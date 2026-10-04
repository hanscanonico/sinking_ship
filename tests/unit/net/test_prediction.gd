extends GutTest
## The client (D11): over a wire 120 ms long each way, jittered and lossy, it moves
## its own seat on the tick its input is pressed, predicts what the host then does,
## and after a shove it could not foresee, comes back to the host's answer. Over the
## offline game's honest wire it is the host, beat for beat.

const LAG := "latency:120,jitter:20,loss:5"
## How near a prediction must come to the host's answer for the same tick: a few
## quanta of the snapshot it started from, grown over the ticks re-run from it.
const AGREE_M := 0.01
## Beats for the client's lead to settle before a test looks.
const SETTLE := 2 * Ticks.RATE
## The flat deck's starboard railing, along z 4 from the stern at x -15 to x 2.
const STARBOARD_SPAN := 2


## A seat that walks along [member stick] while it is set, looking along
## [member look_deg], with [member buttons] held.
class Scripted:
	extends InputSource
	var seat: int
	var stick := Vector2.ZERO
	var look_deg := 0.0
	var buttons := 0

	func _init(seat_id: int) -> void:
		seat = seat_id

	func next_frame(tick: int) -> InputFrame:
		var look := InputFrame.quantize_yaw(deg_to_rad(look_deg))
		return InputFrame.new(seat, tick, InputFrame.quantize(stick), buttons, look)


## Two seats on the flat deck, standing at [param spawns] — in an order the match's
## stream picks — with the client playing seat 0 through [param mine] and the host
## running seat 1 through [param theirs], over [param lag], by [param rules] or the
## shipped ones.
func _match(
	spawns: Array[Vector3],
	mine: InputSource,
	theirs: InputSource,
	lag: String = LAG,
	rules: NetRules = null
) -> LoopbackMatch:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	layout.spawns = spawns
	var config := SimFixtures.config(2, null, 3, layout)
	var sources: Array[InputSource] = [null, theirs]
	return LoopbackMatch.new(
		config,
		rules if rules != null else NetRules.load_default(),
		NetConditions.parse(lag),
		0,
		mine,
		sources
	)


func _own(played: LoopbackMatch) -> Dictionary:
	return played.client.view()["seats"][0]


func _host_seat(played: LoopbackMatch, seat: int = 0) -> Dictionary:
	return played.host.runner.snapshot["seats"][seat]


## Steps [param played] [param beats] beats, noting per tick the client's first
## prediction of seat 0 into [param predicted] and the host's answer into
## [param authority]; returns the events the client's view reached.
func _play(
	played: LoopbackMatch, beats: int, predicted: Dictionary, authority: Dictionary
) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	for _beat in beats:
		events.append_array(played.step())
		var view := played.client.view()
		if not predicted.has(view["tick"]):
			predicted[view["tick"]] = _own(played)["pos"]
		authority[played.host.tick()] = _host_seat(played)["pos"]
	return events


func test_local_input_moves_on_the_same_tick() -> void:
	var mine := Scripted.new(0)
	var played := _match([Vector3(-5.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)], mine, InputSource.new())
	for _beat in SETTLE:
		played.step()
	var before: Vector3 = _own(played)["pos"]
	var lead: int = played.client.view()["tick"] - played.host.tick()
	assert_gt(lead, Ticks.from_seconds(0.12), "the client runs more than a one-way trip ahead")
	mine.stick = Vector2.RIGHT
	played.step()
	var moved: Vector3 = _own(played)["pos"]
	assert_ne(moved, before, "the seat moves on the beat the stick is pushed")
	assert_eq(_host_seat(played)["vel"], Vector3.ZERO, "long before the host has heard of it")


