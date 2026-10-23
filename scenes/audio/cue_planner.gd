class_name CuePlanner
extends RefCounted
## Turns one step of the match into the sounds it makes (D12): the snapshot before
## it, the snapshot after it with the events it carries, and the ship's pose at
## both ticks as SinkSchedule answers them (D7). Nothing else — no live seat, no
## sim (D5). Its own memory, how far through a stride each seat is, how far each
## crate has slid since it last scraped, how far the hull has strained since it
## last complained and which of her water it has heard, is presentation state;
## nothing it does reaches the sim.

## Metres between footfalls, so steps land with the drawn feet: each locomotion
## clip's speed times its length (walk 1.33 s, run 0.93 s), over two feet.
const WALK_STRIDE := BrawlerAnimation.WALK_CLIP_SPEED * 1.333 / 2.0
const RUN_STRIDE := BrawlerAnimation.RUN_CLIP_SPEED * 0.933 / 2.0
## Metres a swimmer covers between strokes: about two a second at swim_speed.
const SWIM_STROKE := 1.1
## The moves that sound as they go, and the metres between their sounds.
const STRIDES := {
	BrawlerAnimation.Move.WALK: WALK_STRIDE,
	BrawlerAnimation.Move.RUN: RUN_STRIDE,
	BrawlerAnimation.Move.SWIM: SWIM_STROKE,
}
## The quietest footfall, at a stroll; a full run is 1.
const STEP_SOFT := 0.45
## A collapse's telegraph is the same wood giving way as the collapse, quieter.
const COLLAPSING_GAIN := 0.6
## Feet this close above the water they are in splash as they step, in metres.
const WET_ABOVE := 0.3
## A step in water as deep over the feet as wade_depth lands this much louder, and
## comes this much further apart, than one in a film of it: wading is heavy going.
## At its loudest a run's step stays well under the bank's ceiling.
const WADE_LOUD := 1.4
const WADE_STRIDE := 1.3
## A landing that costs no stagger still thuds this loud; one that costs
## LANDING_LOUD_TICKS or more lands at full.
const LANDING_SOFT := 0.35
const LANDING_LOUD_TICKS := 12
## Climbing out of the water: the wet landing's splash of the water running off.
const CLIMB_OUT_SPLASH := 0.3
## A jump's effort is the shove's grunt, this much quieter.
const JUMP_EFFORT := 0.5
## The hull's strain is its change of trim and heel in degrees, plus SINK_STRAIN
## per metre it settles: a creak every CREAK_STRAIN of it, a groan every
## GROAN_STRAIN.
const SINK_STRAIN := 4.0
const CREAK_STRAIN := 1.0
const GROAN_STRAIN := 5.0
## Strain a live ship builds every tick even while it holds still, so the hull is
## never silent for long.
const SETTLE_STRAIN := 0.004
## How far round the listener a creak sounds from, in metres.
const CREAK_SPREAD := 6.0
## How far under the lowest deck the hull groans from: about the keel.
const KEEL_BELOW := 0.8
## Metres a crate slides along the deck between two scrapes, and the speed it
## scrapes loudest at, in m/s.
const SCRAPE_STRIDE := 0.4
const SCRAPE_LOUD := 3.0
## The quietest scrape and thud; a full one is 1.
const CARGO_SOFT := 0.4
## Speed a crate loses in one tick, in m/s, that is heard as a thud — it ran into
## something — and the loss, or the speed it comes down at, heard loudest.
const THUD_DROP := 2.0
const THUD_LOUD := 4.0
## A crate the water lifts off the deck splashes this soft.
const AFLOAT_GAIN := 0.45
## Water this far over the lowest corner of a cell's floor, in metres, is heard
## breaking in; and the least difference across an opening heard pouring. Twins of
## InnerWater.SHOWS and InnerWater.POURS, so a pour is heard as it starts being drawn.
const SHOWS := 0.02
const POURS := 0.03
## Seconds a cell heard flooding must stand dry before it is heard flooding again, and
## an opening heard pouring must stand still before it is heard pouring again: water
## hovering at either edge is heard once, not on every crossing.
const CELL_REARM := 10.0
const POUR_REARM := 5.0
## A slot's _off_since while its water is on (_comes_on).
const ON := -1
## The most of the water's cues heard in one tick, the nearest the listener's ears: a
## sinking that sets a deck's worth of water going at once is heard by its nearest,
## not crowding out every voice the brawl needs.
const WATER_CUES := 6
## The openings water passes unseen, and so unheard, as InnerWater leaves them undrawn:
## the gash is the iceberg's boom, a floor's gaps and a small leak only seep.
const UNHEARD: Array[ShipOpening.Kind] = [
	ShipOpening.Kind.GASH, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.LEAK
]

