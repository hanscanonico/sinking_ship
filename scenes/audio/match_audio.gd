class_name MatchAudio
extends Node3D
## The match as heard (D12). Every step the SimDriver takes, CuePlanner turns the
## two snapshots and the pose into cues, and they play — in the head for the seat
## whose eyes the view is in, from where they happen for everyone and everything
## else. Under them the sea, the wind and the sea rushing in follow the listener's
## height above the water and the sinking's pace, and the room's reverb and the
## hull's muffling follow whether the seat heard through stands in a room, easing
## across a doorway rather than snapping; with its eyes under the sea, the outside
## is heard through the water, muffled, the wind gone. The listener rides the current
## camera: a seat's eyes, a spectated seat's, or the observer's (D14). Reads
## snapshots, events, SinkSchedule's pose, the layout's rooms and whether the eyes
## are under (Underwater.is_under) only (D5, D6); nothing it does reaches the sim.

signal cue_played(cue: AudioCue)

## How many cues may sound at once from places, and in the head.
const PLACED_VOICES := 32
const HEAD_VOICES := 8
const SEA := "beds/sea.ogg"
const WIND := "beds/wind.ogg"
const RUSH := "beds/rush.ogg"
## The water lapping in a part-flooded room: the sea's bed, pitched up.
const LAP_PITCH := 1.4
## Seconds the mix takes to go from open deck to enclosed, or back.
const ENCLOSE_SECONDS := 0.25
## Seconds the room's cues take to go muffled as the ears go under, or back, so a
## bob at the surface does not click.
const UNDER_SECONDS := 0.15
## No tick: a slot of the poses read (_pose_at) not read yet.
const NO_TICK := -(1 << 62)

var _driver: SimDriver
var _view: MatchView
var _underwater: Underwater
var _sim: MatchSim
var _local_seat := -1
var _schedule: SinkSchedule
var _layout: ShipLayout
var _step_height: float
## How enclosed the mix is now, 0…1, easing toward the room the seat stands in.
var _enclosure := 0.0
var _planner: CuePlanner
var _bank := SoundBank.new()
var _placed: Array[AudioStreamPlayer3D] = []
var _head: Array[AudioStreamPlayer] = []
var _next_placed := 0
var _next_head := 0
var _listener: AudioListener3D
var _sea: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _rush: AudioStreamPlayer
var _lap: AudioStreamPlayer
## The room's cutoff now, easing toward AmbienceMix.cue_cutoff_hz.
var _cue_hz := AmbienceMix.OPEN_HZ
## The index of each bus asked for by name, until the bus layout changes (_bus).
var _buses := {}
## The tick, and the seat heard through, the mix's snapshot and sinking parts were
## last read at, and what was read then: how enclosed the seat's feet are, how fast
## she sinks, and in the listener's cell how fast the water climbs (no cell, or no rise
## to hear: 0) and how deep it stands (none: -INF). Snapshots and poses are a tick's,
## so they are read again only as the tick, or the seat, changes.
var _mixed_tick := -1
var _mixed_seat := -1
var _enclosed := 0.0
var _sink_rate := 0.0
var _cell_rise := 0.0
var _cell_depth := -INF
## The enclosure, the ears under or not and the room's cutoff the buses were last set
## to (_set_enclosure), and the sea's cutoff, so each is set only as it changes; -1 for
## none yet.
var _set_enclosed := -1.0
var _set_under := false
var _set_hz := -1.0
var _set_sea_hz := -1.0
## The poses read, a second's worth, each in the slot of its tick (tick % slots): the
## pose a second before a tick is found here rather than built again, as SinkSchedule
## keeps only its last few; NO_TICK in a slot not read yet.
var _pose_ticks := PackedInt64Array()
var _poses: Array[ShipPose] = []


func _init() -> void:
	AudioServer.bus_layout_changed.connect(_forget_buses)


func _ready() -> void:
	_listener = AudioListener3D.new()
	_listener.name = "Listener"
	add_child(_listener)
	for _voice in PLACED_VOICES:
		var placed := AudioStreamPlayer3D.new()
		placed.bus = SoundBank.ROOM_BUS
		add_child(placed)
		_placed.append(placed)
	for _voice in HEAD_VOICES:
		var head := AudioStreamPlayer.new()
		add_child(head)
		_head.append(head)
	_sea = _bed(SEA, &"Sea")
	_wind = _bed(WIND, &"Ambience")
	_rush = _bed(RUSH, SoundBank.ROOM_BUS)
	_lap = _bed(SEA, SoundBank.ROOM_BUS)
	_lap.pitch_scale = LAP_PITCH


# Leaves the buses open-deck for the menu, and nothing of the match sounding.
func _exit_tree() -> void:
	_set_enclosure(0.0)
	_silence()
	for bed: AudioStreamPlayer in [_sea, _wind, _rush, _lap]:
		bed.stop()


