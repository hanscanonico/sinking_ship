class_name CuePlanner
extends RefCounted
## Turns one step of the match into the sounds it makes (D12): the snapshot before
## it, the snapshot after it with the events it carries, and the ship's pose at
## both ticks as SinkSchedule answers them (D7). Nothing else — no live seat, no
## sim (D5). Its own memory, how far through a stride each seat is and how far the
## hull has strained since it last complained, is presentation state; nothing it
## does reaches the sim.

## Metres between footfalls, so steps land with the drawn feet: each locomotion
## clip's speed times its length (Walk 1.33 s, Jog_Fwd 0.93 s), over two feet.
const WALK_STRIDE := BrawlerAnimation.WALK_CLIP_SPEED * 1.333 / 2.0
const RUN_STRIDE := BrawlerAnimation.RUN_CLIP_SPEED * 0.933 / 2.0
## The quietest footfall, at a stroll; a full run is 1.
const STEP_SOFT := 0.45
## Feet this close above the sea splash as they step, in metres.
const WET_ABOVE := 0.3
## A landing that costs no stagger still thuds this loud; one that costs
## LANDING_LOUD_TICKS or more lands at full.
const LANDING_SOFT := 0.35
const LANDING_LOUD_TICKS := 12
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

## The seat whose ears the view is in: its own sounds are in the head. -1 when
## no seat's are (the observer camera).
var listener_seat := -1

var _surfaces: Surfaces
var _schedule: SinkSchedule
var _layout: ShipLayout
var _walk_speed: float
## Ticks of charge that make a shove a full one, heard heavy.
var _charge_full: int
## The seat that is "you" for the end of the match.
var _local_seat: int
## Every platform's area together, in the ship plane.
var _hull: Rect2
## The height the hull groans from: KEEL_BELOW under the lowest platform.
var _keel := INF
## How far through its stride each seat is, 0…1.
var _stride := PackedFloat32Array()
var _creak_strain := 0.0
var _groan_strain := 0.0


func _init(
	config: MatchConfig, surfaces: Surfaces, schedule: SinkSchedule, local_seat: int
) -> void:
	_surfaces = surfaces
	_schedule = schedule
	_layout = config.ship
	_walk_speed = config.rules.walk_speed
	_charge_full = Ticks.from_seconds(config.rules.charge_full)
	_local_seat = local_seat
	_hull = _layout.platforms[0].area
	for platform: ShipPlatform in _layout.platforms:
		_hull = _hull.merge(platform.area)
		_keel = minf(_keel, platform.height - KEEL_BELOW)
	_stride.resize(config.seats)
	_stride.fill(0.5)


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
	for event: Dictionary in current["events"]:
		_from_event(event, now, pose_now, cues)
	if current["phase"] == MatchState.Phase.LIVE:
		_hull_strain(pose_then, pose_now, now, tick, cues)
	_floods(pose_then, pose_now, tick, cues)
	return cues


## A footfall each stride while the feet are drawn walking or running; a body
## frozen in a hit-stop holds its stride without a sound.
func _footstep(entry: Dictionary, pose: ShipPose, tick: int, cues: Array[AudioCue]) -> void:
	if entry["hitstop"] > 0:
		return
	var seat: int = entry["seat"]
	var vel: Vector3 = entry["vel"]
	var speed := Vector2(vel.x, vel.z).length()
	var move := BrawlerAnimation.move_for(entry, speed)
	if entry["out"] or (move != BrawlerAnimation.Move.WALK and move != BrawlerAnimation.Move.RUN):
		_stride[seat] = 0.5
		return
	var stride := RUN_STRIDE if move == BrawlerAnimation.Move.RUN else WALK_STRIDE
	_stride[seat] += speed * Ticks.SECONDS_PER_TICK / stride
	if _stride[seat] < 1.0:
		return
	_stride[seat] = fposmod(_stride[seat], 1.0)
	var cue := _at_seat(AudioCue.Kind.FOOTSTEP, tick, entry)
	cue.gain = lerpf(STEP_SOFT, 1.0, clampf(speed / _walk_speed, 0.0, 1.0))
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
		SimEvent.Kind.SEAT_OUT:
			if event["cause"] == PlayerState.Cause.WATER:
				cues.append(_at_seat(AudioCue.Kind.SPLASH, tick, now[seat]))
		SimEvent.Kind.MATCH_ENDED:
			var won := seat == _local_seat and seat >= 0
			cues.append(
				AudioCue.new(AudioCue.Kind.WIN_STING if won else AudioCue.Kind.LOSS_STING, tick)
			)


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


## The sea rushing in: a flood from the middle of each platform as the water
## reaches it, which is when Surfaces calls it flooded.
func _floods(pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[AudioCue]) -> void:
	for platform in _layout.platforms.size():
		if not _surfaces.flooded(platform, pose_now) or _surfaces.flooded(platform, pose_then):
			continue
		var area := _layout.platforms[platform].area
		var flood := AudioCue.new(AudioCue.Kind.FLOOD, tick)
		flood.positional = true
		var middle := area.get_center()
		flood.position = Vector3(middle.x, _layout.platforms[platform].height, middle.y)
		cues.append(flood)


func _at_seat(kind: AudioCue.Kind, tick: int, entry: Dictionary) -> AudioCue:
	var cue := AudioCue.new(kind, tick, entry["seat"])
	cue.position = entry["pos"]
	cue.positional = cue.seat != listener_seat
	return cue


func _ground(surface: int, feet: Vector3, pose: ShipPose) -> AudioCue.Ground:
	if pose.world_height(feet) < WET_ABOVE:
		return AudioCue.Ground.WET
	# Planks are the platforms, numbered first; every surface after them — a stair
	# or a crate's lid — rings as metal.
	if surface != Surfaces.NONE and surface >= _surfaces.platform_count():
		return AudioCue.Ground.METAL
	return AudioCue.Ground.WOOD


## Somewhere in the deck within CREAK_SPREAD of the listener's feet — of the
## hull's middle when no seat is listening — walked round by the tick so creaks
## never come twice from one spot.
func _round_the_listener(now: Dictionary, tick: int) -> Vector3:
	var centre := Vector3(_hull.get_center().x, 0.0, _hull.get_center().y)
	if now.has(listener_seat) and not now[listener_seat]["out"]:
		centre = now[listener_seat]["pos"]
	var turn := tick * 2.39996
	var reach := CREAK_SPREAD * fposmod(tick * 0.618034, 1.0)
	return centre + Vector3(cos(turn) * reach, 0.0, sin(turn) * reach)


## The keel at whichever end and side the pose has lowest.
func _low_end(pose: ShipPose) -> Vector3:
	var middle := _hull.get_center()
	var x := middle.x + signf(pose.trim_deg) * _hull.size.x * 0.5
	var z := middle.y + signf(pose.heel_deg) * _hull.size.y * 0.25
	return Vector3(x, _keel, z)


## Whether [param entry]'s shove carries a full charge (SH4).
func _full_charge(entry: Dictionary) -> bool:
	return entry["charge"] >= _charge_full


static func _by_seat(snapshot: Dictionary) -> Dictionary:
	var entries := {}
	for entry: Dictionary in snapshot["seats"]:
		entries[entry["seat"]] = entry
	return entries