## The other seat stands within reach but out of touch of the walk, so the prediction
## is seldom trusted as it stands: snapshot after snapshot resets it and re-runs the
## walk.
func test_prediction_matches_authority_without_contact() -> void:
	var mine := Scripted.new(0)
	var played := _match(
		[Vector3(-6.0, 0.0, 0.0), Vector3(-2.0, 0.0, 2.0)], mine, InputSource.new()
	)
	var predicted := {}
	var authority := {}
	_play(played, SETTLE, {}, {})
	var from := played.client.view()["tick"] as int
	var start := _host_seat(played)["pos"] as Vector3
	# A wavering walk round a square and back, with a turn of the look and a jump on
	# the way: a frame unlike the one before nearly every tick.
	var re_run := 0
	var beat := 0
	for leg: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		mine.look_deg += 90.0
		mine.buttons = InputFrame.JUMP if leg == Vector2.DOWN else 0
		for _beat in Ticks.from_seconds(0.5):
			mine.stick = leg.rotated(0.6 * sin(beat * 0.9))
			beat += 1
			_play(played, 1, predicted, authority)
			re_run += played.client.resim_ticks
	mine.stick = Vector2.ZERO
	_play(played, Ticks.RATE, predicted, authority)
	assert_gt(re_run, 2 * Ticks.RATE, "the walk was re-run, snapshot after snapshot")
	var compared := 0
	var farthest := 0.0
	for tick: int in predicted:
		if tick < from or not authority.has(tick):
			continue
		compared += 1
		farthest = maxf(farthest, (predicted[tick] as Vector3).distance_to(authority[tick]))
	assert_gt(compared, 2 * Ticks.RATE, "the walk is compared tick by tick")
	assert_lt(farthest, AGREE_M, "every tick drawn where the host then put it")
	var walked: Vector3 = authority[authority.keys().max()]
	assert_gt(walked.distance_to(start), 0.5, "the walk went somewhere")


func test_reconciliation_converges_after_a_remote_shove() -> void:
	var mine := Scripted.new(0)
	var shover := Scripted.new(1)
	var played := _match([Vector3(-0.6, 0.0, 0.0), Vector3(0.6, 0.0, 0.0)], mine, shover)
	var at := _host_seat(played, 1)["pos"] as Vector3
	var target := _host_seat(played, 0)["pos"] as Vector3
	var toward := Vector2(target.x - at.x, target.z - at.z)
	shover.look_deg = rad_to_deg(toward.angle())
	_play(played, SETTLE, {}, {})
	var predicted := {}
	var authority := {}
	var stood := _host_seat(played)["pos"] as Vector3
	shover.buttons = InputFrame.SHOVE
	var events := _play(played, 2, predicted, authority)
	shover.buttons = 0
	var largest := 0.0
	for _beat in 2 * Ticks.RATE:
		events.append_array(_play(played, 1, predicted, authority))
		largest = maxf(largest, played.client.correction.length())
	var landed := events.filter(
		func(event: SimEvent) -> bool:
			return event.kind == SimEvent.Kind.SHOVE_LANDED and event.target == 0
	)
	assert_eq(landed.size(), 1, "the host's word of the shove reached the client's view")
	var shoved := _host_seat(played)["pos"] as Vector3
	assert_gt(shoved.distance_to(stood), 0.5, "the host's seat 1 shoved seat 0 away")
	assert_gt(largest, 0.1, "the client could not foresee it, and was corrected")
	var settled := played.client.view()["tick"] as int - Ticks.from_seconds(0.5)
	var farthest := 0.0
	for tick: int in predicted:
		if tick >= settled and authority.has(tick):
			farthest = maxf(farthest, (predicted[tick] as Vector3).distance_to(authority[tick]))
	assert_lt(farthest, AGREE_M, "and once it settled, the prediction is the host's again")