## Hears [param sim]'s match as [param driver] steps it, from the bodies [param view]
## draws; [param local_seat] is the one whose win is "you won". [param underwater]
## says when the eyes heard through are under the sea.
func setup(
	driver: SimDriver, sim: MatchSim, view: MatchView, local_seat: int, underwater: Underwater
) -> void:
	_driver = driver
	_view = view
	_underwater = underwater
	_sim = sim
	_local_seat = local_seat
	_schedule = sim.schedule
	_layout = sim.config.ship
	_step_height = sim.config.rules.step_height
	_planner = CuePlanner.new(sim.config, sim.surfaces, sim.schedule, local_seat)
	_mixed_tick = -1
	_set_enclosed = -1.0
	_set_sea_hz = -1.0
	_forget_poses()
	if not _driver.stepped.is_connected(_on_stepped):
		_driver.stepped.connect(_on_stepped)
	_silence()
	_listener.make_current()
	for bed: AudioStreamPlayer in [_sea, _wind, _rush, _lap]:
		if SoundBank.audible() and not bed.playing:
			bed.play()


## Forgets what it has heard of the match so far — a replay sought elsewhere (D5): the
## cues plan again from the snapshot, every voice silenced.
func rewind() -> void:
	if _planner == null:
		return
	var heard_through := _planner.listener_seat
	_planner = CuePlanner.new(_sim.config, _sim.surfaces, _sim.schedule, _local_seat)
	_planner.listener_seat = heard_through
	_mixed_tick = -1
	_silence()


## Hears through [param seat]'s ears — its own sounds in the head — or through
## no seat's when it is -1 (the observer camera).
func hear_through(seat: int) -> void:
	if _planner != null:
		_planner.listener_seat = seat


# Runs after MatchScene (its process_priority), so the listener sits where the
# camera was put this frame.
func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if _driver == null or not _driver.started() or camera == null:
		return
	_listener.global_transform = camera.global_transform
	# The sea is the world plane (D7), so the ears' height is their distance to it.
	var above_sea := camera.global_position.y - FirstPersonCamera.eye_height_of(camera)
	var tick: int = _driver.current["tick"]
	var seat := _planner.listener_seat
	if tick != _mixed_tick or seat != _mixed_seat:
		_mixed_tick = tick
		_mixed_seat = seat
		_read_sinking(tick, camera.global_position)
		_enclosed = _enclosure_at(seat)
	_enclosure = move_toward(_enclosure, _enclosed, delta / ENCLOSE_SECONDS)
	_sea.volume_db = AmbienceMix.sea_db(above_sea)
	var under := _underwater.is_under()
	_wind.volume_db = AmbienceMix.wind_db(above_sea, _enclosure, under)
	var rush := AmbienceMix.rush_db(_sink_rate, above_sea)
	rush = maxf(rush, AmbienceMix.cell_rush_db(_cell_rise, under))
	_rush.volume_db = rush
	_lap.volume_db = AmbienceMix.lap_db(_cell_depth, under)
	var sea_hz := AmbienceMix.sea_cutoff_hz(above_sea)
	if sea_hz != _set_sea_hz:
		var sea_filter := _filter(&"Sea")
		if sea_filter != null:
			sea_filter.cutoff_hz = sea_hz
		_set_sea_hz = sea_hz
	_set_enclosure(_enclosure, under, delta)


## Reads the sinking's part of the mix at [param tick], with the ears at
## [param ears] (world space): how fast she sinks over the second to it, and the
## listener's own cell — the water rising in it, and how deep it stands.
func _read_sinking(tick: int, ears: Vector3) -> void:
	var pose := _pose_at(tick)
	var before := _pose_at(tick - Ticks.RATE)
	_sink_rate = pose.sink - before.sink
	_cell_rise = 0.0
	_cell_depth = -INF
	var at := _view.ship_to_world().affine_inverse() * ears
	var cell := pose.cell_at(at)
	if cell == CellMap.NONE:
		return
	if before.levels.size() == pose.levels.size():
		_cell_rise = AmbienceMix.cell_rise(pose, before, cell)
	var floor_point := Vector3(at.x, pose.cells.floor_of(cell), at.z)
	_cell_depth = pose.levels[cell] - pose.world_height(floor_point)


## Her pose at [param tick]: the one read for it within the last second, else
## SinkSchedule's.
func _pose_at(tick: int) -> ShipPose:
	var slot := posmod(tick, _poses.size())
	if _pose_ticks[slot] != tick:
		_pose_ticks[slot] = tick
		_poses[slot] = _schedule.pose_at(tick)
	return _poses[slot]


func _forget_poses() -> void:
	_poses.resize(Ticks.RATE + 1)
	_poses.fill(null)
	_pose_ticks.resize(Ticks.RATE + 1)
	_pose_ticks.fill(NO_TICK)


func _on_stepped(_events: Array[SimEvent]) -> void:
	for cue: AudioCue in _planner.plan(_driver.previous, _driver.current):
		if SoundBank.audible():
			_play(cue)
		cue_played.emit(cue)


