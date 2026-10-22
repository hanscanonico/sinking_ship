class_name Game
extends Node
## What `make run` boots: the main menu, then matches. Every match the UI starts
## — Play, and Rematch with the same choices on a new seed — is made of the menu's
## MatchChoices (D13). Esc / Start pauses by stopping the match's
## SimDriver; the pause is never sim state. User arguments are MatchArgs':
## their match choices fill the menu in, --autoplay presses Play for a bot on the
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

## Where a replay was opened from (R6): leaving it goes back there.
enum ReplayFrom { MENU, LIST, RESULTS }

var _args: MatchArgs
var _match_rules: MatchRules
## Where a blank seed is drawn from: outside the sim, once per match.
var _seeds := RandomNumberGenerator.new()
var _match: MatchScene
## The last match's choices, their seed blank, for a rematch: a fresh one is drawn.
var _rematch_choices: MatchChoices
## The match under way's choices, their seed the one it plays: what its replay is
## built from (MatchScene.choices).
var _playing: MatchChoices
## The saved replays' list (R6), and where the replay being watched was opened from:
## where leaving it goes back to.
var _replays: ReplaysMenu
var _replay_from := ReplayFrom.MENU
## The replay held for its match's sinking to bake or its ship to be dressed (_holding is
## its config); null while none is.
var _holding_replay: ReplayFile
var _capturing := false
## Watches a capture's window for frames drawn, so one the system stops drawing fails
## rather than wait forever (#105); null when not capturing.
var _draw_watch: DrawWatch
## The online play under way, from the Online screen; null when none is.
var _online: OnlinePlay
## The view settings, held so that what --quality and --render-scale choose holds all
## run, never saved.
var _view: ViewSettings
## The tick a capture is due at, past a --phys moment; -1 for --capture-at's.
var _capture_tick := -1
## The next blank-seed match, its seed drawn ahead so its sinking can be made
## on the menu; the match held for its sinking or its ship, and how it will start.
var _upcoming: NextMatch
var _holding: MatchConfig
var _baker := SinkingBaker.new()
## The ship dressed, or being dressed, for the match held or the next one (ShipDressing),
## until a match takes it; and whether the held match waits on its dressing — that one,
## null for the greybox, which none draws — rather than on its sinking's bake.
var _dressing: ShipDressing
var _dressed_hold := false
var _held_dressing: ShipDressing
## The frame the held match began waiting on its dressing: it starts a frame on at the
## soonest.
var _held_since := 0
## The held match served on a thread once its ship is dressed (MatchScene.serve), what it
## served kept beside the config it was served for until that match takes it.
var _serving := MatchServing.new()
## Where each frame's time goes, when --frame-split asks (make fps SPLIT=1); null else.
var _probe: FrameProbe
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
	KeyBindings.local().apply()
	_view = ViewSettings.local()
	# A capture, and a bot's autoplay (make fps), keep the window, VSync and frame rate
	# they were launched with, whatever the player saved.
	if _args.capture_path.is_empty() and not _args.autoplay:
		_view.apply_window()
	else:
		_draw_watch = DrawWatch.new()
	_view.run_quality = _args.quality
	_view.run_render_scale = _args.render_scale
	_view.apply_graphics(get_viewport())
	_match_rules = load(MATCH_DATA)
	var problems := _match_rules.problems()
	problems.append_array(_args.choices.problems(_match_rules))
	if not problems.is_empty():
		push_error("\n".join(problems))
		get_tree().quit(1)
		return
	_upcoming = NextMatch.new(_match_rules, _seeds)
	if _args.frame_split >= 0.0:
		_probe = FrameProbe.new(_args.frame_split)
		add_child(_probe)
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
	_replays = ReplaysMenu.new()
	_replays.name = "ReplaysMenu"
	add_child(_replays)
	_menu.replays_requested.connect(_open_replays)
	_replays.watch_requested.connect(_watch_from_list)
	_replays.back_requested.connect(_leave_replays)
	_settings.view_changed.connect(_on_view_changed)
	_settings.closed.connect(_on_settings_closed)
	_online_menu.play_requested.connect(_play_online)
	_online_menu.back_requested.connect(_leave_online)
	var link := OnlineLink.for_launch(_args)
	_online_menu.page_server = link.server_url
	_menu.setup(_match_rules, _args.choices)
	_upcoming.aim(_menu.choices())
	if not is_nan(_args.capture_sway):
		_menu.hold_drift(_args.capture_sway)
	if not _args.replay_path.is_empty():
		_open_replay_path(_args.replay_path)
		return
	if _args.autoplay:
		_play.call_deferred(_menu.choices())
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
		var dressed := _held_dressing == null or _held_dressing.done()
		if _dressed_hold and Engine.get_process_frames() > _held_since and dressed:
			if _served_held():
				_release_held()
	elif _online == null and (_match == null or _match.is_over()):
		_bake_upcoming()
	if (
		_draw_watch != null
		and _draw_watch.stalled(Engine.get_frames_drawn(), Time.get_ticks_msec())
	):
		push_error("capture: %s: %s" % [_args.capture_path, _draw_watch.stall_message()])
		_draw_watch = null
		get_tree().quit(1)
		return
	if _args.capture_path.is_empty() or _capturing:
		return
	# The backdrop shows its ship once she is dressed, on a thread (MenuBackdrop).
	if _holding != null:
		if _args.capture_screen == "hold" and _hold.visible and _menu.dressed():
			if _baker.progress() >= HOLD_CAPTURED_AT:
				_capture("the held countdown")
		return
	if _match == null:
		if not _args.autoplay and _menu.dressed():
			match _args.capture_screen:
				"settings":
					_settings.open()
				"graphics":
					_settings.open(SettingsMenu.Page.GRAPHICS)
				"online":
					_open_online()
				"room":
					_stage_room()
				"replays":
					_open_replays()
			_capture("the menu")
		return
	var snapshot := _match.current()
	if _capture_due(snapshot):
		_match.set_paused(true)
		match _args.capture_screen:
			"pause":
				_pause.open(_match.prompts(), _match.spectating())
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
	elif not _pause.visible and event.is_action_pressed("pause") and _takes_pause():
		_set_paused(true)
	else:
		return
	get_viewport().set_input_as_handled()


