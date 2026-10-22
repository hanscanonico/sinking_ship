class_name MatchScene
extends Node3D
## One match of the config Game hands in — the local player on the first seat (a
## bot when autoplaying), bots of the config's tier on the rest — or one played on a
## server, the local player on the seat it gives (SH12) — seen through the local
## seat's eyes and, once it is out, through a survivor's (D14), with the results at
## its end. The observer camera stands in for the eyes only as a tool: for --observer
## and captures, and it alone may cut the ship away to look inside. Rematch and menu
## go back to whoever started it: Game, which builds every config through
## MatchChoices.config (D13), or OnlinePlay.

signal rematch_requested
signal menu_requested
## A browser let go of the mouse mid-match at the player's Esc, which this never hears.
signal pointer_lost
## The replay watched was left: Esc, or the controls' Back (R4).
signal replay_closed
## The results asked to watch the match again (R6): [param file] is its replay.
signal replay_requested(file: ReplayFile)

## The choices a local match was built from (Game), for its replay; null online.
var choices: MatchChoices
## A local match's replay, recorded once it ended or as it was left (save_replay): what
## the results offer to watch again; null until then, and for an online match.
var last_replay: ReplayFile
## Her ship dressed for the next match or replay started here (ShipDressing), taken as it
## starts; with none she is dressed as it starts, a frame of seconds.
var dressing: ShipDressing

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
## The stats the results showed, kept past a replay of the match (show_results_again).
var _last_stats: MatchStats
var _order: SpectateOrder
var _names := PackedStringArray()
## The local player's seat when a person plays it; null when a bot does.
var _local: LocalInputSource
## The face the local seat's look was last in (Faces.Up): its look turns as it changes.
var _local_up: int = Faces.Up.DECK
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
## The local match's host and client in one process (start); null online.
var _loopback: LoopbackMatch
## The mouse let go mid-match without pausing, a menu over the match having it, the keys
## and the pad: an online match never pauses.
var _mouse_freed := false
var _marks := BrawlMarks.new()
var _dust := LandingDust.new()
var _fx := SinkingFx.new()
var _iceberg := Iceberg.new()
var _prompts := InputPrompts.new()
var _pointer := PointerCapture.new()
var _kick: ViewKick
## The ship's cells over the observer's view, once show_cells() asks for them: one per
## piece she ends in once she breaks (SH33), each drawn on its piece.
var _cells: Array[CellOverlay] = []
## The free camera the local seat may fly once it is out, in place of a seat's eyes.
var _free := FreeCamera.new()
## The faint light round the eye in a room whose lamps have failed.
var _eye_fill := EyeFill.new()
## The water running off the lens once the eye comes up out of it.
var _lens_drops := LensDrops.new()
## The replay's controls, made the first time a replay is watched (start_replay).
var _replay_hud: ReplayHud
## The replay's orbit camera (R5), made as a replay starts; null until one is.
var _orbit: OrbitCamera
## Whose eyes the replay is seen through, cycled round every seat (SpectateOrder.every).
var _replay_seat := LOCAL_SEAT
## Whether the match stands aside for the next one's held countdown (stand_aside).
var _aside := false

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
	_end.replay_requested.connect(func() -> void: replay_requested.emit(last_replay))
	_driver.stepped.connect(func(events: Array[SimEvent]) -> void: _stats.add(events))
	_driver.stepped.connect(_shake_for_the_sinking)
	add_child(_marks)
	add_child(_dust)
	add_child(_fx)
	add_child(_iceberg)
	add_child(_eye_fill)
	add_child(_lens_drops)
	add_child(FxWarmUp.new(_fx.emitters()))
	add_child(_prompts)
	add_child(_pointer)
	_pointer.lost.connect(pointer_lost.emit)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A match left early — the pause menu's, or the game's quit — is kept as it ends.
	save_replay()


