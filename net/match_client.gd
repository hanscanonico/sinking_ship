class_name MatchClient
extends RefCounted
## A player's end of the match (D11). A beat comes in two halves around the host's:
## sample() reads this seat's frames and sends them, step() takes in what the host
## sent and brings the prediction and the view on.
##
## It runs ahead of the host: its seat's frame for a tick is sent before the host
## steps that tick, the lead kept inside lead_buffer…lead_buffer + lead_slack by what
## each snapshot says of the last frame heard — by sampling extra ticks when frames
## come late, holding when they come too early. It predicts by resetting its sim to
## the newest snapshot and re-running MatchSim.step over its own frames since, every
## other seat repeating its last input; bots are never run here (D10). It draws its
## own seat from that prediction and every other one interp_delay behind the newest
## snapshot, interpolated — and whatever a snapshot leaves out, as it last had it.
##
## Over an instant wire — a host in the same process, nothing in between — the lead
## and the delay are none: the frame sampled is the one the host steps in the same
## beat, and the view is the host's snapshot of that beat, nothing re-run.
##
## A reset is skipped when it cannot change anything (R7): the newest snapshot has this
## seat, the crates and the railings as the prediction had them for that tick, within a
## quantum, nothing else could have touched the seat since (ContactWatch), and the
## prediction was reset less than trust_limit ago — then only the new ticks are stepped.
##
## What it exposes is a snapshot (D5): view(), the match as this player sees it.
## The verdict is the host's alone: the view ends when the host's last snapshot is
## reached. The tick's events come from the host, as the view reaches their tick.

## How the last step() met the newest snapshot: none had come, the prediction agreed
## with it and stood, or it was reset to it and re-run.
enum Reconciled { NOTHING_NEW, TRUSTED, REWOUND }

var config: MatchConfig
## The prediction: the newest snapshot re-run over this seat's frames since — the
## newest snapshot itself, when only watching. The scene may ask it what the data and
## the ship are, never what a seat is doing.
var sim: MatchSim
## The seat this client plays, or -1 to only watch.
var seat: int
## How far the last reset moved this seat's predicted body — what the scene draws
## away over correction_time (D12).
var correction := Vector3.ZERO
var reconciled := Reconciled.NOTHING_NEW
## The ticks the last step() re-ran after a reset (R7).
var resim_ticks := 0

var _rules: NetRules
var _wire: Transport
var _host: int
var _codec: WireCodec
var _watch: ContactWatch
var _source: InputSource
var _history: SnapshotHistory
## The lead band and the interpolation delay, in ticks: NetRules', or none over an
## instant wire.
var _lead_ticks: int
var _slack_ticks: int
var _interp_ticks: int
## The next tick a frame is sampled for: the prediction is stepped up to it.
var _sampled: int
## This seat's frames by tick, from the oldest a reset or a packet needs.
var _frames := {}
var _last_frame: InputFrame
## The prediction by tick, from the newest snapshot's on: this seat's record, the
## crates' and the railings' — what a trusted prediction could get wrong unseen; the
## other seats are ContactWatch's. The rest cannot part: the rng is spent at the start
## alone, the phase moves on with the tick or ends (and the prediction with it), and
## the sinking — collapses and scheduled breaks — is the tick's (D7).
var _predicted := {}
## The tick of the snapshot the prediction was last reset to.
var _reset_from: int
var _ack := -1
## Ticks to sample beyond this beat's one (positive), or beats to hold (negative).
var _shift := 0
## The first tick sent at the lead the last shift set: a report of an older frame
## predates the shift.
var _settle_from := 0
## The tick the other seats are drawn at.
var _view_tick: int
## The highest tick the events of are known; those of later ticks wait for a snapshot.
var _events_through := -1
var _pending: Array[Dictionary] = []
var _view: Dictionary


## A client of [param match_config], whose host is [param host_peer] on
## [param wire], playing [param own_seat] with the frames [param source] makes — or
## only watching when that seat is -1. It starts from the match's first tick, which
## the config alone decides.
func _init(
	match_config: MatchConfig,
	net_rules: NetRules,
	wire: Transport,
	host_peer: int,
	own_seat: int,
	source: InputSource
) -> void:
	config = match_config
	_rules = net_rules
	_wire = wire
	_host = host_peer
	seat = own_seat
	_source = source
	_codec = WireCodec.new(WireCodec.match_hash(config, net_rules))
	var instant := wire.instant()
	_lead_ticks = 0 if instant else _rules.lead_ticks()
	_slack_ticks = 0 if instant else _rules.slack_ticks()
	_interp_ticks = 0 if instant else _rules.interp_ticks()
	sim = MatchSim.create(config)
	_watch = ContactWatch.new(config, sim.schedule)
	_sampled = sim.state.tick
	_reset_from = _sampled
	_note_prediction()
	_history = SnapshotHistory.new(sim.snapshot())
	_view_tick = _sampled - _interp_ticks
	_view = _compose([])