## Whether Esc / Start pauses the match: one being played, never a countdown held for its
## sinking or its ship — whose match has not started, so nothing says it is over — nor
## a replay, nor a match over.
func _takes_pause() -> bool:
	if _holding != null or _holding_replay != null:
		return false
	return not _match.is_over() and not _match.replaying()


## Gives up the countdown held, if one is: its match or replay never starts — its bake
## stopped, its ship's dressing dropped, what was served of it let go, never waited on
## (MatchServing).
func _cancel_hold() -> void:
	if _holding == null:
		return
	_baker.stop()
	_holding = null
	_holding_replay = null
	_dressed_hold = false
	_held_dressing = null
	_hold.hide()
	if _dressing != null:
		_dressing.drop()
		_dressing = null
	_serving.cancel()


func _play(choices: MatchChoices) -> void:
	var problems := choices.problems(_match_rules)
	var config: MatchConfig = null
	if problems.is_empty():
		_aim(choices)
		config = _upcoming.chosen(choices)
		problems = _problems(config)
	if not problems.is_empty():
		if _args.autoplay:
			push_error("\n".join(problems))
			get_tree().quit(1)
		else:
			_menu.show_problem(problems[0])
		return
	_rematch_choices = choices.with_seed("")
	_playing = choices.with_seed(str(config.match_seed))
	_upcoming.take(config)
	_menu.hide()
	_holding = config
	_hold.begin(Ticks.to_seconds(config.countdown_ticks))
	if config.bake_some(0):
		_dress_held()
		return
	_hold_over_backdrop()
	_baker.bake(config, _args.bake_budget_ms if _args.bake_budget_ms > 0.0 else HOLD_BAKE_MS)