## The seat whose ears the view is in: its own sounds are in the head. -1 when
## no seat's are (the observer camera).
var listener_seat := -1

var _surfaces: Surfaces
var _schedule: SinkSchedule
var _layout: ShipLayout
var _walk_speed: float
## Water this deep over the feet takes them (SWIMMING): the deepest wading.
var _wade_depth: float
## Ticks of charge that make a shove a full one, heard heavy.
var _charge_full: int
var _railing_height: float
## The seat that is "you" for the end of the match.
var _local_seat: int
## Every platform's area together, in the ship plane.
var _hull: Rect2
## The height the hull groans from: KEEL_BELOW under the lowest platform.
var _keel := INF
## How far through its stride each seat is, 0…1.
var _stride := PackedFloat32Array()
## How far through its scrape each crate is, 0…1.
var _scrape := PackedFloat32Array()
## Per cell of her structure, its floor's middle and its half extent along the floor.
var _floors := PackedVector3Array()
var _floor_halves := PackedVector3Array()
## The openings water can pass (SinkSchedule.passages, then failing), but the unheard;
## their two sides, by cell, -1 for the sea or the sky; 1 for one shut until it fails.
var _openings: Array[ShipOpening] = []
var _sides := PackedInt32Array()
var _shut := PackedByteArray()
## What of the water has been heard, by slot — each cell's, then each opening's, then
## each platform's out of every cell: 1 once its coming on is heard, until it has stood
## off its rearm; and the tick it has stood off since, ON while it is on.
var _heard := PackedByteArray()
var _off_since := PackedInt32Array()
## Each platform's slot: its cell's, so the two flood as one, or its own.
var _platform_slots := PackedInt32Array()
## CELL_REARM and POUR_REARM in ticks.
var _cell_rearm := Ticks.from_seconds(CELL_REARM)
var _pour_rearm := Ticks.from_seconds(POUR_REARM)
var _creak_strain := 0.0
var _groan_strain := 0.0


func _init(
	config: MatchConfig, surfaces: Surfaces, schedule: SinkSchedule, local_seat: int
) -> void:
	_surfaces = surfaces
	_schedule = schedule
	_layout = config.ship
	_walk_speed = config.rules.walk_speed
	_wade_depth = config.rules.wade_depth
	_charge_full = Ticks.from_seconds(config.rules.charge_full)
	_railing_height = config.rules.railing_height
	_local_seat = local_seat
	_hull = _layout.platforms[0].area
	for platform: ShipPlatform in _layout.platforms:
		_hull = _hull.merge(platform.area)
		_keel = minf(_keel, platform.height - KEEL_BELOW)
	_stride.resize(config.seats)
	_stride.fill(0.5)
	_scrape.resize(_layout.props.size())
	var structure := _layout.structure
	if structure != null:
		_watch_structure(structure)
	var pose := _schedule.pose_at(0)
	var slots := _floors.size() + _openings.size()
	for platform: ShipPlatform in _layout.platforms:
		var middle := platform.area.get_center()
		var cell := pose.cell_at(Vector3(middle.x, platform.height + CellMap.DRY, middle.y))
		if cell == CellMap.NONE or cell >= _floors.size():
			cell = slots
			slots += 1
		_platform_slots.append(cell)
	_heard.resize(slots)
	_off_since.resize(slots)
	_off_since.fill(ON)


