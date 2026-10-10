class_name Game
extends Node
## What `make run` boots: the main menu, then matches. Every match the UI starts
## — Play, and Rematch with the same ship, seats and tier on a new seed — is built by
## MatchConfig.from_menu (D13). Esc / Start pauses by stopping the match's
## SimDriver; the pause is never sim state. User arguments are MatchArgs':
## --seed, --seats and --ship fill the menu in, --autoplay presses Play for a bot on the
## local seat, and --capture saves a frame — of the match, or of the menu when
## nothing is autoplaying — and quits. A match is seen through the local seat's
## eyes (D14); the observer camera is a tool that only --observer and captures
## reach, and --capture-eye takes a capture through a seat's eyes instead;
## --observer-cut cuts the observer's view of the ship away to show the inside;
## --net-sim puts fake lag on the wire between the local host and the client.
## --server serves rooms instead (ServerLoop), and --connect with --autoplay plays in a
## server's room with nobody at the keys (OnlineAutoplay); neither opens a menu (SH12).
## Play online opens the Online screen (OnlineMenu) over the menu's backdrop, whose link
## a person plays there (OnlinePlay); --connect without --autoplay — or a browser page's
## address naming a room — opens it on that link, and plays it once the name is known.
## --capture-screen stages the settings — on their Graphics page for graphics —, the
## pause menu, the results, the Online screen, a room — its players made up, no server
## asked — or the online pause over the match, the settings opened from it or not, for
## a capture, or catches the countdown held for a slow bake (hold); --capture-sway holds
## the menu backdrop's drift.
## The saved volumes, window and graphics apply as it boots — --quality and
## --render-scale stand in for the saved graphics for one run; the settings screen opens
## from the main menu and the pause menu, and its changes reach the window, the menu's
## backdrop and the match as they are made.
## A match's sinking is made before it starts, never during play (R20): the next
## blank-seed match's is baked a slice a frame while the menu or the results show (its
## seed drawn ahead), and one not yet made when Play is pressed holds the countdown —
## its first number, with a bar, over the backdrop — until it is (BakeHold);
## --bake-budget sets the held bake's slice of each frame, to measure or show the hold.

const MATCH_DATA := "res://data/match/default.tres"
const MATCH_SCENE := preload("res://scenes/match/match.tscn")
## Frames drawn after a capture's moment, so the view has settled on it.
const CAPTURE_SETTLE_FRAMES := 3
## Frames between silencing everything and quitting, for the mixer to let go.
const QUIT_SETTLE_FRAMES := 4
## The slice of each frame a sinking's bakes may take, in milliseconds: on the menu,
## where it must not show, and holding the countdown, where little else is drawn.
const MENU_BAKE_MS := 4.0
const HOLD_BAKE_MS := 12.0
## A capture that jumps to a moment of the sinking starts this many seconds before it,
## so what the sinking shows — spray at the waterlines, wreckage out on the sea, wet
## decks — has settled into it rather than starting.
const JUMP_LEAD := 15.0
## A capture of a held countdown is taken once its bar is this far on.
const HOLD_CAPTURED_AT := 0.5

var _args: MatchArgs
var _match_rules: MatchRules
## Where a blank seed is drawn from: outside the sim, once per match.
var _seeds := RandomNumberGenerator.new()
var _match: MatchScene
## The last match's ship, seats, tier and pace, for a rematch.
var _ship: StringName
var _seats: int
var _tier: StringName
var _fast: bool
var _capturing := false
## The online play under way, from the Online screen; null when none is.
var _online: OnlinePlay
## The view settings, held so that what --quality and --render-scale choose holds all
## run, never saved.
var _view: ViewSettings
## The tick a capture is due at, past a --phys moment; -1 for --capture-at's.
var _capture_tick := -1
## The next blank-seed match, its seed drawn ahead so its sinking can be made
## on the menu; the match held for its sinking, and how it will start.
var _upcoming: NextMatch
var _holding: MatchConfig
var _baker := SinkingBaker.new()
var _hold := BakeHold.new()

@onready var _menu: MainMenu = $MainMenu
@onready var _online_menu: OnlineMenu = $OnlineMenu
@onready var _pause: PauseMenu = $PauseMenu
@onready var _settings: SettingsMenu = $SettingsMenu
@onready var _music: MusicPlayer = $Music