## The countdown held over the menu's backdrop, the ship at rest, while the held match's
## sinking bakes or its ship is dressed.
func _hold_over_backdrop() -> void:
	# A rematch's, or a replay's from them: the results stand aside, or they draw over
	# the hold — kept for the way back (_close_replay).
	if _match != null:
		_match.stand_aside()
	# An autoplay never built the backdrop, and has nobody to show it to: building it now
	# would only take from the frames the hold keeps moving.
	if not _args.autoplay:
		_menu.show_behind(_hold.beside())


## The next blank-seed match goes on the menu's pick of ship.
func _on_ship_picked() -> void:
	_aim(_menu.choices())


## The next blank-seed match is drawn on [param choices]: a bake under way of one drawn
## on another sinking stops.
func _aim(choices: MatchChoices) -> void:
	var baking := _baker.baking()
	_upcoming.aim(choices)
	if baking != null and baking != _holding and baking != _upcoming.config():
		_baker.stop()


## Bakes the next blank-seed match's sinking on, gently, while nothing plays, and dresses
## her ship once it is baked, on a thread: so Play starts at once.
func _bake_upcoming() -> void:
	var next := _upcoming.config()
	if next == null:
		return
	if not next.bake_some(0):
		if _baker.baking() == null:
			_baker.bake(next, MENU_BAKE_MS)
	# A frame split times the match's sinking as it is first built: dressing her builds it.
	elif _probe == null:
		_dressing_of(next)


func _on_baked(config: MatchConfig) -> void:
	if config == _holding:
		_dress_held()


## Starts the held match or replay once its ship is dressed — a frame on at the soonest,
## the countdown held over the backdrop meanwhile (_process) — its scene made now, standing
## aside: making it and starting it would each fill most of a frame.
func _dress_held() -> void:
	_held_dressing = _dressing_of(_holding, _holding_replay != null)
	_dressed_hold = true
	_held_since = Engine.get_process_frames()
	if _match == null:
		_ensure_match()
		_match.stand_aside()
	_hold_over_backdrop()


## Whether the held match is served (MatchScene.serve): a match served on a thread, which
## starts once that is done — but a replay, which no loopback serves, and a tool's jump or
## frame split, which start() serves itself.
func _served_held() -> bool:
	var jumps := _args.phys_seconds >= 0.0 and _args.jump
	if _holding_replay != null or jumps or _probe != null:
		return true
	var config := _holding
	if _serving.ready_for(config):
		return true
	# One served for another held match, given up, ends first; what it served is dropped.
	if _serving.busy():
		return false
	# Her ship dressed, her sinking is built: nothing else builds it meanwhile.
	var local := MatchScene.local_for(config, _args.autoplay)
	var net_sim := _args.net_sim
	_serving.serve(
		config, func() -> MatchScene.Served: return MatchScene.serve(config, local, net_sim)
	)
	return false


## The held match, or its replay, starts: its sinking is made and its ship dressed.
func _release_held() -> void:
	var config := _holding
	var file := _holding_replay
	_holding = null
	_holding_replay = null
	_dressed_hold = false
	_held_dressing = null
	_hold.hide()
	if file != null:
		_begin_replay(file, config)
	else:
		_start(config)