func test_a_snapshot_without_some_seats_keeps_them() -> void:
	var config := SimFixtures.config(3)
	var clock := NetClock.new()
	var honest := NetConditions.new()
	var host_end := LoopbackTransport.new(0, clock, honest, SeedStreams.derive(1, 0))
	var client_end := LoopbackTransport.new(1, clock, honest, SeedStreams.derive(1, 1))
	LoopbackTransport.link(host_end, client_end)
	var client := MatchClient.new(
		config, NetRules.load_default(), client_end, 0, 0, Scripted.new(0)
	)
	var first := client.view()["seats"][1]["pos"] as Vector3
	var host := MatchSim.create(config)
	SimFixtures.place(host, 1, Vector3(4.0, 0.0, 2.5))
	SimFixtures.place(host, 2, Vector3(-4.0, 0.0, -2.5))
	for _tick in 5:
		host.step([])
	var partial := host.snapshot()
	var listed: Array[Dictionary] = [partial["seats"][0], partial["seats"][2]]
	partial["seats"] = listed
	var codec := WireCodec.new(WireCodec.match_hash(config, NetRules.load_default()))
	host_end.send(1, codec.encode_snapshot(partial, -1, -1, 0))
	for _beat in 10:
		client.sample()
		client.step()
	var seats: Array = client.view()["seats"]
	assert_eq(seats.size(), 3, "every seat is still drawn")
	assert_eq(seats[1]["pos"], first, "the one left out where it was last known")
	assert_almost_eq(seats[2]["pos"], Vector3(-4.0, 0.0, -2.5), Vector3.ONE * 0.001)
	assert_gte(client.sim.state.tick, 5, "and the prediction runs on from the snapshot")


## After a stall the newest snapshot is past every frame sampled: the seat leaps to it,
## and the leap is a correction the scene draws away rather than a snap.
func test_a_snapshot_past_the_frames_sampled_is_a_correction() -> void:
	var config := SimFixtures.config(2)
	var clock := NetClock.new()
	var honest := NetConditions.new()
	var host_end := LoopbackTransport.new(0, clock, honest, SeedStreams.derive(1, 0))
	var client_end := LoopbackTransport.new(1, clock, honest, SeedStreams.derive(1, 1))
	LoopbackTransport.link(host_end, client_end)
	var client := MatchClient.new(
		config, NetRules.load_default(), client_end, 0, 0, Scripted.new(0)
	)
	var was := client.view()["seats"][0]["pos"] as Vector3
	var host := MatchSim.create(config)
	SimFixtures.place(host, 0, was + Vector3(2.0, 0.0, 1.0))
	for _tick in 5:
		host.step([])
	var codec := WireCodec.new(WireCodec.match_hash(config, NetRules.load_default()))
	host_end.send(1, codec.encode_snapshot(host.snapshot(), -1, -1, 0))
	client.sample()
	client.step()
	assert_eq(client.sim.state.tick, 5, "the prediction leapt to the snapshot")
	assert_almost_eq(client.correction, Vector3(2.0, 0.0, 1.0), Vector3.ONE * 0.002)


## A two-seat match on a deck 0.4 m out of a sea that rises 2 m in 8 s — it ends — the
## seats at [param spawns] (in the match stream's order), over [param lag].
func _sinking_match(
	spawns: Array[Vector3], mine: InputSource, theirs: InputSource, lag: String
) -> LoopbackMatch:
	var layout := SimFixtures.low_deck(0.4)
	layout.spawns = spawns
	var sinking := SimFixtures.scenario([[0.0, 0.0, 0.0, 0.0], [8.0, 2.0, 0.0, 0.0]])
	var config := SimFixtures.config(2, sinking, 5, layout)
	var sources: Array[InputSource] = [null, theirs]
	return LoopbackMatch.new(
		config, NetRules.load_default(), NetConditions.parse(lag), 0, mine, sources
	)


## What a beat's events were, comparably.
func _told(events: Array) -> Array[String]:
	var told: Array[String] = []
	for event: Dictionary in events:
		told.append("%d %d %d %d" % [event["tick"], event["kind"], event["seat"], event["target"]])
	return told