## The cells and the openings of [param structure], whose water is heard.
func _watch_structure(structure: ShipStructure) -> void:
	for cell: FloodCell in structure.cells:
		var half := (cell.high - cell.low) * 0.5
		_floors.append(Vector3(cell.low.x + half.x, cell.low.y, cell.low.z + half.z))
		_floor_halves.append(Vector3(half.x, 0.0, half.z))
	var failing := _schedule.failing()
	var openings := _schedule.passages().duplicate()
	openings.append_array(failing)
	for index in openings.size():
		var opening: ShipOpening = openings[index]
		if opening.kind in UNHEARD or opening.joins.size() != 2:
			continue
		_openings.append(opening)
		for place: StringName in opening.joins:
			_sides.append(structure.cell_named(place))
		_shut.append(1 if index >= openings.size() - failing.size() else 0)


## The cues of the step from [param previous] to [param current], whose events
## are the ones that step raised.
func plan(previous: Dictionary, current: Dictionary) -> Array[AudioCue]:
	var cues: Array[AudioCue] = []
	var tick: int = current["tick"]
	var pose_then := _schedule.pose_at(previous["tick"])
	var pose_now := _schedule.pose_at(tick)
	var then := _by_seat(previous)
	var now := _by_seat(current)
	for seat: int in now:
		var entry: Dictionary = now[seat]
		_footstep(entry, pose_now, tick, cues)
		if then.has(seat):
			_shove(then[seat], entry, tick, cues)
			_take_off(then[seat], entry, tick, cues)
	_cargo(previous["props"], current["props"], tick, cues)
	for event: Dictionary in current["events"]:
		_from_event(event, now, pose_now, cues)
	if current["phase"] == MatchState.Phase.LIVE:
		_hull_strain(pose_then, pose_now, now, tick, cues)
	_water(pose_then, pose_now, now, tick, cues)
	return cues


## A footfall each stride while the feet are drawn walking or running, and a stroke
## each SWIM_STROKE while a swimmer is drawn swimming along; a body frozen in a
## hit-stop holds its stride without a sound. Wading, the steps come louder and
## further apart the deeper the water over the feet.
func _footstep(entry: Dictionary, pose: ShipPose, tick: int, cues: Array[AudioCue]) -> void:
	if entry["hitstop"] > 0:
		return
	var seat: int = entry["seat"]
	var vel: Vector3 = entry["vel"]
	var speed := Vector2(vel.x, vel.z).length()
	var move := BrawlerAnimation.move_for(entry, speed)
	if entry["out"] or not STRIDES.has(move):
		_stride[seat] = 0.5
		return
	var wading := 0.0 if move == BrawlerAnimation.Move.SWIM else _wading(entry["pos"], pose)
	var stride: float = STRIDES[move] * lerpf(1.0, WADE_STRIDE, wading)
	_stride[seat] += speed * Ticks.SECONDS_PER_TICK / stride
	if _stride[seat] < 1.0:
		return
	_stride[seat] = fposmod(_stride[seat], 1.0)
	if move == BrawlerAnimation.Move.SWIM:
		cues.append(_at_seat(AudioCue.Kind.STROKE, tick, entry))
		return
	var cue := _at_seat(AudioCue.Kind.FOOTSTEP, tick, entry)
	cue.gain = lerpf(STEP_SOFT, 1.0, clampf(speed / _walk_speed, 0.0, 1.0))
	cue.gain *= lerpf(1.0, WADE_LOUD, wading)
	cue.ground = _ground(entry["surface"], entry["pos"], pose)
	cues.append(cue)