func _play(cue: AudioCue) -> void:
	var stream := _bank.stream(cue.kind, cue.ground)
	var level := SoundBank.db(cue.kind) + linear_to_db(cue.gain)
	var pitch := SoundBank.pitch(cue.kind)
	if cue.heavy:
		level += SoundBank.HEAVY_DB
		pitch *= SoundBank.HEAVY_PITCH
	if cue.positional:
		var placed := _idle(_placed, _next_placed)
		_next_placed = (placed + 1) % _placed.size()
		var voice := _placed[placed]
		voice.stream = stream
		voice.volume_db = level
		voice.unit_size = SoundBank.near(cue.kind)
		voice.max_distance = SoundBank.far(cue.kind)
		voice.pitch_scale = pitch
		voice.global_position = (
			_view.seat_world_position(cue.seat)
			if cue.seat >= 0
			else _view.ship_to_world() * cue.position
		)
		voice.play()
		return
	var in_head := _idle(_head, _next_head)
	_next_head = (in_head + 1) % _head.size()
	var head := _head[in_head]
	head.stream = stream
	head.bus = SoundBank.bus(cue.kind)
	head.volume_db = level + (SoundBank.IN_HEAD_DB if cue.seat >= 0 else 0.0)
	head.pitch_scale = pitch
	head.play()


## The first of [param voices] from [param from] on that has finished, so a crowd's
## footfalls do not cut off a groan or a flood still sounding; [param from] itself,
## the one started longest ago, when every voice is busy.
static func _idle(voices: Array, from: int) -> int:
	for offset in voices.size():
		var index := (from + offset) % voices.size()
		if not voices[index].playing:
			return index
	return from


## Stops every cue still sounding.
func _silence() -> void:
	for voice: AudioStreamPlayer3D in _placed:
		voice.stop()
	for voice: AudioStreamPlayer in _head:
		voice.stop()


## How enclosed [param seat]'s feet are on the latest snapshot: 1 in a room, 0 on
## open deck, once out, and for the observer camera (-1).
func _enclosure_at(seat: int) -> float:
	if seat < 0:
		return 0.0
	var entry: Dictionary = _driver.current["seats"][seat]
	if entry["out"]:
		return 0.0
	return AmbienceMix.enclosure(_layout, entry["pos"], _step_height)


## The room's reverb, and the outside heard through the hull — or the sea; with the
## ears under, the room's cues muffled too, eased over [param delta] seconds (at once
## when it is negative). Nothing is set again while none of it has changed.
func _set_enclosure(enclosure: float, under: bool = false, delta: float = -1.0) -> void:
	var target := AmbienceMix.cue_cutoff_hz(under)
	if (
		delta >= 0.0
		and _cue_hz == target
		and enclosure == _set_enclosed
		and under == _set_under
		and _cue_hz == _set_hz
	):
		return
	var room := _bus(SoundBank.ROOM_BUS)
	if room != -1:
		var reverb := AudioServer.get_bus_effect(room, 0) as AudioEffectReverb
		reverb.wet = AmbienceMix.reverb_wet(enclosure)
		AudioServer.set_bus_effect_enabled(room, 0, enclosure > 0.0)
		if delta < 0.0:
			_cue_hz = target
		else:
			# Evenly in octaves, as the ear hears a cutoff move.
			var octaves := log(AmbienceMix.OPEN_HZ / AmbienceMix.UNDER_CUE_HZ) / log(2.0)
			var now := log(_cue_hz) / log(2.0)
			var goal := log(target) / log(2.0)
			now = move_toward(now, goal, octaves * delta / UNDER_SECONDS)
			_cue_hz = target if now == goal else pow(2.0, now)
		if AudioServer.get_bus_effect_count(room) > 1:
			var muffle := AudioServer.get_bus_effect(room, 1) as AudioEffectLowPassFilter
			if muffle != null:
				muffle.cutoff_hz = _cue_hz
	var outside := _filter(&"Ambience")
	if outside != null:
		outside.cutoff_hz = AmbienceMix.outside_cutoff_hz(enclosure, under)
	_set_enclosed = enclosure
	_set_under = under
	_set_hz = _cue_hz


## The low-pass filter on [param bus], or null when the layout has none.
func _filter(bus: StringName) -> AudioEffectLowPassFilter:
	var index := _bus(bus)
	if index == -1:
		return null
	return AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter


## The index of the bus named [param bus], -1 when the layout has none: looked up by
## name once, and again whenever the layout changes or the index kept has gone.
func _bus(bus: StringName) -> int:
	var index: int = _buses.get(bus, -1)
	if index == -1 or index >= AudioServer.bus_count:
		index = AudioServer.get_bus_index(bus)
		_buses[bus] = index
	return index


## Forgets every bus's index, and what they were set to: the layout has changed.
func _forget_buses() -> void:
	_buses.clear()
	_set_enclosed = -1.0
	_set_sea_hz = -1.0


func _bed(file: String, bus: StringName) -> AudioStreamPlayer:
	var bed := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(SoundBank.DIR + file)
	stream.loop = true
	bed.stream = stream
	bed.bus = bus
	bed.volume_db = AmbienceMix.SILENT_DB
	add_child(bed)
	return bed