func test_offline_the_view_is_the_hosts_snapshot_of_the_same_beat() -> void:
	var mine := Scripted.new(0)
	var theirs := Scripted.new(1)
	var spawns: Array[Vector3] = [Vector3(-0.6, 0.0, 0.0), Vector3(0.6, 0.0, 0.0)]
	var played := _sinking_match(spawns, mine, theirs, "")
	var beats := 0
	var differ := ""
	var re_run := 0
	while not played.host.is_over() and beats < 30 * Ticks.RATE:
		# Both shove and walk about, so the match has contact, falls and the sea.
		mine.buttons = InputFrame.SHOVE if beats % 20 < 3 else 0
		mine.stick = Vector2.from_angle(beats * 0.05) * 0.6
		mine.look_deg = beats * 3.0
		theirs.buttons = InputFrame.SHOVE if beats % 25 < 3 else 0
		theirs.look_deg = 180.0 - beats * 2.0
		played.step()
		beats += 1
		re_run += played.client.resim_ticks
		var view := played.client.view()
		var host := played.host.runner.snapshot
		if not differ.is_empty():
			continue
		if view["tick"] != host["tick"] or view["phase"] != host["phase"]:
			differ = (
				"beat %d: tick %d phase %d, host's %d %d"
				% [beats, view["tick"], view["phase"], host["tick"], host["phase"]]
			)
		for index in host["seats"].size():
			if not WireCodec.within_quantum(&"seats", host["seats"][index], view["seats"][index]):
				differ = "beat %d: seat %d is not the host's" % [beats, index]
		if played.client.correction != Vector3.ZERO:
			differ = "beat %d: corrected by %s" % [beats, played.client.correction]
		if _told(view["events"]) != _told(host["events"]):
			differ = (
				"beat %d: events %s, host's %s"
				% [beats, _told(view["events"]), _told(host["events"])]
			)
	assert_true(played.host.is_over(), "the match ended")
	assert_gt(beats, 2 * Ticks.RATE, "after a while")
	assert_eq(differ, "", "every beat, the view is the host's snapshot of it")
	assert_eq(re_run, 0, "and nothing was ever re-run")
	assert_true(played.client.is_over(), "the client saw the verdict the beat it came")


func test_over_a_lying_wire_others_are_drawn_interp_delay_behind() -> void:
	var walker := Scripted.new(1)
	var spawns: Array[Vector3] = [Vector3(-10.0, 0.0, -2.0), Vector3(-10.0, 0.0, 2.0)]
	var played := _match(spawns, Scripted.new(0), walker)
	walker.stick = Vector2(0.5, 0.0)
	var walked := {}
	for _beat in SETTLE + Ticks.RATE:
		played.step()
		walked[played.host.tick()] = _host_seat(played, 1)["pos"]
	var drawn := played.client.view()["seats"][1]["pos"] as Vector3
	var at := -1
	for tick: int in walked:
		if (walked[tick] as Vector3).distance_to(drawn) < 0.001:
			at = tick
	var behind := played.client.host_tick() - at
	var delay := NetRules.load_default().interp_ticks()
	assert_gt(at, 0, "seat 1 is drawn where the host had it at some tick")
	assert_between(behind, delay - 1, delay + 1, "interp_delay behind the newest snapshot")
	var lead: int = played.client.view()["tick"] - played.client.host_tick()
	assert_gt(lead, 2 * Ticks.from_seconds(0.12), "and its own seat a round trip ahead")


func test_a_body_coming_within_reach_forces_a_full_rewind() -> void:
	var walker := Scripted.new(1)
	var spawns: Array[Vector3] = [Vector3(-12.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0)]
	# The reset that comes now and then put off, so the first one is the contact's.
	var patient: NetRules = NetRules.load_default().duplicate()
	patient.trust_limit = 60.0
	var played := _match(spawns, Scripted.new(0), walker, LAG, patient)
	var predicted := {}
	var authority := {}
	_play(played, SETTLE, predicted, authority)
	var mine := _host_seat(played, 0)["pos"] as Vector3
	var from := _host_seat(played, 1)["pos"] as Vector3
	walker.stick = Vector2(mine.x - from.x, mine.z - from.z).normalized()
	walker.look_deg = rad_to_deg(walker.stick.angle())
	var walked := {}
	var trusted := 0
	var rewound_at := INF
	for _beat in 3 * Ticks.RATE:
		_play(played, 1, predicted, authority)
		walked[played.host.tick()] = _host_seat(played, 1)["pos"]
		var client := played.client
		if client.reconciled == MatchClient.Reconciled.TRUSTED:
			trusted += 1
		elif client.reconciled == MatchClient.Reconciled.REWOUND and rewound_at == INF:
			# How far apart the snapshot it met had the two.
			var known: Vector3 = (
				authority[client.host_tick()] - walked.get(client.host_tick(), from)
			)
			rewound_at = Vector2(known.x, known.z).length()
	var rules := SimFixtures.rules()
	var touch := 2.0 * rules.body_radius + rules.shove_reach
	assert_gt(trusted, Ticks.RATE, "far apart, the prediction stands without a rewind")
	assert_between(rewound_at, touch, 10.0, "a body coming within reach forces one, early")
	var farthest := 0.0
	for tick: int in predicted:
		if authority.has(tick):
			farthest = maxf(farthest, (predicted[tick] as Vector3).distance_to(authority[tick]))
	assert_lt(farthest, AGREE_M, "and every tick was predicted where the host had it")