# Runs after MatchView (the scene's process_priority), so the eyes sit on the bodies
# as drawn this frame.
func _process(delta: float) -> void:
	if not _driver.started() or _aside:
		return
	var snapshot := _driver.current
	var viewed := _replay_seat if _driver.replaying() else _order.target(snapshot)
	_hud.show_snapshot(snapshot)
	_sea_and_sky.show_sinking(snapshot["tick"], _view.ship_to_world())
	_sea_and_sky.show_waders(_view.waders_drawn())
	var drawn := lerpf(_driver.previous["tick"], snapshot["tick"], _driver.alpha)
	_iceberg.show_at(drawn, _underwater.is_under())
	if not _cells.is_empty():
		var pose := _driver.sim().schedule.pose_at(snapshot["tick"])
		var leaves := ShipPieces.leaves_of(_driver.sim().schedule)
		for at in _cells.size():
			var piece := leaves[at] if not leaves.is_empty() else 0
			_cells[at].show_water(pose.of_piece(piece), _view.piece_to_world(at))
	_hud.show_spectating(_spectating(snapshot, viewed))
	_hud.show_controls(_prompts if _local != null else null)
	if _driver.replaying():
		_show_replay(snapshot, viewed)
	else:
		_end.show_results(
			_stats,
			_local_seat,
			_names,
			_config.match_seed,
			_config.goal == MatchRules.Goal.SURVIVAL
		)
	if _end.visible:
		_end.show_prompts(_prompts)
		save_replay()
	_free.keep(_can_fly(snapshot))
	_pointer.want(_looking() or _flying())
	_hold()
	var local_up := _up_of(snapshot, _local_seat)
	if _local != null and local_up != _local_up:
		_local.turn_face(_local_up, local_up, _view.seat_to_world(_local_seat).basis)
		_local_up = local_up
	if _looking() and not _free.active:
		_local.look_by_stick(delta)
	_audio.hear_through(-1 if _observer or _free.active or _orbiting() else viewed)
	_first_person_hud.flying = _free.active or _orbiting()
	if _observer:
		_observer_camera.follow(_view.seat_world_position(viewed), delta)
		_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)
		return
	if _free.active:
		_fly(snapshot, viewed, delta)
		return
	if _orbiting():
		_orbit_view(snapshot, viewed, delta)
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
	var world := _view.seat_to_world(viewed)
	var up := _up_of(snapshot, viewed)
	# Eyes stood in ship space (--capture-from) stand on her decks, still whatever the
	# seat they look through goes through.
	var height := _view.seat_height(viewed)
	if not _staged.is_empty():
		world = _view.ship_to_world()
		kick = Vector3.ZERO
		up = Faces.Up.DECK
		height = _view.height_at(feet)
	_eyes.ease_eye(viewed, height / _config.rules.body_height, delta)
	_eyes.look_from(world, feet, yaw, pitch, kick, up)
	_arms.visible = _staged.is_empty()
	if _staged.is_empty():
		_arms.show_seat(
			viewed, _driver.previous["seats"][viewed], snapshot["seats"][viewed], _driver.alpha
		)
	var eye := _eyes.global_position
	_underwater.show_eye(eye, _view.above_water(eye), _view.indoors(eye))
	_eye_fill.show_eye(eye, _view.lit_at(eye), _underwater.is_under())
	_lens_drops.show_eye(_underwater.is_under())
	_first_person_hud.show_view(snapshot, viewed, yaw, _eyes, _view)


