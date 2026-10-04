class_name Game
extends Node
## What `make run` boots: the main menu, then matches. Every match the UI starts
## — Play, and Rematch with the same seats and tier on a new seed — is built by
## MatchConfig.from_menu (D13). Esc / Start pauses by stopping the match's
## SimDriver; the pause is never sim state. User arguments are MatchArgs':
## --seed and --seats fill the menu in, --autoplay presses Play for a bot on the
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
## --capture-screen stages the settings, the pause menu, the results, the Online screen,
## a room — its players made up, no server asked — or the online pause over the match,
## the settings opened from it or not, for a capture.
## The saved volumes and window apply as it boots; the settings screen opens from
## the main menu and the pause menu.

const MATCH_DATA := "res://data/match/default.tres"
const MATCH_SCENE := preload("res://scenes/match/match.tscn")
## Frames drawn after a capture's moment, so the view has settled on it.
const CAPTURE_SETTLE_FRAMES := 3
## Frames between silencing everything and quitting, for the mixer to let go.
const QUIT_SETTLE_FRAMES := 4

var _args: MatchArgs
var _match_rules: MatchRules
## Where a blank seed is drawn from: outside the sim, once per match.
var _seeds := RandomNumberGenerator.new()
var _match: MatchScene
## The last match's seats and tier, for a rematch.
var _seats: int
var _tier: StringName
var _capturing := false
## The online play under way, from the Online screen; null when none is.
var _online: OnlinePlay

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
	# A capture keeps the window it was launched with, whatever the player saved.
	if _args.capture_path.is_empty():
		ViewSettings.local().apply_window()
	_match_rules = load(MATCH_DATA)
	var problems := _match_rules.problems()
	if not problems.is_empty():
		push_error("\n".join(problems))
		get_tree().quit(1)
		return
	_menu.play_requested.connect(_play)
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
	_menu.setup(_match_rules, seats, _match_rules.bot_tier, seed_text)
	if _args.autoplay:
		_play.call_deferred(seats, _match_rules.bot_tier, seed_text)
		return
	_music.play_menu()
	if link.wanted:
		_open_online()
		_online_menu.take_link(link)
	else:
		_menu.open()


func _process(_delta: float) -> void:
	if _args.capture_path.is_empty() or _capturing:
		return
	if _match == null:
		if not _args.autoplay:
			match _args.capture_screen:
				"settings":
					_settings.open()
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


func _play(seats: int, tier: StringName, seed_text: String) -> void:
	var config := MatchConfig.from_menu(_match_rules, seats, tier, seed_text, _seeds)
	var problems := _problems(config)
	if not problems.is_empty():
		if _args.autoplay:
			push_error("\n".join(problems))
			get_tree().quit(1)
		else:
			_menu.show_problem(problems[0])
		return
	_seats = seats
	_tier = tier
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
	_match.start(
		config, _args.autoplay, observer, eye, _args.observer_cut, _args.greybox, _args.net_sim
	)
	if capturing:
		_match.stage_eyes(_args.capture_from)


func _rematch() -> void:
	_play(_seats, _tier, "")


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


## Why [param config] cannot start; a null config is a menu choice from_menu
## refused.
func _problems(config: MatchConfig) -> PackedStringArray:
	if config == null:
		return PackedStringArray(
			[
				(
					"Choose %d to %d seats, and a seed that is blank or a whole number"
					% [_match_rules.min_seats, _match_rules.max_seats]
				)
			]
		)
	var found := config.problems()
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