## A grunt as a shove starts winding up and a whoosh as it is thrown: one each per
## shove, from the shover — the sound of SH9's off-screen arc — heavy at a full
## charge.
func _shove(then: Dictionary, now: Dictionary, tick: int, cues: Array[AudioCue]) -> void:
	if now["out"] or then["action"] == now["action"]:
		return
	match now["action"]:
		PlayerState.Action.WINDUP:
			cues.append(_at_seat(AudioCue.Kind.GRUNT, tick, now))
		PlayerState.Action.ACTIVE:
			var whoosh := _at_seat(AudioCue.Kind.WHOOSH, tick, now)
			whoosh.heavy = _full_charge(now)
			cues.append(whoosh)


## The cargo (SH10), crate by crate from [param then] to [param now] — the two
## snapshots' "props": a scrape each SCRAPE_STRIDE a crate slides along the deck, a
## thud as it comes down or loses THUD_DROP of its speed in a tick, and a splash as
## it goes into the sea. The water lifting one off the deck splashes soft; afloat it
## is silent, and drifting off adrift it makes no second splash.
func _cargo(then: Array, now: Array, tick: int, cues: Array[AudioCue]) -> void:
	for index in now.size():
		var entry: Dictionary = now[index]
		var before: Dictionary = then[index]
		var state: PropState.Body = entry["state"]
		var was_state: PropState.Body = before["state"]
		if state == PropState.Body.LOST:
			if was_state != PropState.Body.LOST and was_state != PropState.Body.FLOATING:
				cues.append(_at_crate(AudioCue.Kind.SPLASH, tick, entry))
			continue
		if state == PropState.Body.FLOATING:
			if was_state != PropState.Body.FLOATING:
				var lifted := _at_crate(AudioCue.Kind.SPLASH, tick, entry)
				lifted.gain = AFLOAT_GAIN
				cues.append(lifted)
			continue
		var vel: Vector3 = entry["vel"]
		var was: Vector3 = before["vel"]
		var speed := Vector2(vel.x, vel.z).length()
		var lost := Vector2(was.x, was.z).length() - speed
		var landed: bool = (
			before["state"] == PropState.Body.AIRBORNE and state == PropState.Body.GROUNDED
		)
		if landed or lost >= THUD_DROP:
			var thud := _at_crate(AudioCue.Kind.THUD, tick, entry)
			thud.gain = lerpf(CARGO_SOFT, 1.0, clampf(maxf(lost, -was.y) / THUD_LOUD, 0.0, 1.0))
			cues.append(thud)
		if state != PropState.Body.GROUNDED:
			continue
		_scrape[index] += speed * Ticks.SECONDS_PER_TICK / SCRAPE_STRIDE
		if _scrape[index] < 1.0:
			continue
		_scrape[index] = fposmod(_scrape[index], 1.0)
		var scrape := _at_crate(AudioCue.Kind.SCRAPE, tick, entry)
		scrape.gain = lerpf(CARGO_SOFT, 1.0, clampf(speed / SCRAPE_LOUD, 0.0, 1.0))
		cues.append(scrape)


## An effort as a body jumps; its landing is the LANDING event's thud.
func _take_off(then: Dictionary, now: Dictionary, tick: int, cues: Array[AudioCue]) -> void:
	if now["out"] or not now["jumped"] or then["jumped"]:
		return
	var effort := _at_seat(AudioCue.Kind.GRUNT, tick, now)
	effort.gain = JUMP_EFFORT
	cues.append(effort)