func _unhandled_input(event: InputEvent) -> void:
	if not _driver.started() or _mouse_freed or _aside:
		return
	if event is InputEventMouseMotion:
		if _orbiting():
			_orbit.drag(event as InputEventMouseMotion)
		elif _flying():
			_free.look_by_mouse((event as InputEventMouseMotion).screen_relative)
		elif _looking():
			_local.look_by_mouse((event as InputEventMouseMotion).screen_relative)
		return
	if _end.visible and event.is_action_pressed("restart"):
		rematch_requested.emit()
	elif _end.visible and event.is_action_pressed("pause"):
		menu_requested.emit()
	elif _driver.replaying():
		if not _replay_input(event):
			return
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
## [param jump_to], a tool's, starts the match at that tick instead, every seat on what
## is dry then (MatchJump); -1 starts it at its first. With [param split], the match's
## pieces are timed into it (FrameMeter, make fps SPLIT=1).
func start(
	config: MatchConfig,
	autoplay: bool,
	observer: bool = false,
	eye_seat: int = LOCAL_SEAT,
	observer_cut: float = INF,
	greybox: bool = false,
	net_sim: NetConditions = null,
	jump_to: int = -1,
	split: FrameSplit = null
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
	var from := MatchJump.snapshot(config, jump_to) if jump_to >= 0 else {}
	var loopback: LoopbackMatch
	if split == null:
		loopback = LoopbackMatch.new(config, net_rules, conditions, played, local, served, from)
	else:
		served = FrameMeter.time_sources(served, split)
		loopback = FrameMeter.Loopback.new(
			config, net_rules, conditions, played, local, served, from, split
		)
	var names := _seat_names(config.seats)
	_loopback = loopback
	last_replay = null
	_begin(loopback, local, LOCAL_SEAT, names, observer, eye_seat, observer_cut, greybox)


## Starts [param played] — a match on a server, RemoteMatch (SH12) — from its first
## tick: the local player on its client's seat through [param local]'s keys, mouse
## and pad, every seat named by [param names]. Seen through that seat's eyes; nothing
## of it pauses.
func start_online(played: PlayedMatch, local: LocalInputSource, names: PackedStringArray) -> void:
	var seat := played.client.seat
	_online = true
	_loopback = null
	last_replay = null
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


## Holds the lens wet as it is [param seconds] after surfacing (--capture-wet): a tool,
## a still shot having no surfacing to wet it.
func wet_lens(seconds: float) -> void:
	_lens_drops.hold_wet(seconds)


## Has the observer camera watch from her [param side] (--observer-side): a tool, as
## it is.
func watch_from(side: ObserverCamera.Beam) -> void:
	_observer_camera.side = side
	_observer_camera.reset(_view.seat_world_position(_eye_seat), _deck_bounds(_config.ship))


## Draws the ship's cells over the observer's view, named, and frames the whole ship
## (--observer-cells): a tool, as the observer camera is.
func show_cells() -> void:
	if _cells.is_empty():
		var schedule := _driver.sim().schedule
		var leaves := ShipPieces.leaves_of(schedule)
		for at in maxi(leaves.size(), 1):
			var overlay := CellOverlay.new()
			_view.piece_node(at).add_child(overlay)
			var drawn := _config.ship.structure if leaves.is_empty() else null
			overlay.build(drawn if drawn != null else schedule.structure_of(leaves[at]))
			_cells.append(overlay)
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
	_driver.start(played)
	_setup_view(
		played.client.config, local, local_seat, names, observer, eye_seat, observer_cut, greybox
	)


## What a match and a replay share once the driver runs it: [param config]'s ship,
## sinking and seats drawn, [param local] (null for a bot, or a replay) on
## [param local_seat], seen through [param eye_seat]'s eyes or the observer camera, as
## start() says.
func _setup_view(
	config: MatchConfig,
	local: LocalInputSource,
	local_seat: int,
	names: PackedStringArray,
	observer: bool,
	eye_seat: int,
	observer_cut: float,
	greybox: bool
) -> void:
	_config = config
	_observer = observer
	_eye_seat = eye_seat
	_local = local
	_local_seat = local_seat
	_mouse_freed = false
	var settings := ViewSettings.local()
	var net_rules := NetRules.load_default()
	if _local != null:
		# The look starts where the match's first snapshot faces the seat.
		_local.yaw = _driver.latest()["seats"][_local_seat]["facing"]
		_local_up = _up_of(_driver.latest(), _local_seat)
	# The client's prediction, or the replay's sim: what the data, the ship and its
	# sinking are.
	var sim := _driver.sim()
	_stats = MatchStats.new(config.seats, config.countdown_ticks)
	_order = SpectateOrder.new(_eye_seat, _stats)
	_names = names
	_greybox.cut_above = cut_of(observer, observer_cut)
	_ship_art.cut_above = _greybox.cut_above
	_greybox.visible = greybox
	_ship_art.visible = not _greybox.visible
	if dressing != null and (greybox or not dressing.fits(config, _greybox.cut_above)):
		dressing.drop()
		dressing = null
	_view.setup(_driver, sim, _local_seat, net_rules.correction_time, dressing)
	dressing = null
	_ship_art = _view.art()
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
	_sea_and_sky.setup(sim.schedule.end_tick(), config.ship, config.scenario.sea_depth)
	_underwater.setup(_sea_and_sky)
	_iceberg.setup(sim.schedule, config.ship, config.match_seed, _sea_and_sky)
	_view.flood_with(_sea_and_sky.water())
	_show_graphics(settings.graphics())
	_observer_camera.whole_ship = observer and is_finite(observer_cut)
	_audio.setup(_driver, sim, _view, _local_seat, _underwater)
	_observer_camera.reset(_view.seat_world_position(_eye_seat), _deck_bounds(config.ship))
	if observer:
		_observer_camera.make_current()
	else:
		_eyes.make_current()
	_aside = false
	visible = true
	for layer: CanvasLayer in _overlays():
		layer.show()
	_end.hide()
	if _replay_hud != null:
		_replay_hud.visible = _driver.replaying()
	print("match seed %d" % config.match_seed)


## Records the local match as its replay (last_replay) — the host's log, which has every
## seat's frames — and saves it, once: as the results show, or as the match is left
## early, its log ending where play ended (R3). An online match is never saved: its host
## is elsewhere. A match started mid-way (a tool's jump) is recorded but not saved, as
## no replay could rebuild its start (ReplayFile.playable).
func save_replay() -> void:
	if last_replay != null or _loopback == null or choices == null:
		return
	var runner := _loopback.host.runner
	# A match left before a tick was stepped has nothing to watch again.
	if runner.input_log.last_tick() < runner.input_log.first_tick:
		return
	var recorder := ReplayRecorder.new()
	last_replay = recorder.record(choices, runner)
	_last_stats = _stats
	var playable := last_replay.playable()
	_end.offer_replay(playable)
	if playable:
		recorder.save(last_replay)


## Watches [param file]'s match again (R4, #212): its sim run from its log
## (ReplayTimeline) and drawn exactly as a live match is, seen through the recorded
## human seat's eyes, with the replay's controls over it (ReplayHud) and nothing of a
## match's input, pause or results. Esc, or the controls' Back, emits replay_closed.
func start_replay(file: ReplayFile, config: MatchConfig) -> void:
	var rules := ReplayRules.load_default()
	var timeline := ReplayTimeline.new(file, rules, config)
	_online = false
	_loopback = null
	choices = file.choices
	last_replay = file
	_driver.start_replay(timeline, rules)
	if not _driver.sought.is_connected(_on_sought):
		_driver.sought.connect(_on_sought)
	if _replay_hud == null:
		_replay_hud = ReplayHud.new()
		_replay_hud.name = "ReplayHud"
		add_child(_replay_hud)
		_replay_hud.pause_toggled.connect(replay_pause)
		_replay_hud.step_requested.connect(replay_step)
		_replay_hud.speed_requested.connect(replay_speed)
		_replay_hud.seek_requested.connect(replay_seek)
		_replay_hud.close_requested.connect(replay_closed.emit)
	_replay_hud.setup(timeline.first_tick(), timeline.last_tick())
	_setup_view(config, null, LOCAL_SEAT, _seat_names(config.seats), false, LOCAL_SEAT, INF, false)
	# Nobody plays: no crosshair, readouts or wedges over the eyes, as from the observer.
	_first_person_hud.setup(timeline.sim(), _names, false, _prompts)
	_replay_seat = LOCAL_SEAT
	_orbit = OrbitCamera.new(ViewSettings.local())
	_orbit.set_ship(config.ship)
	_orbit.open()


## Whether a replay is being watched rather than a match played.
func replaying() -> bool:
	return _driver != null and _driver.replaying()


## The match it last started, played or watched, and its sinking — kept behind the
## results for a replay of it to share (Game, D7); null before any.
func played_config() -> MatchConfig:
	return _config


## Pauses the replay, or plays it on.
func replay_pause() -> void:
	var clock := _driver.clock()
	if clock != null:
		clock.paused = not clock.paused


## The replay one tick on ([param direction] 1) or back (-1), paused first.
func replay_step(direction: int) -> void:
	var clock := _driver.clock()
	if clock == null:
		return
	clock.paused = true
	_driver.step_once(direction)


## Up ([param direction] 1) or down (-1) the replay's speed ladder.
func replay_speed(direction: int) -> void:
	var clock := _driver.clock()
	if clock == null:
		return
	if direction > 0:
		clock.speed_up()
	else:
		clock.speed_down()


## The replay to [param tick].
func replay_seek(tick: int) -> void:
	_driver.seek(tick)


## Back from a replay opened from the results (R6): the results again, over the replay
## standing still, with Rematch, Watch replay and Menu as before.
func show_results_again() -> void:
	if _last_stats == null or not _driver.replaying():
		return
	_driver.clock().paused = true
	_replay_hud.hide()
	_end.show_results(
		_last_stats,
		_local_seat,
		_names,
		_config.match_seed,
		_config.goal == MatchRules.Goal.SURVIVAL
	)


## Stands the ended match aside while Game holds the next one's countdown for its
## sinking (R20) — a rematch's, or a replay's watched from the results: nothing of it
## drawn, its world, HUDs and results, nor its keys heard, so the held countdown shows
## over the menu's backdrop as a held Play does. The match and its last stats are kept
## for the way back from the replay (show_results_again); start or start_replay brings
## it back.
func stand_aside() -> void:
	_aside = true
	visible = false
	for layer: CanvasLayer in _overlays():
		layer.hide()


## Everything the match draws over the world.
func _overlays() -> Array[CanvasLayer]:
	var layers: Array[CanvasLayer] = [
		_hud, _first_person_hud, _underwater, _lens_drops, _pointer, _end
	]
	if _replay_hud != null:
		layers.append(_replay_hud)
	return layers


## The replay's keys: whether [param event] was one of them, and what it asked done.
func _replay_input(event: InputEvent) -> bool:
	if event.is_action_pressed("replay_pause"):
		replay_pause()
	elif event.is_action_pressed("replay_step_back"):
		replay_step(-1)
	elif event.is_action_pressed("replay_step_forward"):
		replay_step(1)
	elif event.is_action_pressed("replay_speed_down"):
		replay_speed(-1)
	elif event.is_action_pressed("replay_speed_up"):
		replay_speed(1)
	elif event.is_action_pressed("replay_seek_start"):
		replay_seek(_driver.timeline().first_tick())
	elif event.is_action_pressed("replay_seek_end"):
		replay_seek(_driver.timeline().last_tick())
	elif event.is_action_pressed("spectate_next"):
		_replay_seat = SpectateOrder.every(_replay_seat, 1, _config.seats)
	elif event.is_action_pressed("spectate_previous"):
		_replay_seat = SpectateOrder.every(_replay_seat, -1, _config.seats)
	elif event.is_action_pressed("replay_camera_toggle"):
		_orbit.active = not _orbit.active
	elif event.is_action_pressed("replay_orbit_lock"):
		_orbit.locked = not _orbit.locked
	elif event is InputEventMouseButton and event.is_pressed() and _orbiting():
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			_orbit.zoom(1.0)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit.zoom(-1.0)
		else:
			return false
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		replay_closed.emit()
	else:
		return false
	return true


## The replay's controls over the view, as the replay stands at [param snapshot], seen
## through [param viewed]'s eyes.
func _show_replay(snapshot: Dictionary, viewed: int) -> void:
	var clock := _driver.clock()
	_replay_hud.show_state(
		snapshot["tick"],
		clock.paused,
		clock.speed(),
		Hud.whose_view(_hud.fit_name(_names[viewed]), viewed == _local_seat, false),
		_camera_name(),
		_prompts
	)


## The replay was sought: what presentation built from the ticks before is built again
## from the snapshot (D5) — the standings, the sinking's effects and the cues.
func _on_sought(_tick: int) -> void:
	_stats = MatchStats.new(_config.seats, _config.countdown_ticks)
	_order = SpectateOrder.new(_eye_seat, _stats)
	_fx.clear()
	_audio.rewind()


## Whether the replay is seen from the orbit camera now.
func _orbiting() -> bool:
	return _driver.replaying() and _orbit != null and _orbit.active


## The view from the orbit camera (R5): every seat drawn, nobody's arms, the pivot on
## [param viewed]'s head while locked, and the HUD as from the observer.
func _orbit_view(snapshot: Dictionary, viewed: int, delta: float) -> void:
	var head := _view.seat_world_position(viewed) + Vector3.UP * _eyes.eye_height()
	_orbit.advance(delta, head, _view.ship_to_world())
	_view.look_out_of(-1)
	_arms.visible = false
	_eyes.global_transform = _orbit.transform()
	var eye := _eyes.global_position
	_underwater.show_eye(eye, _view.above_water(eye), _view.indoors(eye))
	_eye_fill.show_eye(eye, _view.lit_at(eye), _underwater.is_under())
	_lens_drops.show_eye(_underwater.is_under())
	_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)