## Seat 0's view: the longest run of beats [param played] went on without its own
## seat moving, over [param beats] beats.
func _longest_still(played: LoopbackMatch, beats: int) -> int:
	var was := _own(played)["pos"] as Vector3
	var still := 0
	var longest := 0
	for _beat in beats:
		played.step()
		var now := _own(played)["pos"] as Vector3
		still = still + 1 if now == was else 0
		longest = maxi(longest, still)
		was = now
	return longest


## However still a body stands in a snapshot, it may be knocked away at the fastest the
## rules move anything and slide down the heeled deck on top of that: a seat within
## that reach of it over the span is not clear of it, and one beyond is.
func test_a_still_body_is_near_within_a_knockback_and_a_slide() -> void:
	var config := SimFixtures.config(2, SimFixtures.tilted(0.0, 12.0))
	var rules := config.rules
	var sim := MatchSim.create(config)
	var at := Vector3(-6.0, 0.0, 0.0)
	SimFixtures.place(sim, 0, at)
	var path := PackedVector3Array()
	path.resize(Ticks.from_seconds(0.3) + 1)
	path.fill(at)
	var span := (path.size() - 1) * Ticks.SECONDS_PER_TICK
	var fastest := maxf(
		maxf(rules.walk_speed, rules.vault_speed),
		maxf(rules.charged_knockback, maxf(rules.knockback, rules.crate_knockback))
	)
	var pull := rules.gravity * sin(deg_to_rad(12.0))
	var reach := 2.0 * rules.body_radius + rules.shove_reach + (fastest + pull * span) * span
	var watch := ContactWatch.new(config, sim.schedule)
	SimFixtures.place(sim, 1, at + Vector3(reach - 0.05, 0.0, 0.0))
	assert_false(watch.clear(sim.snapshot(), 0, path, 0), "within reach")
	SimFixtures.place(sim, 1, at + Vector3(reach + 0.05, 0.0, 0.0))
	assert_true(watch.clear(sim.snapshot(), 0, path, 0), "beyond it")


func test_a_railing_broken_far_away_is_gone_from_the_prediction() -> void:
	var mine := Scripted.new(0)
	mine.look_deg = 90.0
	var spawns: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(-12.0, 0.0, -3.0)]
	var played := _match(spawns, mine, InputSource.new())
	_play(played, SETTLE, {}, {})
	var stood := _host_seat(played)["pos"] as Vector3
	assert_almost_eq(stood, Vector3.ZERO, Vector3.ONE * 0.01, "seat 0 stands mid-deck")
	# Broken as a body slammed into it far along would: out of reach of seat 0, whose
	# own record goes on agreeing with the prediction's.
	played.host.runner.sim.state.railing_hp[STARBOARD_SPAN] = 0.0
	var broke := played.host.tick()
	var gone_after := -1
	var predicted := {}
	var authority := {}
	var largest := 0.0
	for beat in 3 * Ticks.RATE:
		if beat == Ticks.RATE:
			mine.stick = Vector2(0.0, 1.0)
		_play(played, 1, predicted, authority)
		var held: float = played.client.sim.state.railing_hp[STARBOARD_SPAN]
		if gone_after < 0 and held == 0.0:
			gone_after = played.host.tick() - broke
		largest = maxf(largest, played.client.correction.length())
	assert_between(gone_after, 0, Ticks.from_seconds(0.3), "gone from it within a round trip")
	var walked := _host_seat(played)["pos"] as Vector3
	assert_gt(walked.z, 4.5, "seat 0 walked out where the railing was")
	assert_lt(largest, 0.03, "and was never corrected by more than a few centimetres")
	var farthest := 0.0
	for tick: int in predicted:
		if tick > broke and authority.has(tick):
			farthest = maxf(farthest, (predicted[tick] as Vector3).distance_to(authority[tick]))
	assert_lt(farthest, AGREE_M, "every tick predicted where the host had it")