## The ship of [param config]'s match — or of its replay, when [param watched] — dressed,
## or being dressed on a thread, as it will be drawn: the one dressed or under way when it
## fits, a new one otherwise, which drops any other; null for a match drawn as the
## greybox, which no dressing draws.
func _dressing_of(config: MatchConfig, watched: bool = false) -> ShipDressing:
	if _args.greybox and not watched:
		return null
	# A replay is seen through eyes (MatchScene.start_replay).
	var cut := INF if watched else MatchScene.cut_of(_observer(), _args.observer_cut)
	if _dressing != null and _dressing.fits(config, cut):
		return _dressing
	if _dressing != null:
		_dressing.drop()
	# A frame split times the poses of her sinking as it is first built: dressing her does.
	if _probe != null and not FrameMeter.time_schedule(config, _probe.split):
		push_warning("frame split: the match's sinking was built already; its poses untimed")
	_dressing = ShipDressing.new(config, cut).start()
	return _dressing


## [param config]'s ship dressed (_dressing_of), handed over to its match or its replay,
## when [param watched], to take; no longer this one's.
func _take_dressing(config: MatchConfig, watched: bool = false) -> ShipDressing:
	var dressing := _dressing_of(config, watched)
	_dressing = null
	return dressing


## Whether the match is seen through the observer camera rather than a seat's eyes: as
## --observer asks, and for a capture taken neither through a seat's eyes nor from eyes
## stood in ship space (--capture-from), which look through a seat's.
func _observer() -> bool:
	var capturing := not _args.capture_path.is_empty()
	var staged := capturing and not _args.capture_from.is_empty()
	return _args.observer or (capturing and _args.capture_eye < 0 and not staged)


## Starts [param config]'s match, its sinking made and its ship dressed.
func _start(config: MatchConfig) -> void:
	_baker.stop()
	_ensure_match()
	_menu.hide()
	_music.play_match()
	_set_paused(false)
	var capturing := not _args.capture_path.is_empty()
	var observer := _observer()
	var eye := _args.capture_eye if capturing and _args.capture_eye >= 0 else MatchScene.LOCAL_SEAT
	var split: FrameSplit = null
	if _probe != null:
		split = _probe.split
		_probe.playing = true
		# A dressed ship's dressing timed her sinking (_dressing_of); the greybox has none.
		if _args.greybox and not FrameMeter.time_schedule(config, split):
			push_warning("frame split: the match's sinking was built already; its poses untimed")
	var jump_to := -1
	if _args.phys_seconds >= 0.0:
		_capture_tick = config.schedule().physics_tick(_args.phys_seconds)
		if _args.jump:
			jump_to = maxi(_capture_tick - Ticks.from_seconds(JUMP_LEAD), 0)
	_match.choices = _playing
	_match.dressing = _take_dressing(config)
	_match.served = _serving.take(config)
	_match.start(
		config,
		_args.autoplay,
		observer,
		eye,
		_args.observer_cut,
		_args.greybox,
		_args.net_sim,
		jump_to,
		split
	)
	if capturing:
		_match.stage_eyes(_args.capture_from)
	if capturing and not is_nan(_args.capture_wet):
		_match.wet_lens(_args.capture_wet)
	if observer:
		_match.watch_from(_args.observer_side)
	if observer and _args.observer_cells:
		_match.show_cells()


## The match scene, made the first time a match or a replay needs it.
func _ensure_match() -> void:
	if _match != null:
		return
	_match = MATCH_SCENE.instantiate()
	add_child(_match)
	_match.rematch_requested.connect(_rematch)
	_match.menu_requested.connect(_to_menu)
	_match.replay_closed.connect(_close_replay)
	_match.replay_requested.connect(_watch_from_results)


## Opens the replay saved at [param path] (--replay); quits, the reason printed, when
## nothing readable is there or it can no longer be played.
func _open_replay_path(path: String) -> void:
	var file := ReplayStore.new().load_file(path)
	if file == null:
		push_error("replay: %s is not a replay the game can read" % path)
		get_tree().quit(1)
		return
	if not file.playable(_match_rules):
		push_error(
			"replay: %s cannot be played: its match data has changed, or it started mid-way" % path
		)
		get_tree().quit(1)
		return
	_replay_from = ReplayFrom.MENU
	_start_replay(file)


