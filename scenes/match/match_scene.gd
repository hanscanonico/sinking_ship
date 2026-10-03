class_name MatchScene
extends Node3D
## One match of the config Game hands in — the local player on the first seat (a
## bot when autoplaying), bots of the config's tier on the rest — seen through the
## local seat's eyes and, once it is out, through a survivor's (D14), with the
## results at its end. The observer camera stands in for the eyes only as a tool:
## for --observer and captures. Rematch and menu go back to Game, which builds
## every config through MatchConfig.from_menu (D13).

signal rematch_requested
signal menu_requested

const LOCAL_SEAT := 0
## The gaze through another seat's eyes, in degrees above the horizon: at a level
## gaze the deck within about 3 m of the feet is under the frame.
const SPECTATE_PITCH_DEG := -10.0

var _config: MatchConfig
var _stats: MatchStats
var _order: SpectateOrder
var _names := PackedStringArray()
## The local player's seat when a person plays it; null when a bot does.
var _local: LocalInputSource
var _observer: bool
## Whose eyes the view is in while that seat is dry: the local seat's, or a capture's.
var _eye_seat := LOCAL_SEAT
var _paused := false

@onready var _driver: SimDriver = $SimDriver
@onready var _view: MatchView = $MatchView
@onready var _observer_camera: ObserverCamera = $ObserverCamera
@onready var _eyes: FirstPersonCamera = $FirstPersonCamera
@onready var _hud: Hud = $Hud
@onready var _first_person_hud: FirstPersonHud = $FirstPersonHud
@onready var _end: EndOverlay = $EndOverlay


func _ready() -> void:
	_end.rematch_requested.connect(rematch_requested.emit)
	_end.menu_requested.connect(menu_requested.emit)
	_driver.stepped.connect(func(events: Array[SimEvent]) -> void: _stats.add(events))


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Runs after MatchView (the scene's process_priority), so the eyes sit on the bodies
# as drawn this frame.
func _process(delta: float) -> void:
	if _driver.runner == null:
		return
	var snapshot := _driver.current
	var viewed := _order.target(snapshot)
	_hud.show_snapshot(snapshot)
	_hud.show_spectating(_spectating(snapshot, viewed))
	_end.show_results(_stats, LOCAL_SEAT, _names, _config.match_seed)
	var mouse := Input.MOUSE_MODE_CAPTURED if _looking() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mouse:
		Input.mouse_mode = mouse
	if _looking():
		_local.look_by_stick(delta)
	if _observer:
		_observer_camera.follow(_view.seat_world_position(viewed), delta)
		_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)
		return
	# Another seat's pitch never leaves its client, so its gaze is fixed (D14): a
	# little below level, so the deck and its edges show under the horizon.
	var yaw := _view.seat_facing(viewed)
	var pitch := deg_to_rad(SPECTATE_PITCH_DEG)
	if _local != null and viewed == LOCAL_SEAT:
		yaw = _local.yaw
		pitch = _local.pitch
	_view.look_out_of(viewed)
	_eyes.look_from(_view.ship_to_world(), _view.seat_feet(viewed), yaw, pitch)
	_first_person_hud.show_view(snapshot, viewed, yaw, _eyes, _view)


func _unhandled_input(event: InputEvent) -> void:
	if _driver.runner == null:
		return
	if event is InputEventMouseMotion:
		if _looking():
			_local.look_by_mouse((event as InputEventMouseMotion).screen_relative)
		return
	if _end.visible and event.is_action_pressed("restart"):
		rematch_requested.emit()
	elif _end.visible and event.is_action_pressed("pause"):
		menu_requested.emit()
	elif event.is_action_pressed("spectate_next"):
		_order.cycle(_driver.current, 1)
	elif event.is_action_pressed("spectate_previous"):
		_order.cycle(_driver.current, -1)
	else:
		return
	get_viewport().set_input_as_handled()


## Starts [param config]'s match from its first tick; [param autoplay] puts a bot
## on the local seat. The view is [param eye_seat]'s eyes, or the observer camera
## when [param observer] says so.
func start(
	config: MatchConfig, autoplay: bool, observer: bool = false, eye_seat: int = LOCAL_SEAT
) -> void:
	_config = config
	_observer = observer
	_eye_seat = eye_seat
	var profile := BotProfile.for_tier(config.bot_tier)
	var sim := MatchSim.create(config)
	var settings := ViewSettings.local()
	var sources: Array[InputSource] = []
	_local = null
	if config.humans > 0 and not autoplay:
		var facing: float = sim.snapshot()["seats"][LOCAL_SEAT]["facing"]
		_local = LocalInputSource.new(LOCAL_SEAT, facing, settings)
		sources.append(_local)
	else:
		sources.append(BotInputSource.new(LOCAL_SEAT, profile, config))
	sources.append_array(BotInputSource.fill(config, profile, LOCAL_SEAT + 1))
	_stats = MatchStats.new(config.seats, config.countdown_ticks)
	_order = SpectateOrder.new(_eye_seat, _stats)
	_names = _seat_names(config.seats)
	_driver.start(MatchRunner.new(sim, sources))
	_view.setup(_driver, sim, LOCAL_SEAT)
	_view.look_out_of(-1 if observer else _eye_seat)
	_hud.setup(sim)
	_eyes.setup(settings)
	_first_person_hud.setup(sim, _names, not observer)
	_observer_camera.reset(_view.seat_world_position(_eye_seat), _deck_bounds(config.ship))
	if observer:
		_observer_camera.make_current()
	else:
		_eyes.make_current()
	_end.hide()
	print("match seed %d" % config.match_seed)


## The latest snapshot.
func current() -> Dictionary:
	return _driver.current


## Whether the latest snapshot says the match has ended.
func is_over() -> bool:
	return _driver.current.get("phase", -1) == MatchState.Phase.ENDED


## Pausing stops the SimDriver and nothing else: it is never sim state. The mouse
## is freed while paused.
func set_paused(paused: bool) -> void:
	_paused = paused
	_driver.set_process(not paused)


## Whether the local player's mouse and stick turn their look now: in play, and
## neither paused nor at the results.
func _looking() -> bool:
	return _local != null and not _paused and not _end.visible


## Every platform's area together, in the ship plane.
func _deck_bounds(layout: ShipLayout) -> Rect2:
	var bounds := layout.platforms[0].area
	for platform: ShipPlatform in layout.platforms:
		bounds = bounds.merge(platform.area)
	return bounds


static func _seat_names(seats: int) -> PackedStringArray:
	var names := PackedStringArray(["You"])
	for seat in range(LOCAL_SEAT + 1, seats):
		names.append("Bot %d" % seat)
	return names


## The banner while the eye seat is out and the match goes on, naming whose eyes
## the view is in; empty otherwise.
func _spectating(snapshot: Dictionary, viewed: int) -> String:
	var seats: Array = snapshot["seats"]
	var mine: Dictionary = seats[_eye_seat]
	if not mine["out"] or snapshot["phase"] == MatchState.Phase.ENDED:
		return ""
	var whose := ("watching %s" if _observer else "through %s's eyes") % _names[viewed]
	return (
		"Overboard — %s of %d   ·   %s   ·   Q / E or d-pad to switch"
		% [EndOverlay.ordinal(mine["place"]), seats.size(), whose]
	)