func test_a_crate_moved_far_away_is_moved_in_the_prediction() -> void:
	var crates: Array[ShipProp] = [SimFixtures.crate(Vector3(12.0, 0.0, -2.0))]
	var layout := SimFixtures.crated(crates)
	layout.spawns = [Vector3(-2.0, 0.0, 2.0), Vector3(-14.0, 0.0, -2.0)] as Array[Vector3]
	var config := SimFixtures.config(2, null, 3, layout)
	var sources: Array[InputSource] = [null, InputSource.new()]
	var played := LoopbackMatch.new(
		config, NetRules.load_default(), NetConditions.parse(LAG), 0, Scripted.new(0), sources
	)
	_play(played, SETTLE, {}, {})
	# Moved as a shove far from seat 0 would.
	var crate: PropState = played.host.runner.sim.state.props[0]
	crate.pos.z += 1.5
	var moved := played.host.tick()
	var caught_up := -1
	for _beat in Ticks.RATE:
		played.step()
		var held: Vector3 = played.client.sim.state.props[0].pos
		if caught_up < 0 and held.distance_to(crate.pos) < 0.01:
			caught_up = played.host.tick() - moved
	assert_between(caught_up, 0, Ticks.from_seconds(0.3), "moved in it within a round trip")


## The other seat, swimming with its cold all but spent, is pulled out on the host the
## tick after: the prediction, which only repeats its last input, ends the match on it
## — and is not trusted on, so seat 0 walks on.
func test_a_prediction_ended_by_a_phantom_does_not_freeze_the_seat() -> void:
	var mine := Scripted.new(0)
	var spawns: Array[Vector3] = [Vector3(-8.0, 0.0, 3.0), Vector3(8.0, 0.0, -3.0)]
	var played := _match(spawns, mine, InputSource.new())
	_play(played, SETTLE, {}, {})
	mine.stick = Vector2(0.5, 0.0)
	assert_lte(_longest_still(played, Ticks.from_seconds(0.5)), 1, "seat 0 walks")
	var host := played.host.runner.sim
	var near := _host_seat(played)["pos"] as Vector3 + Vector3(1.0, 0.0, 3.0)
	SimFixtures.swim(host, 1, near)
	host.state.seats[1].cold = 0.3
	played.step()
	# Out of the sea, far off and warm: nothing near seat 0 the host knows of.
	SimFixtures.place(host, 1, Vector3(12.0, 0.0, -3.0))
	host.state.seats[1].cold = SimFixtures.rules().cold_meter
	var still := _longest_still(played, Ticks.RATE)
	assert_false(played.host.is_over(), "the host's match goes on")
	assert_lte(still, 2, "and seat 0 never stands still for more than a lost snapshot")


func test_a_trusted_prediction_is_still_reset_now_and_then() -> void:
	var spawns: Array[Vector3] = [Vector3(-12.0, 0.0, 0.0), Vector3(12.0, 0.0, 0.0)]
	var played := _match(spawns, Scripted.new(0), InputSource.new())
	_play(played, SETTLE, {}, {})
	var limit := NetRules.load_default().trust_ticks()
	var reset_at := played.client.host_tick()
	var longest := 0
	var resets := 0
	var trusted := 0
	for _beat in 4 * Ticks.RATE:
		played.step()
		match played.client.reconciled:
			MatchClient.Reconciled.TRUSTED:
				trusted += 1
			MatchClient.Reconciled.REWOUND:
				resets += 1
				longest = maxi(longest, played.client.host_tick() - reset_at)
				reset_at = played.client.host_tick()
	longest = maxi(longest, played.client.host_tick() - reset_at)
	assert_gt(trusted, 2 * Ticks.RATE, "far apart, the prediction is trusted")
	assert_gt(resets, 1, "and still reset")
	assert_lte(longest, limit + Ticks.from_seconds(0.1), "at least every trust_limit")