## The saved replays over the menu's backdrop (R6).
func _open_replays() -> void:
	_replays.open(ReplayStore.new(), _match_rules)
	_menu.show_behind(_replays.panel())


func _leave_replays() -> void:
	_replays.hide()
	_menu.open()


func _watch_from_list(file: ReplayFile) -> void:
	_replay_from = ReplayFrom.LIST
	_replays.hide()
	_start_replay(file)


func _watch_from_results(file: ReplayFile) -> void:
	if file == null:
		return
	_replay_from = ReplayFrom.RESULTS
	_start_replay(file)


## Watches [param file] in the match scene (R4), its match's sinking made first as a
## played match's is (R20): the countdown held over the backdrop while it bakes —
## never from the results, whose match made that very sinking already.
func _start_replay(file: ReplayFile) -> void:
	var played: MatchConfig = null
	if _replay_from == ReplayFrom.RESULTS and _match != null:
		played = _match.played_config()
	var config := replay_config(file, _match_rules, played)
	if config == null:
		push_error("replay: its choices no longer make a match")
		return
	_baker.stop()
	_menu.hide()
	_pause.hide()
	_holding = config
	_holding_replay = file
	_hold.begin(Ticks.to_seconds(config.countdown_ticks))
	if config.bake_some(0):
		_dress_held()
		return
	_hold_over_backdrop()
	_baker.bake(config, _args.bake_budget_ms if _args.bake_budget_ms > 0.0 else HOLD_BAKE_MS)


## The match [param file] plays, on [param match_rules]; null when its choices no longer
## make one. It takes [param played]'s sinking, baked or under way, when that match is
## the same — the same ship, scenario and seed make the same sinking (D7) — so a replay
## watched from the results never bakes hers again.
static func replay_config(
	file: ReplayFile, match_rules: MatchRules, played: MatchConfig
) -> MatchConfig:
	var config := file.config(match_rules)
	if config != null:
		config.share_sinking(played)
	return config


## Watches [param file] on [param config], its sinking made, in the match scene.
func _begin_replay(file: ReplayFile, config: MatchConfig) -> void:
	_ensure_match()
	_menu.hide()
	_pause.hide()
	_music.play_match()
	_match.set_paused(false)
	_match.dressing = _take_dressing(config, true)
	_match.start_replay(file, config)


## Back from a replay, to where it was opened from (R6): the results it was watched
## from, the list of replays, or the menu (--replay).
func _close_replay() -> void:
	match _replay_from:
		ReplayFrom.RESULTS:
			_match.show_results_again()
		ReplayFrom.LIST:
			_to_menu()
			_open_replays()
		_:
			_to_menu()


func _rematch() -> void:
	_play(_rematch_choices)


func _to_menu() -> void:
	_cancel_hold()
	_pause.hide()
	if _probe != null:
		_probe.playing = false
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


# However the game quits — its Quit, a capture taken, the window closed — every ship being
# dressed on a thread is finished first: left, its thread would wait on frames that never
# come, and the game would never end (ShipDressing). A match being served is waited for
# after them, never before: its task may wait on the pool's threads they hold.
func _exit_tree() -> void:
	if _dressing != null:
		_dressing.drop()
		_dressing = null
	ShipDressing.finish_all()
	_serving.finish()


## The pause's controls as the keys now stand, the settings having maybe rebound them.
func _on_settings_closed() -> void:
	if _match != null and _pause.visible:
		_pause.show_controls(_match.prompts(), _match.spectating())


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
		_pause.open(_match.prompts(), _match.spectating())
	else:
		_pause.hide()


## Why [param config], made of choices free of problems, cannot start.
func _problems(config: MatchConfig) -> PackedStringArray:
	var found := config.problems()
	if not _args.capture_from.is_empty() and _args.capture_from.size() < 4:
		found.append("capture: FROM=x,y,z takes LOOK=x,y,z, or --capture-from a yaw")
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
