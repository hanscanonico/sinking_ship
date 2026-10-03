class_name MatchScene
extends Node3D
## What `make run` boots: one match of the default data — the local player on the
## first seat (a bot with --autoplay), bots on the rest — restarted on a fresh seed
## after a result. User arguments are MatchArgs'; --capture saves a frame and quits.

const MATCH_DATA := "res://data/match/default.tres"
const LOCAL_SEAT := 0
## Frames drawn after a capture's moment, so the view has settled on it.
const CAPTURE_SETTLE_FRAMES := 3

var _args: MatchArgs
var _seeds := RandomNumberGenerator.new()
var _capturing := false

@onready var _driver: SimDriver = $SimDriver
@onready var _view: MatchView = $MatchView
@onready var _rig: CameraRig = $CameraRig
@onready var _hud: Hud = $Hud
@onready var _end: EndOverlay = $EndOverlay


func _ready() -> void:
	_args = MatchArgs.parse(OS.get_cmdline_user_args())
	_seeds.randomize()
	_end.restart_requested.connect(_restart)
	_end.quit_requested.connect(get_tree().quit)
	_start(_args.seed_value if _args.seed_value >= 0 else _seeds.randi())


func _process(delta: float) -> void:
	if _driver.runner == null:
		return
	var snapshot := _driver.current
	_hud.show_snapshot(snapshot)
	_end.show_snapshot(snapshot, LOCAL_SEAT)
	_rig.follow(_view.seat_world_position(LOCAL_SEAT), delta)
	if not _args.capture_path.is_empty() and not _capturing and _capture_due(snapshot):
		_capture(snapshot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("restart") and _end.visible:
		_restart()


func _start(seed_value: int) -> void:
	var match_rules: MatchRules = load(MATCH_DATA)
	var config := MatchConfig.from_rules(match_rules, seed_value, _args.seats)
	var problems := config.problems()
	if not problems.is_empty():
		push_error("\n".join(problems))
		get_tree().quit(1)
		return
	var profile := BotProfile.for_tier(match_rules.bot_tier)
	var sources: Array[InputSource] = []
	if match_rules.humans > 0 and not _args.autoplay:
		sources.append(LocalInputSource.new(LOCAL_SEAT, _rig))
	else:
		sources.append(BotInputSource.new(LOCAL_SEAT, profile, config))
	sources.append_array(BotInputSource.fill(config, profile, LOCAL_SEAT + 1))
	var sim := MatchSim.create(config)
	_driver.start(MatchRunner.new(sim, sources))
	_view.setup(_driver, sim, LOCAL_SEAT)
	_rig.reset(_view.seat_world_position(LOCAL_SEAT), _deck_bounds(config.ship))
	_end.hide()
	print("match seed %d" % seed_value)


func _restart() -> void:
	_start(_seeds.randi())


## Every platform's area together, in the ship plane.
func _deck_bounds(layout: ShipLayout) -> Rect2:
	var bounds := layout.platforms[0].area
	for platform: ShipPlatform in layout.platforms:
		bounds = bounds.merge(platform.area)
	return bounds


func _capture_due(snapshot: Dictionary) -> bool:
	if snapshot["phase"] == MatchState.Phase.ENDED:
		return true
	return _args.capture_at >= 0.0 and snapshot["tick"] >= Ticks.from_seconds(_args.capture_at)


## Holds the match where it is, lets the view settle, saves the frame and quits.
func _capture(snapshot: Dictionary) -> void:
	_capturing = true
	_driver.set_process(false)
	for _frame in CAPTURE_SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_args.capture_path)
	if error != OK:
		push_error("capture: %s: %s" % [_args.capture_path, error_string(error)])
		get_tree().quit(1)
		return
	print("captured %s at %s" % [_args.capture_path, MatchTranscript.clock(snapshot["tick"])])
	get_tree().quit()