func _ready() -> void:
	_args = MatchArgs.parse(OS.get_cmdline_user_args())
	if _args.server:
		add_child(ServerLoop.new(_args))
		return
	if not _args.connect_url.is_empty() and _args.autoplay:
		add_child(OnlineAutoplay.new(_args))
		return
	_seeds.randomize()
	AudioSettings.local().apply()
	_view = ViewSettings.local()
	# A capture keeps the window it was launched with, whatever the player saved.
	if _args.capture_path.is_empty():
		_view.apply_window()
	_view.run_quality = _args.quality
	_view.run_render_scale = _args.render_scale
	_view.apply_graphics(get_viewport())
	_match_rules = load(MATCH_DATA)
	var problems := _match_rules.problems()
	problems.append_array(_args.problems())
	if not problems.is_empty():
		push_error("\n".join(problems))
		get_tree().quit(1)
		return
	_upcoming = NextMatch.new(_match_rules, _args, _seeds)
	add_child(_baker)
	add_child(_hold)
	_baker.baked.connect(_on_baked)
	_menu.play_requested.connect(_play)
	_menu.ship_picked.connect(_on_ship_picked)
	_menu.online_requested.connect(_open_online)
	_menu.settings_requested.connect(_settings.open)
	_menu.quit_requested.connect(_quit)
	_pause.resume_requested.connect(_set_paused.bind(false))
	_pause.menu_requested.connect(_to_menu)
	_pause.settings_requested.connect(_settings.open)
	_pause.quit_requested.connect(_quit)
	_settings.view_changed.connect(_on_view_changed)
	_online_menu.play_requested.connect(_play_online)
	_online_menu.back_requested.connect(_leave_online)
	var link := OnlineLink.for_launch(_args)
	_online_menu.page_server = link.server_url
	var seats := _args.seats if _args.seats > 0 else _match_rules.seats
	var seed_text := str(_args.seed_value) if _args.seed_value >= 0 else ""
	_menu.setup(_match_rules, _args.ship(), seats, _match_rules.bot_tier, seed_text, _args.fast)
	if not is_nan(_args.capture_sway):
		_menu.hold_drift(_args.capture_sway)
	if _args.autoplay:
		_play.call_deferred(
			_menu.picked_ship(), seats, _match_rules.bot_tier, seed_text, _args.fast
		)
		return
	_music.play_menu()
	if link.wanted:
		_open_online()
		_online_menu.take_link(link)
	else:
		_menu.open()


func _process(delta: float) -> void:
	# A server, a headless client of one, or a boot stopped on bad arguments never
	# reaches the menu's matches.
	if _upcoming == null:
		return
	if _holding != null:
		_hold.advance(delta, _baker.progress())
	elif _online == null and (_match == null or _match.is_over()):
		_bake_upcoming()
	if _args.capture_path.is_empty() or _capturing:
		return
	if _holding != null:
		if _args.capture_screen == "hold" and _hold.visible:
			if _baker.progress() >= HOLD_CAPTURED_AT:
				_capture("the held countdown")
		return
	if _match == null:
		if not _args.autoplay:
			match _args.capture_screen:
				"settings":
					_settings.open()
				"graphics":
					_settings.open(SettingsMenu.Page.GRAPHICS)
				"online":
					_open_online()
				"room":
					_stage_room()
			_capture("the menu")
		return
	var snapshot := _match.current()
	if _capture_due(snapshot):
		_match.set_paused(true)
		match _args.capture_screen:
			"pause":
				_pause.open()
			"online-pause", "online-settings":
				_stage_online_pause(_args.capture_screen == "online-settings")
		_capture(MatchTranscript.clock(snapshot["tick"]))