## The match as this player sees it now: a snapshot, its tick the prediction's.
func view() -> Dictionary:
	return _view


## Whether the view has reached the host's verdict.
func is_over() -> bool:
	return _view["phase"] == MatchState.Phase.ENDED


## The newest tick the host has stepped to that this client knows of.
func host_tick() -> int:
	return _history.newest()["tick"]


## The first half of a beat: this seat's frames for the ticks the lead runs to, sent
## to the host.
func sample() -> void:
	var newest := _history.newest()
	if seat < 0 or newest["phase"] == MatchState.Phase.ENDED:
		return
	var ticks := 1
	if _shift > 0:
		ticks += _shift
		_shift = 0
	elif _shift < 0:
		ticks = 0
		_shift += 1
	var cap: int = newest["tick"] + _rules.prediction_cap_ticks()
	var made := false
	for _beat in ticks:
		if _sampled >= cap:
			break
		var frame := _source.next_frame(_sampled)
		if frame == null:
			frame = _repeat(_sampled)
		_frames[_sampled] = frame
		_last_frame = frame
		_sampled += 1
		made = true
	if made:
		_send()


## The second half of a beat: what the host sent taken in, the prediction brought up
## to the ticks sampled, the view a tick on. Returns the events the view reached.
func step() -> Array[SimEvent]:
	correction = Vector3.ZERO
	resim_ticks = 0
	reconciled = Reconciled.NOTHING_NEW
	var newer := _receive()
	if newer:
		_reconcile(_history.newest())
	while seat >= 0 and sim.state.tick < _sampled and not sim.is_over():
		_step_prediction(sim.state.tick)
	_view_tick += 1
	if newer:
		var behind := host_tick() - _interp_ticks - _view_tick
		if absi(behind) > _interp_ticks:
			_view_tick += behind
		elif absi(behind) >= 2:
			_view_tick += signi(behind)
	var events: Array[SimEvent] = []
	var reached: Array[Dictionary] = []
	while not _pending.is_empty() and _pending[0]["tick"] < _view_tick:
		var entry: Dictionary = _pending.pop_front()
		reached.append(entry)
		events.append(SimEvent.from_dict(entry))
	_view = _compose(reached)
	if _source != null:
		_source.observe(_view, sim.schedule.pose_at(_view["tick"]))
	return events


## Takes in every snapshot that came; true when one is newer than any before.
func _receive() -> bool:
	var newer := false
	for packet: Transport.Packet in _wire.receive():
		if packet.peer != _host:
			continue
		var got := _codec.decode_snapshot(packet.bytes)
		if got == null or not _history.add(got.snapshot):
			continue
		newer = true
		var tick: int = got.snapshot["tick"]
		for entry: Dictionary in got.snapshot["events"]:
			if entry["tick"] > _events_through:
				_pending.append(entry)
		_events_through = maxi(_events_through, tick - 1)
		_ack = maxi(_ack, got.ack)
		if got.heard >= _settle_from:
			_keep_lead(got.early)
	return newer


## Shifts the sampling so a frame arrives in the middle of the lead band, when the
## one just heard of arrived [param early] ticks ahead of need outside it.
func _keep_lead(early: int) -> void:
	var most := _lead_ticks + _slack_ticks
	if early >= _lead_ticks and early <= most:
		return
	_shift = ((_lead_ticks + most) >> 1) - early
	_settle_from = _sampled + maxi(_shift, 0)


## Meets [param newest]: trusts the prediction where nothing can have changed it,
## else resets to the snapshot and re-runs the prediction to where it was — this
## seat's frames from the snapshot's tick on, which the host had not yet stepped when
## it sent it. Frames before it are in it, applied or repeated by the host.
func _reconcile(newest: Dictionary) -> void:
	var from: int = newest["tick"]
	var reached := sim.state.tick
	if _trusted(newest):
		reconciled = Reconciled.TRUSTED
	else:
		reconciled = Reconciled.REWOUND
		var was := _own_pos()
		sim.restore(newest)
		_reset_from = from
		_predicted.clear()
		_note_prediction()
		for tick in range(from, reached):
			if sim.is_over():
				break
			_step_prediction(tick)
		resim_ticks = maxi(reached - from, 0)
		# Behind a snapshot the frames sampled had not reached — after a stall — the
		# seat leaps to it, and is drawn there smoothly too.
		if reached >= from or _sampled < from:
			correction = _own_pos() - was
	for tick: int in _predicted.keys():
		if tick < from:
			_predicted.erase(tick)
	var oldest := mini(from, maxi(_ack + 1, _sampled - _rules.input_redundancy))
	for tick: int in _frames.keys():
		if tick < oldest:
			_frames.erase(tick)