## What [param event] sounds like. Going into the sea splashes, climbing out lands
## wet with a small splash, and a climber shoved back in splashes heavy; an out by
## the cold is quiet — its splash was going in.
func _from_event(event: Dictionary, now: Dictionary, pose: ShipPose, cues: Array[AudioCue]) -> void:
	var tick: int = event["tick"]
	var seat: int = event["seat"]
	match event["kind"]:
		SimEvent.Kind.SHOVE_LANDED:
			var impact := _at_seat(AudioCue.Kind.IMPACT, tick, now[event["target"]])
			impact.heavy = _full_charge(now[seat])
			cues.append(impact)
		SimEvent.Kind.VAULTED:
			cues.append(_at_seat(AudioCue.Kind.VAULT, tick, now[seat]))
		SimEvent.Kind.FELL:
			cues.append(_at_seat(AudioCue.Kind.FALL, tick, now[seat]))
		SimEvent.Kind.LANDED:
			var cue := _at_seat(AudioCue.Kind.LANDING, tick, now[seat])
			var heavy := clampf(float(event["stagger"]) / LANDING_LOUD_TICKS, 0.0, 1.0)
			cue.gain = lerpf(LANDING_SOFT, 1.0, heavy)
			cue.ground = _ground(event["surface"], cue.position, pose)
			cues.append(cue)
		SimEvent.Kind.ENTERED_WATER:
			cues.append(_at_seat(AudioCue.Kind.SPLASH, tick, now[seat]))
		SimEvent.Kind.CLIMBED_OUT:
			var out := _at_seat(AudioCue.Kind.LANDING, tick, now[seat])
			out.gain = LANDING_SOFT
			out.ground = AudioCue.Ground.WET
			cues.append(out)
			var dripping := _at_seat(AudioCue.Kind.SPLASH, tick, now[seat])
			dripping.gain = CLIMB_OUT_SPLASH
			cues.append(dripping)
		SimEvent.Kind.CRATE_HIT:
			var thud := _at_seat(AudioCue.Kind.THUD, tick, now[seat])
			thud.heavy = true
			cues.append(thud)
		SimEvent.Kind.BOWLED:
			cues.append(_at_seat(AudioCue.Kind.IMPACT, tick, now[seat]))
		SimEvent.Kind.RAILING_BROKE:
			var crack := AudioCue.new(AudioCue.Kind.CRACK, tick)
			crack.positional = true
			crack.position = _layout.railing_middle(event["railing"], _railing_height * 0.5)
			cues.append(crack)
		SimEvent.Kind.KNOCKED_BACK_IN:
			var thrown := _at_seat(AudioCue.Kind.SPLASH, tick, now[seat])
			thrown.heavy = true
			cues.append(thrown)
		SimEvent.Kind.MATCH_ENDED:
			var won := seat == _local_seat and seat >= 0
			cues.append(
				AudioCue.new(AudioCue.Kind.WIN_STING if won else AudioCue.Kind.LOSS_STING, tick)
			)
		SimEvent.Kind.SHIP_LURCHING:
			var horn := AudioCue.new(AudioCue.Kind.HORN, tick)
			horn.positional = true
			horn.position = Vector3(_hull.get_center().x, 0.0, _hull.get_center().y)
			cues.append(horn)
		SimEvent.Kind.HOLED:
			_holed(tick, cues)
		SimEvent.Kind.FUNNEL_STRAINING, SimEvent.Kind.FUNNEL_FALLING:
			_funnel(event, tick, pose, cues)
		SimEvent.Kind.OPENING_GAVE_WAY:
			var bursting := AudioCue.new(AudioCue.Kind.CRACK, tick)
			bursting.positional = true
			bursting.position = _failing_at(event["cell"])
			bursting.heavy = true
			cues.append(bursting)
		SimEvent.Kind.KNOCKED_DOWN:
			var struck := _at_seat(AudioCue.Kind.IMPACT, tick, now[seat])
			struck.heavy = true
			cues.append(struck)
		SimEvent.Kind.PLATFORM_COLLAPSING, SimEvent.Kind.PLATFORM_COLLAPSED:
			var giving := AudioCue.new(AudioCue.Kind.COLLAPSE, tick)
			giving.positional = true
			giving.position = _platform_middle(event["platform"])
			if event["kind"] == SimEvent.Kind.PLATFORM_COLLAPSING:
				giving.gain = COLLAPSING_GAIN
			cues.append(giving)


