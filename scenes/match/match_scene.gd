class_name MatchScene
extends Node3D
## One match of the config Game hands in — the local player on the first seat (a
## bot when autoplaying), bots of the config's tier on the rest — or one played on a
## server, the local player on the seat it gives (SH12) — seen through the local
## seat's eyes and, once it is out, through a survivor's (D14), with the results at
## its end. The observer camera stands in for the eyes only as a tool: for --observer
## and captures, and it alone may cut the ship away to look inside. Rematch and menu
## go back to whoever started it: Game, which builds every config through
## MatchConfig.from_menu (D13), or OnlinePlay.

signal rematch_requested
signal menu_requested
## A browser let go of the mouse mid-match at the player's Esc, which this never hears.
signal pointer_lost

const LOCAL_SEAT := 0
## The gaze through another seat's eyes, in degrees above the horizon: at a level
## gaze the deck within about 3 m of the feet is under the frame.
const SPECTATE_PITCH_DEG := -10.0
## The view's shake, 0…1 of a lurch's, as a lurch is telegraphed and as a deck
## collapses.
const LURCH_WARNING_SHAKE := 0.4
const COLLAPSE_SHAKE := 0.6
## The observer's framing of the cells: lower and further off than its own, so the
## cells stacked under the decks stand apart and the ship shows end to end.
const CELLS_PITCH_DEG := 25.0
const CELLS_DISTANCE := 33.0

var _config: MatchConfig
var _stats: MatchStats
var _order: SpectateOrder
var _names := PackedStringArray()
## The local player's seat when a person plays it; null when a bot does.
var _local: LocalInputSource
## The seat whose win is "you won", and whose look the local player turns.
var _local_seat := LOCAL_SEAT
var _observer: bool
## Whose eyes the view is in while that seat is dry: the local seat's, or a capture's.
var _eye_seat := LOCAL_SEAT
## A capture's eyes, standing apart from the seat they look through: feet x, y, z
## in ship space, yaw and pitch in degrees (--capture-from); empty for the seat's own.
var _staged := PackedFloat64Array()
var _paused := false
## Whether the match is played on a server: started by start_online.
var _online := false
## The mouse let go mid-match without pausing, a menu over the match having it, the keys
## and the pad: an online match never pauses.
var _mouse_freed := false
var _marks := BrawlMarks.new()
var _dust := LandingDust.new()
var _fx := SinkingFx.new()
var _prompts := InputPrompts.new()
var _pointer := PointerCapture.new()
var _kick: ViewKick
## The ship's cells over the observer's view, once show_cells() asks for them.
var _cells: CellOverlay
## The free camera the local seat may fly once it is out, in place of a seat's eyes.
var _free := FreeCamera.new()

@onready var _sea_and_sky: SeaAndSky = $SeaAndSky
@onready var _driver: SimDriver = $SimDriver
@onready var _view: MatchView = $MatchView
@onready var _greybox: ShipGreybox = $MatchView/Ship/Greybox
@onready var _ship_art: ShipArt = $MatchView/Ship/ShipArt
@onready var _observer_camera: ObserverCamera = $ObserverCamera
@onready var _eyes: FirstPersonCamera = $FirstPersonCamera
@onready var _arms: FirstPersonArms = $FirstPersonCamera/Arms
@onready var _hud: Hud = $Hud
@onready var _first_person_hud: FirstPersonHud = $FirstPersonHud
@onready var _underwater: Underwater = $Underwater
@onready var _end: EndOverlay = $EndOverlay
@onready var _audio: MatchAudio = $Audio