## The camera the replay's plate names.
func _camera_name() -> String:
	if not _orbiting():
		return "First person"
	return "Orbit · on the seat" if _orbit.locked else "Orbit · free"


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
## is freed while paused, and the local seat held, as under any menu over the match.
func set_paused(paused: bool) -> void:
	_paused = paused
	_driver.set_process(not paused)
	_hold()


## The sinking is felt before it is seen (D12): a full shake as the iceberg strikes,
## a light one as a lurch is telegraphed, a full one as it swings, a lighter one as a
## deck gives way, a funnel comes down or her hull parts (SH33); a light one as something
## bursts, the hull creaks or a hinge starts in it — read from every stepped tick's
## events, so a hitch never eats one.
func _shake_for_the_sinking(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SHIP_LURCHING, SimEvent.Kind.OPENING_GAVE_WAY:
				_kick.shake(LURCH_WARNING_SHAKE)
			SimEvent.Kind.HULL_STRESSED, SimEvent.Kind.FUNNEL_STRAINING, SimEvent.Kind.HULL_HINGING:
				_kick.shake(LURCH_WARNING_SHAKE)
			SimEvent.Kind.SHIP_LURCHED, SimEvent.Kind.HOLED:
				_kick.shake()
			SimEvent.Kind.HULL_PARTED:
				_kick.shake(COLLAPSE_SHAKE)
			SimEvent.Kind.PLATFORM_COLLAPSED, SimEvent.Kind.KNOCKED_DOWN:
				_kick.shake(COLLAPSE_SHAKE)


## Whether the local player's mouse and stick turn their look now: in play, and
## neither paused, at the results nor with the mouse let go.
func _looking() -> bool:
	return _local != null and not _paused and not _end.visible and not _mouse_freed


## Whether the free camera turns and flies now: flown, and neither paused, at the
## results nor with the mouse let go.
func _flying() -> bool:
	return _free.active and not _paused and not _end.visible and not _mouse_freed


## The frame [param seat] of [param snapshot] stands in (MatchState.up_of): its piece's;
## her decks' for no seat.
static func _up_of(snapshot: Dictionary, seat: int) -> int:
	if seat < 0 or seat >= snapshot["seats"].size():
		return snapshot["up"][0]
	return MatchState.up_of(snapshot, snapshot["seats"][seat])


## Whether the free camera may be flown in [param snapshot]: the eye seat out while the
## match goes on, the eyes being a seat's (not the observer's).
func _can_fly(snapshot: Dictionary) -> bool:
	var mine: Dictionary = snapshot["seats"][_eye_seat]
	return (
		not _observer
		and not _driver.replaying()
		and mine["out"]
		and snapshot["phase"] != MatchState.Phase.ENDED
	)


## Into the free camera, behind and over the seat whose eyes the view was in and
## looking where they did; or back into those eyes.
func _toggle_free() -> void:
	_free.toggle(true)
	if _free.active:
		var viewed := _order.target(_driver.current)
		var head := _view.seat_world_position(viewed) + Vector3.UP * _eyes.eye_height()
		_free.start(head, -_eyes.global_basis.z)


## The view from the free camera: every seat drawn, nobody's arms, and the HUD as the
## observer's, of [param viewed] — the seat last watched.
func _fly(snapshot: Dictionary, viewed: int, delta: float) -> void:
	if _flying():
		_free.fly_by_input(delta)
	_view.look_out_of(-1)
	_arms.visible = false
	_eyes.global_transform = _free.transform()
	var eye := _eyes.global_position
	_underwater.show_eye(eye, _view.above_water(eye), _view.indoors(eye))
	_eye_fill.show_eye(eye, _view.lit_at(eye), _underwater.is_under())
	_lens_drops.show_eye(_underwater.is_under())
	_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)


## The local seat stands still while a menu over the match — the pause menu, or the
## online match's Esc — or a browser's "Click to play" on a server has the keys, the
## pad and the mouse.
func _hold() -> void:
	if _local != null:
		_local.held = _paused or _mouse_freed or (_online and _pointer.waiting())


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


## How high up the ship is cut away (ShipArt.cut_above): at [param observer_cut] for
## the observer camera when [param observer] says it looks, nowhere through eyes.
static func cut_of(observer: bool, observer_cut: float) -> float:
	return observer_cut if observer else INF


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