## A funnel creaking as its stays strain — the creak players hear and bots read (D10) —
## and groaning as it goes, from its top.
func _funnel(event: Dictionary, tick: int, pose: ShipPose, cues: Array[AudioCue]) -> void:
	for fall: FunnelFall in pose.falls:
		if fall.fitting.name != event["cell"]:
			continue
		var straining: bool = event["kind"] == SimEvent.Kind.FUNNEL_STRAINING
		var cue := AudioCue.new(AudioCue.Kind.CREAK if straining else AudioCue.Kind.GROAN, tick)
		cue.positional = true
		cue.position = fall.fitting.base + Vector3.UP * fall.fitting.height
		cue.heavy = not straining
		cues.append(cue)


## Where the opening called [param named] stands — one shut until it fails, or a door
## the ship shuts — or her middle when it is neither.
func _failing_at(named: StringName) -> Vector3:
	var openings := _schedule.failing().duplicate()
	if _layout.structure != null:
		openings.append_array(_layout.structure.openings)
	for opening: ShipOpening in openings:
		if opening.name == named:
			return opening.centre
	return Vector3(_hull.get_center().x, 0.0, _hull.get_center().y)


## The iceberg striking: a boom from the middle of the gash SinkSchedule has her
## struck with, and the hull groaning from the keel under it.
func _holed(tick: int, cues: Array[AudioCue]) -> void:
	var damage := _schedule.damage()
	if damage == null or damage.trace.is_empty():
		return
	var gash := damage.trace[damage.trace.size() / 2]
	var boom := AudioCue.new(AudioCue.Kind.HOLED, tick)
	boom.positional = true
	boom.position = gash
	cues.append(boom)
	var groan := AudioCue.new(AudioCue.Kind.GROAN, tick)
	groan.positional = true
	groan.position = Vector3(gash.x, _keel, gash.z * 0.5)
	cues.append(groan)


## The ship complains as it lists and settles: creaks round the listener as the
## strain builds, and a groan from the keel at the end going under.
func _hull_strain(
	pose_then: ShipPose, pose_now: ShipPose, now: Dictionary, tick: int, cues: Array[AudioCue]
) -> void:
	var strain := (
		absf(pose_now.trim_deg - pose_then.trim_deg)
		+ absf(pose_now.heel_deg - pose_then.heel_deg)
		+ absf(pose_now.sink - pose_then.sink) * SINK_STRAIN
		+ SETTLE_STRAIN
	)
	_creak_strain += strain
	_groan_strain += strain
	if _creak_strain >= CREAK_STRAIN:
		_creak_strain = fposmod(_creak_strain, CREAK_STRAIN)
		var creak := AudioCue.new(AudioCue.Kind.CREAK, tick)
		creak.positional = true
		creak.position = _round_the_listener(now, tick)
		cues.append(creak)
	if _groan_strain >= GROAN_STRAIN:
		_groan_strain = fposmod(_groan_strain, GROAN_STRAIN)
		var groan := AudioCue.new(AudioCue.Kind.GROAN, tick)
		groan.positional = true
		groan.position = _low_end(pose_now)
		cues.append(groan)


## The sea breaking in and running on, each heard once as it comes and again only
## once it has stopped a while (_comes_on): a flood from the middle of a cell's floor
## as its water rises SHOWS over the floor's lowest corner, and from the middle of a
## platform as the water reaches it, which is when Surfaces calls it flooded — but for
## one in a cell, which floods with its cell, the one heard of the two first; and a
## pour from an opening's middle as it starts carrying water. WATER_CUES of them at most,
## the nearest the listener; the rest go unheard.
func _water(
	pose_then: ShipPose, pose_now: ShipPose, now: Dictionary, tick: int, cues: Array[AudioCue]
) -> void:
	var heard: Array[AudioCue] = []
	_water_coming_on(pose_then, pose_now, tick, heard)
	if heard.size() > WATER_CUES:
		var ears := _ears(now)
		heard.sort_custom(
			func(a: AudioCue, b: AudioCue) -> bool:
				return a.position.distance_squared_to(ears) < b.position.distance_squared_to(ears)
		)
		heard.resize(WATER_CUES)
	cues.append_array(heard)