func _ready() -> void:
	_end.rematch_requested.connect(rematch_requested.emit)
	_end.menu_requested.connect(menu_requested.emit)
	_driver.stepped.connect(func(events: Array[SimEvent]) -> void: _stats.add(events))
	_driver.stepped.connect(_shake_for_the_sinking)
	add_child(_marks)
	add_child(_dust)
	add_child(_fx)
	add_child(FxWarmUp.new(_fx.emitters()))
	add_child(_prompts)
	add_child(_pointer)
	_pointer.lost.connect(pointer_lost.emit)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Runs after MatchView (the scene's process_priority), so the eyes sit on the bodies
# as drawn this frame.
func _process(delta: float) -> void:
	if _driver.client == null:
		return
	var snapshot := _driver.current
	var viewed := _order.target(snapshot)
	_hud.show_snapshot(snapshot)
	_sea_and_sky.show_sinking(snapshot["tick"], _view.ship_to_world())
	if _cells != null:
		var pose := _driver.client.sim.schedule.pose_at(snapshot["tick"])
		_cells.show_water(pose, _view.ship_to_world())
	_hud.show_spectating(_spectating(snapshot, viewed))
	_hud.show_controls(_prompts if _local != null else null)
	_end.show_results(_stats, _local_seat, _names, _config.match_seed)
	if _end.visible:
		_end.show_prompts(_prompts)
	_free.keep(_can_fly(snapshot))
	_pointer.want(_looking() or _flying())
	_hold()
	if _looking() and not _free.active:
		_local.look_by_stick(delta)
	_audio.hear_through(-1 if _observer or _free.active else viewed)
	_first_person_hud.flying = _free.active
	if _observer:
		_observer_camera.follow(_view.seat_world_position(viewed), delta)
		_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)
		return
	if _free.active:
		_fly(snapshot, viewed, delta)
		return
	# Another seat's pitch never leaves its client, so its gaze is fixed (D14): a
	# little below level, so the deck and its edges show under the horizon.
	var yaw := _view.seat_facing(viewed)
	var pitch := deg_to_rad(SPECTATE_PITCH_DEG)
	var feet := _view.seat_feet(viewed)
	if _local != null and viewed == _local_seat:
		yaw = _local.yaw
		pitch = _local.pitch
	if _staged.size() >= 5:
		feet = Vector3(_staged[0], _staged[1], _staged[2])
		yaw = deg_to_rad(_staged[3])
		pitch = deg_to_rad(_staged[4])
	_view.look_out_of(viewed)
	_kick.follow(snapshot, viewed, yaw)
	var kick := _kick.advance(delta)
	_eyes.look_from(_view.ship_to_world(), feet, yaw, pitch, kick)
	_arms.visible = _staged.is_empty()
	if _staged.is_empty():
		_arms.show_seat(
			viewed, _driver.previous["seats"][viewed], snapshot["seats"][viewed], _driver.alpha
		)
	_underwater.show_eye(_eyes.global_position, _view.above_water(_eyes.global_position))
	_first_person_hud.show_view(snapshot, viewed, yaw, _eyes, _view)


func _unhandled_input(event: InputEvent) -> void:
	if _driver.client == null or _mouse_freed:
		return
	if event is InputEventMouseMotion:
		if _flying():
			_free.look_by_mouse((event as InputEventMouseMotion).screen_relative)
		elif _looking():
			_local.look_by_mouse((event as InputEventMouseMotion).screen_relative)
		return
	if _end.visible and event.is_action_pressed("restart"):
		rematch_requested.emit()
	elif _end.visible and event.is_action_pressed("pause"):
		menu_requested.emit()
	elif event.is_action_pressed("spectate_free") and _can_fly(_driver.current):
		_toggle_free()
	elif event.is_action_pressed("spectate_next"):
		_free.leave()
		_order.cycle(_driver.current, 1)
	elif event.is_action_pressed("spectate_previous"):
		_free.leave()
		_order.cycle(_driver.current, -1)
	else:
		return
	get_viewport().set_input_as_handled()


## Starts [param config]'s match from its first tick, served by a local host and
## seen through a client over a loopback that lies as [param net_sim] says — not at
## all, without it (SH11). [param autoplay] puts a bot on the local seat: the host's,
## as every bot is (D10), so the client only watches and the match is the one
## `make match` plays for the seed. The view is [param eye_seat]'s eyes, or the
## observer camera when [param observer] says so — which draws nothing of the ship at
## or above the ship-local height [param observer_cut] and frames the whole ship once
## it is finite. [param greybox] draws the greybox in place of the dressed ship.
func start(
	config: MatchConfig,
	autoplay: bool,
	observer: bool = false,
	eye_seat: int = LOCAL_SEAT,
	observer_cut: float = INF,
	greybox: bool = false,
	net_sim: NetConditions = null
) -> void:
	var profile := BotProfile.for_tier(config.bot_tier)
	var net_rules := NetRules.load_default()
	var played := -1
	var served: Array[InputSource] = []
	var local: LocalInputSource = null
	if config.humans > 0 and not autoplay:
		local = LocalInputSource.new(LOCAL_SEAT, 0.0, ViewSettings.local())
		played = LOCAL_SEAT
		served.append(null)
	else:
		served.append(BotInputSource.new(LOCAL_SEAT, profile, config))
	served.append_array(BotInputSource.fill(config, profile, LOCAL_SEAT + 1))
	var conditions := net_sim if net_sim != null else NetConditions.new()
	var loopback := LoopbackMatch.new(config, net_rules, conditions, played, local, served)
	var names := _seat_names(config.seats)
	_begin(loopback, local, LOCAL_SEAT, names, observer, eye_seat, observer_cut, greybox)