## Whether the prediction can stand against [param newest] as it is: it ran past the
## snapshot's tick and has not ended — an end may be its phantoms' — it was last reset
## less than trust_limit before, it had at that tick what the snapshot has, and nothing
## in the snapshot — nor in the prediction itself, whose other seats only repeat their
## last inputs — can have come near this seat over the ticks since.
func _trusted(newest: Dictionary) -> bool:
	var from: int = newest["tick"]
	var reached := sim.state.tick
	if seat < 0 or reached <= from or newest["phase"] == MatchState.Phase.ENDED:
		return false
	if sim.is_over() or from - _reset_from >= _rules.trust_ticks():
		return false
	if not _predicted.has(from) or not _agrees(newest, _predicted[from]):
		return false
	var path := PackedVector3Array()
	for tick in range(from, reached + 1):
		path.append(_predicted[tick]["seat"]["pos"])
	var here := PackedVector3Array([path[-1]])
	return (
		_watch.clear(newest, seat, path, 0)
		and _watch.clear(sim.snapshot(), seat, here, reached - from)
	)


## Whether [param newest] has this seat, the crates and the railings as the
## prediction had them at its tick — [param then] — within a quantum.
func _agrees(newest: Dictionary, then: Dictionary) -> bool:
	if not WireCodec.within_quantum(&"seats", newest["seats"][seat], then["seat"]):
		return false
	var hp: PackedFloat64Array = then["railing_hp"]
	if not WireCodec.field_within_quantum(&"snapshot", "railing_hp", newest["railing_hp"], hp):
		return false
	var crates: Array = newest["props"]
	var held: Array[Dictionary] = then["props"]
	if crates.size() != held.size():
		return false
	for index in crates.size():
		if not WireCodec.within_quantum(&"props", crates[index], held[index]):
			return false
	return true


## Steps the prediction over [param tick] with this seat's frame for it.
func _step_prediction(tick: int) -> void:
	var row: Array[InputFrame] = []
	row.resize(config.seats)
	row[seat] = _frames.get(tick)
	sim.step(row)
	_note_prediction()


func _note_prediction() -> void:
	if seat < 0:
		return
	var crates: Array[Dictionary] = []
	for crate: PropState in sim.state.props:
		crates.append(crate.to_dict())
	_predicted[sim.state.tick] = {
		"seat": sim.state.seats[seat].to_dict(),
		"props": crates,
		"railing_hp": sim.state.railing_hp.duplicate(),
	}


## The packet of this seat's newest frames — the last input_redundancy of them, none
## the host has applied — oldest first.
func _send() -> void:
	var first := maxi(_ack + 1, _sampled - _rules.input_redundancy)
	var frames: Array[InputFrame] = []
	var tick := _sampled - 1
	while tick >= first and _frames.has(tick):
		frames.push_front(_frames[tick])
		tick -= 1
	if not frames.is_empty():
		_wire.send(_host, _codec.encode_inputs(frames))


## This seat's last frame again, for [param tick]; standing still before any.
func _repeat(tick: int) -> InputFrame:
	if _last_frame == null:
		return InputFrame.new(seat, tick)
	return InputFrame.new(seat, tick, _last_frame.move, _last_frame.buttons, _last_frame.look_yaw)


func _own_pos() -> Vector3:
	if seat < 0:
		return Vector3.ZERO
	return sim.state.seats[seat].pos


## The view: the host's match at the view tick, its events [param reached] — and,
## until the host's verdict is reached, this seat as predicted, at the prediction's
## tick and phase. A predicted end is not the host's, so it shows as play going on.
func _compose(reached: Array[Dictionary]) -> Dictionary:
	var view := _history.at(_view_tick)
	view["events"] = reached
	if seat < 0 or view["phase"] == MatchState.Phase.ENDED:
		return view
	view["tick"] = sim.state.tick
	var predicted := sim.state.phase
	view["phase"] = MatchState.Phase.LIVE if predicted == MatchState.Phase.ENDED else predicted
	view["seats"][seat] = sim.state.seats[seat].to_dict()
	return view