## The cues of _water before any goes unheard.
func _water_coming_on(
	pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[AudioCue]
) -> void:
	var cells := _keeps_cells(pose_then) and _keeps_cells(pose_now)
	if cells:
		for cell in _floors.size():
			var was := _over_floor(cell, pose_then)
			if _comes_on(cell, was, _over_floor(cell, pose_now), tick, _cell_rearm):
				_flood_at(_floors[cell], tick, cues)
	for platform in _layout.platforms.size():
		var was := _surfaces.flooded(platform, pose_then)
		var slot := _platform_slots[platform]
		if not _comes_on(slot, was, _surfaces.flooded(platform, pose_now), tick, _cell_rearm):
			continue
		var middle := _layout.platforms[platform].area.get_center()
		_flood_at(Vector3(middle.x, _layout.platforms[platform].height, middle.y), tick, cues)
	if not cells:
		return
	for index in _openings.size():
		var slot := _floors.size() + index
		var was := _pouring(index, pose_then)
		if not _comes_on(slot, was, _pouring(index, pose_now), tick, _pour_rearm):
			continue
		var pour := AudioCue.new(AudioCue.Kind.POUR, tick)
		pour.positional = true
		pour.position = _openings[index].centre
		cues.append(pour)


## A flood from [param at].
func _flood_at(at: Vector3, tick: int, cues: Array[AudioCue]) -> void:
	var flood := AudioCue.new(AudioCue.Kind.FLOOD, tick)
	flood.positional = true
	flood.position = at
	cues.append(flood)


## Whether the water of [param slot] is heard coming on at [param tick]: on under the
## pose before it as [param was], under its own as [param now_on]. It is heard as it
## comes on, and once heard not again until it has stood off [param rearm] ticks, so
## water hovering at the edge is heard once, not on every crossing. On already when
## first asked about, it is taken as heard.
func _comes_on(slot: int, was: bool, now_on: bool, tick: int, rearm: int) -> bool:
	if now_on:
		_off_since[slot] = ON
	elif _off_since[slot] == ON:
		_off_since[slot] = tick
	elif _heard[slot] == 1 and tick - _off_since[slot] >= rearm:
		_heard[slot] = 0
	if not now_on or _heard[slot] == 1:
		return false
	_heard[slot] = 1
	return not was


## Whether opening [param index] carries water under [param pose]: open — a door
## the ship has not shut, one shut until it fails once it has — with one side's
## water over its bottom by SHOWS and over the other side's by POURS. That side holds
## water: the sea, or a cell wet over its floor — a dry cell's level is its floor, which
## stands over a doorway down into a lower cell.
func _pouring(index: int, pose: ShipPose) -> bool:
	var opening := _openings[index]
	var failed: int = pose.opened.get(opening.name, 0)
	if failed == 0 and (_shut[index] == 1 or pose.doors_shut.get(opening.name, 0.0) >= 1.0):
		return false
	var first := _sides[index * 2]
	var second := _sides[index * 2 + 1]
	var first_level := _side_level(first, pose)
	var second_level := _side_level(second, pose)
	var high := first if first_level >= second_level else second
	if high != -1 and not _over_floor(high, pose):
		return false
	var bottom := _lowest(pose, opening.centre, opening.size * 0.5)
	return (
		maxf(first_level, second_level) > bottom + SHOWS
		and absf(first_level - second_level) >= POURS
	)


## The world height of the water on side [param cell] of an opening: its cell's, or
## the sea's.
func _side_level(cell: int, pose: ShipPose) -> float:
	return 0.0 if cell == -1 else pose.levels[cell]


## Whether [param pose] keeps a level for each of her cells.
func _keeps_cells(pose: ShipPose) -> bool:
	return not _floors.is_empty() and pose.levels.size() == _floors.size()