## Starts [param played] — a match on a server, RemoteMatch (SH12) — from its first
## tick: the local player on its client's seat through [param local]'s keys, mouse
## and pad, every seat named by [param names]. Seen through that seat's eyes; nothing
## of it pauses.
func start_online(played: PlayedMatch, local: LocalInputSource, names: PackedStringArray) -> void:
	var seat := played.client.seat
	_online = true
	_begin(played, local, seat, names, false, seat, INF, false)
	_end.offer_room()


## Stands a capture's eyes on [param at] — feet x, y, z in ship space, yaw and
## pitch in degrees — whatever the seat they look through does; empty leaves them
## the seat's own. The seat's arms are not drawn there.
func stage_eyes(at: PackedFloat64Array) -> void:
	_staged = at
	if at.size() == 4:
		_staged.append(SPECTATE_PITCH_DEG)
	_arms.visible = at.is_empty()


## Has the observer camera watch from her [param side] (--observer-side): a tool, as
## it is.
func watch_from(side: ObserverCamera.Beam) -> void:
	_observer_camera.side = side
	_observer_camera.reset(_view.seat_world_position(_eye_seat), _deck_bounds(_config.ship))


## Draws the ship's cells over the observer's view, named, and frames the whole ship
## (--observer-cells): a tool, as the observer camera is.
func show_cells() -> void:
	if _cells == null:
		_cells = CellOverlay.new()
		_view.get_node("Ship").add_child(_cells)
	_cells.build(_config.ship.structure)
	_observer_camera.pitch_deg = CELLS_PITCH_DEG
	_observer_camera.distance = CELLS_DISTANCE
	_observer_camera.whole_ship = true
	_observer_camera.reset(Vector3.ZERO, _deck_bounds(_config.ship))


## Lets the mouse go, or takes it back, without pausing: the online match's Esc. While
## it is let go the match takes nothing of the keys, the pad or the mouse.
func free_mouse(freed: bool) -> void:
	_mouse_freed = freed
	_hold()


## What both kinds of match start with: [param played] stepped from its first tick,
## [param local] (null for a bot) on [param local_seat], seen through
## [param eye_seat]'s eyes or the observer camera, as start() says.
func _begin(
	played: PlayedMatch,
	local: LocalInputSource,
	local_seat: int,
	names: PackedStringArray,
	observer: bool,
	eye_seat: int,
	observer_cut: float,
	greybox: bool
) -> void:
	var config := played.client.config
	_config = config
	_observer = observer
	_eye_seat = eye_seat
	_local = local
	_local_seat = local_seat
	_mouse_freed = false
	var settings := ViewSettings.local()
	var net_rules := NetRules.load_default()
	_driver.start(played)
	if _local != null:
		# The look starts where the match's first snapshot faces the seat.
		_local.yaw = _driver.client.view()["seats"][_local_seat]["facing"]
	# The client's prediction: what the data, the ship and its sinking are.
	var sim := _driver.client.sim
	_stats = MatchStats.new(config.seats, config.countdown_ticks)
	_order = SpectateOrder.new(_eye_seat, _stats)
	_names = names
	_greybox.cut_above = observer_cut if observer else INF
	_ship_art.cut_above = _greybox.cut_above
	_greybox.visible = greybox
	_ship_art.visible = not greybox
	_view.setup(_driver, sim, _local_seat, net_rules.correction_time)
	_view.look_out_of(-1 if observer else _eye_seat)
	_hud.setup(sim)
	_marks.setup(_driver, _view, sim)
	_dust.setup(_driver, _view)
	_fx.setup(_driver, _view, sim, _sea_and_sky.sun())
	_kick = ViewKick.new(settings.view_kick)
	_free = FreeCamera.new(settings)
	_free.set_bounds(_deck_bounds(config.ship))
	_eyes.setup(settings)
	_arms.setup(config.rules)
	_first_person_hud.setup(sim, _names, not observer, _prompts)
	_sea_and_sky.setup(sim.schedule.end_tick(), config.ship)
	_underwater.setup(_sea_and_sky)
	_view.flood_with(_sea_and_sky.water())
	_show_graphics(settings.graphics())
	_observer_camera.whole_ship = observer and is_finite(observer_cut)
	_audio.setup(_driver, sim, _view, _local_seat, _underwater)
	_observer_camera.reset(_view.seat_world_position(_eye_seat), _deck_bounds(config.ship))
	if observer:
		_observer_camera.make_current()
	else:
		_eyes.make_current()
	_end.hide()
	print("match seed %d" % config.match_seed)


