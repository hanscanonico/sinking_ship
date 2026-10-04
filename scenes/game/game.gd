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

@onready var _menu: MainMenu = $MainMenu
@onready var _pause: PauseMenu = $PauseMenu
@onready var _settings: SettingsMenu = $SettingsMenu
@onready var _music: MusicPlayer = $Music


func _ready() -> void:
	_args = MatchArgs.parse(OS.get_cmdline_user_args())
	if _args.server:
		add_child(ServerLoop.new(_args))
		return
	if not _args.connect_url.is_empty():
		if _args.autoplay:
			add_child(OnlineAutoplay.new(_args))
			return
		push_warning("--connect plays with --autoplay until the Online menu (SH12b)")
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
	_menu.settings_requested.connect(_settings.open)
	_menu.quit_requested.connect(_quit)
	_pause.resume_requested.connect(_set_paused.bind(false))
	_pause.menu_requested.connect(_to_menu)
	_pause.settings_requested.connect(_settings.open)
	_pause.quit_requested.connect(_quit)
	_settings.view_changed.connect(_on_view_changed)
	var seats := _args.seats if _args.seats > 0 else _match_rules.seats
	var seed_text := str(_args.seed_value) if _args.seed_value >= 0 else ""
	_menu.setup(_match_rules, seats, _match_rules.bot_tier, seed_text)
	if _args.autoplay:
		_play.call_deferred(seats, _match_rules.bot_tier, seed_text)
	else:
		_menu.open()
		_music.play_menu()


func _process(_delta: float) -> void:
	if _args.capture_path.is_empty() or _capturing:
		return
	if _match == null:
		if not _args.autoplay:
			_capture("the menu")
		return
	var snapshot := _match.current()
	if _capture_due(snapshot):
		_match.set_paused(true)
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