## Whether cell [param cell]'s water stands SHOWS over its floor's lowest corner.
func _over_floor(cell: int, pose: ShipPose) -> bool:
	return pose.levels[cell] > _lowest(pose, _floors[cell], _floor_halves[cell]) + SHOWS


## The lowest world height under [param pose] of the box about [param centre] reaching
## [param half] each way.
static func _lowest(pose: ShipPose, centre: Vector3, half: Vector3) -> float:
	var basis := pose.transform.basis
	var row := Vector3(basis.x.y, basis.y.y, basis.z.y)
	var reach := absf(row.x) * half.x + absf(row.y) * half.y + absf(row.z) * half.z
	return row.dot(centre) - reach + pose.transform.origin.y


func _at_crate(kind: AudioCue.Kind, tick: int, entry: Dictionary) -> AudioCue:
	var cue := AudioCue.new(kind, tick)
	cue.position = entry["pos"]
	cue.positional = true
	return cue


func _at_seat(kind: AudioCue.Kind, tick: int, entry: Dictionary) -> AudioCue:
	var cue := AudioCue.new(kind, tick, entry["seat"])
	cue.position = entry["pos"]
	cue.positional = cue.seat != listener_seat
	return cue


func _ground(surface: int, feet: Vector3, pose: ShipPose) -> AudioCue.Ground:
	if pose.world_height(feet) - pose.water_level(feet) < WET_ABOVE:
		return AudioCue.Ground.WET
	# Planks are the platforms, numbered first; every surface after them — a stair
	# or a crate's lid — rings as metal.
	if surface != Surfaces.NONE and surface >= _surfaces.platform_count():
		return AudioCue.Ground.METAL
	return AudioCue.Ground.WOOD


## How deep the water stands over [param feet], as a share of wade_depth: 0 dry or
## in a film of it, 1 as deep as it gets before it takes them.
func _wading(feet: Vector3, pose: ShipPose) -> float:
	var depth := pose.water_level(feet) - pose.world_height(feet)
	return clampf(depth / _wade_depth, 0.0, 1.0)


## Somewhere in the deck within CREAK_SPREAD of the listener's feet — of the
## hull's middle when no seat is listening — walked round by the tick so creaks
## never come twice from one spot.
func _round_the_listener(now: Dictionary, tick: int) -> Vector3:
	var centre := _ears(now)
	var turn := tick * 2.39996
	var reach := CREAK_SPREAD * fposmod(tick * 0.618034, 1.0)
	return centre + Vector3(cos(turn) * reach, 0.0, sin(turn) * reach)


## The listener's feet, or the hull's middle when no seat is listening.
func _ears(now: Dictionary) -> Vector3:
	if now.has(listener_seat) and not now[listener_seat]["out"]:
		return now[listener_seat]["pos"]
	return Vector3(_hull.get_center().x, 0.0, _hull.get_center().y)


## The keel at whichever end and side the pose has lowest.
func _low_end(pose: ShipPose) -> Vector3:
	var middle := _hull.get_center()
	var x := middle.x + signf(pose.trim_deg) * _hull.size.x * 0.5
	var z := middle.y + signf(pose.heel_deg) * _hull.size.y * 0.25
	return Vector3(x, _keel, z)


## The middle of the first platform called [param platform_name], at its height:
## where a deck giving way is heard from.
func _platform_middle(platform_name: StringName) -> Vector3:
	for platform: ShipPlatform in _layout.platforms:
		if platform.name == platform_name:
			var middle := platform.area.get_center()
			return Vector3(middle.x, platform.height, middle.y)
	return Vector3(_hull.get_center().x, 0.0, _hull.get_center().y)


## Whether [param entry]'s shove carries a full charge (SH4).
func _full_charge(entry: Dictionary) -> bool:
	return entry["charge"] >= _charge_full


static func _by_seat(snapshot: Dictionary) -> Dictionary:
	var entries := {}
	for entry: Dictionary in snapshot["seats"]:
		entries[entry["seat"]] = entry
	return entries