## Takes up the settings screen's field of view, deck roll, view kick and graphics
## mid-match; the look's sensitivity and invert-Y are read from the same settings as
## they turn.
func apply_view(settings: ViewSettings) -> void:
	_eyes.setup(settings)
	_kick.set_strength(settings.view_kick)
	_show_graphics(settings.graphics())


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


## The sinking is felt before it is seen (D12): a full shake as the iceberg strikes,
## a light one as a lurch is telegraphed, a full one as it swings, a lighter one as a
## deck gives way — read from every stepped tick's events, so a hitch never eats one.
func _shake_for_the_sinking(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SHIP_LURCHING:
				_kick.shake(LURCH_WARNING_SHAKE)
			SimEvent.Kind.SHIP_LURCHED, SimEvent.Kind.HOLED:
				_kick.shake()
			SimEvent.Kind.PLATFORM_COLLAPSED:
				_kick.shake(COLLAPSE_SHAKE)


## Whether the local player's mouse and stick turn their look now: in play, and
## neither paused, at the results nor with the mouse let go.
func _looking() -> bool:
	return _local != null and not _paused and not _end.visible and not _mouse_freed


## Whether the free camera turns and flies now: flown, and neither paused, at the
## results nor with the mouse let go.
func _flying() -> bool:
	return _free.active and not _paused and not _end.visible and not _mouse_freed


## Whether the free camera may be flown in [param snapshot]: the eye seat out while the
## match goes on, the eyes being a seat's (not the observer's).
func _can_fly(snapshot: Dictionary) -> bool:
	var mine: Dictionary = snapshot["seats"][_eye_seat]
	return not _observer and mine["out"] and snapshot["phase"] != MatchState.Phase.ENDED


## Into the free camera, behind and over the seat whose eyes the view was in and
## looking where they did; or back into those eyes.
func _toggle_free() -> void:
	_free.toggle(true)
	if _free.active:
		var viewed := _order.target(_driver.current)
		var head := _view.seat_world_position(viewed) + Vector3.UP * FirstPersonCamera.EYE_HEIGHT
		_free.start(head, -_eyes.global_basis.z)


## The view from the free camera: every seat drawn, nobody's arms, and the HUD as the
## observer's, of [param viewed] — the seat last watched.
func _fly(snapshot: Dictionary, viewed: int, delta: float) -> void:
	if _flying():
		_free.fly_by_input(delta)
	_view.look_out_of(-1)
	_arms.visible = false
	_eyes.global_transform = _free.transform()
	_underwater.show_eye(_eyes.global_position, _view.above_water(_eyes.global_position))
	_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)


## The local seat of a match on a server stands still while a menu over the match, or a
## browser's "Click to play", has the keys, the pad and the mouse.
func _hold() -> void:
	if _local != null:
		_local.held = _mouse_freed or (_online and _pointer.waiting())


## Draws the sea, the sky and the ship as [param quality] says.
func _show_graphics(quality: GraphicsQuality) -> void:
	_sea_and_sky.show_graphics(quality)
	_underwater.show_graphics(quality)
	_ship_art.show_graphics(quality)


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
	var seat_name := _hud.fit_name(_names[viewed])
	var whose := Hud.whose_view(seat_name, viewed == _local_seat, _observer)
	return Hud.spectating_text(
		EndOverlay.ordinal(mine["place"]),
		seats.size(),
		whose,
		_prompts.word(&"spectate_previous"),
		_prompts.word(&"spectate_next"),
		"" if _observer else _prompts.word(&"spectate_free"),
		_free.active
	)
