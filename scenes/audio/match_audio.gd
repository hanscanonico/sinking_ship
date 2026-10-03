class_name MatchAudio
extends Node3D
## The match as heard (D12). Every step the SimDriver takes, CuePlanner turns the
## two snapshots and the pose into cues, and they play — in the head for the seat
## whose eyes the view is in, from where they happen for everyone and everything
## else. Under them the sea, the wind and the sea rushing in follow the listener's
## height above the water and the sinking's pace, and the room's reverb and the
## hull's muffling follow whether the seat heard through stands in a room, easing
## across a doorway rather than snapping. The listener rides the current camera: a
## seat's eyes, a spectated seat's, or the observer's (D14). Reads snapshots,
## events, SinkSchedule's pose and the layout's rooms only (D5, D6); nothing it
## does reaches the sim.

signal cue_played(cue: AudioCue)

## How many cues may sound at once from places, and in the head.
const PLACED_VOICES := 32
const HEAD_VOICES := 8
const SEA := "beds/sea.ogg"
const WIND := "beds/wind.ogg"
const RUSH := "beds/rush.ogg"
## Seconds the mix takes to go from open deck to enclosed, or back.
const ENCLOSE_SECONDS := 0.25

var _driver: SimDriver
var _view: MatchView
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


# Leaves the buses open-deck for the menu, and nothing of the match sounding.
func _exit_tree() -> void:
	_set_enclosure(0.0)
	_silence()
	for bed: AudioStreamPlayer in [_sea, _wind, _rush]:
		bed.stop()


## Hears [param sim]'s match as [param driver] steps it, from the bodies [param view]
## draws; [param local_seat] is the one whose win is "you won".
func setup(driver: SimDriver, sim: MatchSim, view: MatchView, local_seat: int) -> void:
	_driver = driver
	_view = view
	_schedule = sim.schedule
	_layout = sim.config.ship
	_step_height = sim.config.rules.step_height
	_planner = CuePlanner.new(sim.config, sim.surfaces, sim.schedule, local_seat)
	if not _driver.stepped.is_connected(_on_stepped):
		_driver.stepped.connect(_on_stepped)
	_silence()
	_listener.make_current()
	for bed: AudioStreamPlayer in [_sea, _wind, _rush]:
		if SoundBank.audible() and not bed.playing:
			bed.play()


## Hears through [param seat]'s ears — its own sounds in the head — or through
## no seat's when it is -1 (the observer camera).
func hear_through(seat: int) -> void:
	if _planner != null:
		_planner.listener_seat = seat


# Runs after MatchScene (its process_priority), so the listener sits where the
# camera was put this frame.
func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if _driver == null or _driver.runner == null or camera == null:
		return
	_listener.global_transform = camera.global_transform
	# The sea is the world plane (D7), so the ears' height is their distance to it.
	var above_sea := camera.global_position.y - FirstPersonCamera.EYE_HEIGHT
	var tick: int = _driver.current["tick"]
	var sink_rate := _schedule.pose_at(tick).sink - _schedule.pose_at(tick - Ticks.RATE).sink
	_enclosure = move_toward(
		_enclosure, _enclosure_at(_planner.listener_seat), delta / ENCLOSE_SECONDS
	)
	_sea.volume_db = AmbienceMix.sea_db(above_sea)
	_wind.volume_db = AmbienceMix.wind_db(above_sea, _enclosure)
	_rush.volume_db = AmbienceMix.rush_db(sink_rate, above_sea)
	var sea_filter := _filter(&"Sea")
	if sea_filter != null:
		sea_filter.cutoff_hz = AmbienceMix.sea_cutoff_hz(above_sea)
	_set_enclosure(_enclosure)


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


## The room's reverb, and the outside heard through the hull.
func _set_enclosure(enclosure: float) -> void:
	var room := AudioServer.get_bus_index(SoundBank.ROOM_BUS)
	if room != -1:
		var reverb := AudioServer.get_bus_effect(room, 0) as AudioEffectReverb
		reverb.wet = AmbienceMix.reverb_wet(enclosure)
		AudioServer.set_bus_effect_enabled(room, 0, enclosure > 0.0)
	var outside := _filter(&"Ambience")
	if outside != null:
		outside.cutoff_hz = AmbienceMix.outside_cutoff_hz(enclosure)


## The low-pass filter on [param bus], or null when the layout has none.
func _filter(bus: StringName) -> AudioEffectLowPassFilter:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return null
	return AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter


func _bed(file: String, bus: StringName) -> AudioStreamPlayer:
	var bed := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(SoundBank.DIR + file)
	stream.loop = true
	bed.stream = stream
	bed.bus = bus
	bed.volume_db = AmbienceMix.SILENT_DB
	add_child(bed)
	return bed