func _unhandled_input(event: InputEvent) -> void:
	if _match == null:
		return
	if (
		_pause.visible
		and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"))
	):
		_set_paused(false)
	elif not _pause.visible and event.is_action_pressed("pause") and not _match.is_over():
		_set_paused(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _play(ship: StringName, seats: int, tier: StringName, seed_text: String, fast: bool) -> void:
	_on_ship_picked(ship)
	var config := _upcoming.chosen(seats, tier, seed_text, fast)
	var problems := _problems(config, ship)
	if not problems.is_empty():
		if _args.autoplay:
			push_error("\n".join(problems))
			get_tree().quit(1)
		else:
			_menu.show_problem(problems[0])
		return
	_ship = ship
	_seats = seats
	_tier = tier
	_fast = fast
	_upcoming.take(config)
	_menu.hide()
	if config.bake_some(0):
		_start(config)
		return
	_holding = config
	_hold.begin(Ticks.to_seconds(config.countdown_ticks))
	# Over the menu's backdrop, the ship at rest; an autoplay never dressed it, and
	# dressing it now would stall the very frames the hold keeps moving.
	if not _args.autoplay:
		_menu.show_behind(_hold.beside())
	_baker.bake(config, _args.bake_budget_ms if _args.bake_budget_ms > 0.0 else HOLD_BAKE_MS)


## The next blank-seed match goes on [param ship], the menu's pick: a bake under way of
## one drawn on another ship stops.
func _on_ship_picked(ship: StringName) -> void:
	var baking := _baker.baking()
	_upcoming.aim(ship)
	if baking != null and baking != _holding and baking != _upcoming.config():
		_baker.stop()


## Bakes the next blank-seed match's sinking on, gently, while nothing plays.
func _bake_upcoming() -> void:
	if _baker.baking() == null and not _upcoming.config().bake_some(0):
		_baker.bake(_upcoming.config(), MENU_BAKE_MS)


func _on_baked(config: MatchConfig) -> void:
	if config != _holding:
		return
	_holding = null
	_hold.hide()
	_start(config)


## Starts [param config]'s match, its sinking made.
func _start(config: MatchConfig) -> void:
	_baker.stop()
	if _match == null:
		_match = MATCH_SCENE.instantiate()
		add_child(_match)
		_match.rematch_requested.connect(_rematch)
		_match.menu_requested.connect(_to_menu)
	_menu.hide()
	_music.play_match()
	_set_paused(false)
	var capturing := not _args.capture_path.is_empty()
	var observer := _args.observer or (capturing and _args.capture_eye < 0)
	var eye := _args.capture_eye if capturing and _args.capture_eye >= 0 else MatchScene.LOCAL_SEAT
	var jump_to := -1
	if _args.phys_seconds >= 0.0:
		_capture_tick = config.schedule().physics_tick(_args.phys_seconds)
		if _args.jump:
			jump_to = maxi(_capture_tick - Ticks.from_seconds(JUMP_LEAD), 0)
	_match.start(
		config,
		_args.autoplay,
		observer,
		eye,
		_args.observer_cut,
		_args.greybox,
		_args.net_sim,
		jump_to
	)
	if capturing:
		_match.stage_eyes(_args.capture_from)
	if observer:
		_match.watch_from(_args.observer_side)
	if observer and _args.observer_cells:
		_match.show_cells()


func _rematch() -> void:
	_play(_ship, _seats, _tier, "", _fast)


func _to_menu() -> void:
	_pause.hide()
	if _match != null:
		_match.queue_free()
		_match = null
	_menu.open()
	_music.play_menu()


## Stops every sound — the music, the menus' ticks, the match's — and gives the
## mixer a few frames to let go of them first: a playback still alive at exit is
## reported as leaked.
func _quit() -> void:
	for player: AudioStreamPlayer in find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
	if _match != null:
		_match.queue_free()
		_match = null
	for _frame in QUIT_SETTLE_FRAMES:
		await get_tree().process_frame
	get_tree().quit()


func _on_view_changed(settings: ViewSettings) -> void:
	settings.apply_graphics(get_viewport())
	_menu.show_graphics(settings)
	if _match != null:
		_match.apply_view(settings)
	if _online != null:
		_online.apply_view(settings)


## The Online screen over the menu's backdrop, saying [param note] and offering to
## rejoin [param rejoin]'s room when they are not "".
func _open_online(note: String = "", rejoin: String = "") -> void:
	_online_menu.open(note, rejoin)
	_menu.show_behind(_online_menu.panel())


## Plays [param link], the Online screen waiting on it until the room shows.
func _play_online(link: OnlineLink) -> void:
	_drop_online()
	_online = OnlinePlay.new(link)
	_online.entered_room.connect(_on_entered_room)
	_online.playing_changed.connect(_on_online_playing)
	_online.settings = _settings
	_online.ended.connect(_on_online_ended)
	add_child(_online)
	# Ahead of the settings screen, which so hears Esc before the online pause under it.
	move_child(_online, _settings.get_index())
	_online_menu.show_connecting()


func _on_entered_room() -> void:
	_online_menu.hide()
	_menu.show_behind(_online.room_panel())


func _on_online_playing(playing: bool) -> void:
	if playing:
		_online_menu.hide()
		_menu.hide()
		_music.play_match()
	else:
		_menu.show_behind(_online.room_panel())
		_music.play_menu()


func _on_online_ended(to_menu: bool, note: String, rejoin: String) -> void:
	_drop_online()
	_music.play_menu()
	if to_menu:
		_online_menu.hide()
		_menu.open()
	else:
		_open_online(note, rejoin)


## Back from the Online screen, giving up on whatever it was connecting to.
func _leave_online() -> void:
	_drop_online()
	_online_menu.hide()
	_menu.open()


func _drop_online() -> void:
	if _online == null:
		return
	_online.hang_up()
	_online.queue_free()
	_online = null


## A room to capture, its players made up: a host, this player, a name as long as the
## server takes, and the bots for the rest.
func _stage_room() -> void:
	var room: RoomScreen = OnlinePlay.ROOM_SCREEN.instantiate()
	room.seats = _match_rules.seats
	add_child(room)
	var roster := RoomRoster.new()
	roster.code = "KXRT"
	roster.you = 1
	for player: String in ["Ada", "Bea", "Bartholomew Fitz"]:
		roster.players.append(RoomRoster.Player.new(player, player == "Ada", false))
	room.show_room(roster)
	_menu.show_behind(room.panel())


## The online pause over the match, and the settings opened from it when
## [param settings] says, to capture: no server asked.
func _stage_online_pause(settings: bool) -> void:
	var pause: OnlinePause = OnlinePlay.ONLINE_PAUSE.instantiate()
	add_child(pause)
	pause.open()
	if settings:
		_settings.open()


func _set_paused(paused: bool) -> void:
	_match.set_paused(paused)
	if paused:
		_pause.open()
	else:
		_pause.hide()


## Why [param config], on [param ship], cannot start; a null config is a menu choice
## from_menu refused.
func _problems(config: MatchConfig, ship: StringName) -> PackedStringArray:
	if config == null:
		var layout := Fleet.layout(ship) if not ship.is_empty() else _match_rules.ship
		if layout == null:
			return PackedStringArray(["Choose a ship: %s" % ", ".join(Fleet.names())])
		return PackedStringArray(
			[
				(
					"Choose %d to %d seats, and a seed that is blank or a whole number"
					% [layout.min_seats, layout.max_seats]
				)
			]
		)
	var found := config.problems()
	found.append_array(_args.problems())
	if _args.capture_eye >= config.seats:
		found.append("capture: no seat %d in a %d-seat match" % [_args.capture_eye, config.seats])
	var profile := BotProfile.for_tier(config.bot_tier)
	if profile == null:
		found.append("menu: no bot profile named %s under data/bots/" % config.bot_tier)
	else:
		found.append_array(profile.problems())
	return found


func _capture_due(snapshot: Dictionary) -> bool:
	if snapshot["phase"] == MatchState.Phase.ENDED:
		return true
	if _capture_tick >= 0:
		return snapshot["tick"] >= _capture_tick
	return _args.capture_at >= 0.0 and snapshot["tick"] >= Ticks.from_seconds(_args.capture_at)


## Lets the view settle on what is showing, saves the frame and quits.
func _capture(moment: String) -> void:
	_capturing = true
	# The results' buttons take presses only once their guard is over: show them so.
	if _args.capture_screen == "results":
		await get_tree().create_timer(EndOverlay.PRESS_GUARD_SECONDS).timeout
	for _frame in CAPTURE_SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_args.capture_path)
	if error != OK:
		push_error("capture: %s: %s" % [_args.capture_path, error_string(error)])
		get_tree().quit(1)
		return
	print("captured %s at %s" % [_args.capture_path, moment])
	get_tree().quit()
