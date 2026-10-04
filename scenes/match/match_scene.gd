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

const LOCAL_SEAT := 0
## The gaze through another seat's eyes, in degrees above the horizon: at a level
## gaze the deck within about 3 m of the feet is under the frame.
const SPECTATE_PITCH_DEG := -10.0
## The view's shake, 0…1 of a lurch's, as a lurch is telegraphed and as a deck
## collapses.
const LURCH_WARNING_SHAKE := 0.4
const COLLAPSE_SHAKE := 0.6

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
var _paused := false
## The mouse let go mid-match without pausing: an online match never pauses.
var _mouse_freed := false
var _marks := BrawlMarks.new()
var _dust := LandingDust.new()
var _prompts := InputPrompts.new()
var _kick: ViewKick

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
	add_child(_prompts)


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
	_hud.show_spectating(_spectating(snapshot, viewed))
	_hud.show_controls(_prompts.controls() if _local != null else "")
	_end.show_results(_stats, _local_seat, _names, _config.match_seed)
	_end.show_prompts(_prompts)
	var mouse := Input.MOUSE_MODE_CAPTURED if _looking() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mouse:
		Input.mouse_mode = mouse
	if _looking():
		_local.look_by_stick(delta)
	_audio.hear_through(-1 if _observer else viewed)
	if _observer:
		_observer_camera.follow(_view.seat_world_position(viewed), delta)
		_first_person_hud.show_view(snapshot, viewed, 0.0, _eyes, _view)
		return
	# Another seat's pitch never leaves its client, so its gaze is fixed (D14): a
	# little below level, so the deck and its edges show under the horizon.
	var yaw := _view.seat_facing(viewed)
	var pitch := deg_to_rad(SPECTATE_PITCH_DEG)
	if _local != null and viewed == _local_seat:
		yaw = _local.yaw
		pitch = _local.pitch
	_view.look_out_of(viewed)
	_kick.follow(snapshot, viewed, yaw)
	var kick := _kick.advance(delta)
	_eyes.look_from(_view.ship_to_world(), _view.seat_feet(viewed), yaw, pitch, kick)
	_arms.show_seat(
		viewed, _driver.previous["seats"][viewed], snapshot["seats"][viewed], _driver.alpha
	)
	_underwater.show_eye(_eyes.global_position)
	_first_person_hud.show_view(snapshot, viewed, yaw, _eyes, _view)


func _unhandled_input(event: InputEvent) -> void:
	if _driver.client == null:
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
	_begin(played, local, seat, names, false, seat, INF, false)


## Lets the mouse go, or takes it back, without pausing: the online match's Esc.
func free_mouse(freed: bool) -> void:
	_mouse_freed = freed


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
	_kick = ViewKick.new(settings.view_kick)
	_eyes.setup(settings)
	_arms.setup(config.rules)
	_first_person_hud.setup(sim, _names, not observer, _prompts)
	_underwater.setup($SeaAndSky/Environment as WorldEnvironment)
	_observer_camera.whole_ship = observer and is_finite(observer_cut)
	_audio.setup(_driver, sim, _view, _local_seat, _underwater)
	_observer_camera.reset(_view.seat_world_position(_eye_seat), _deck_bounds(config.ship))
	if observer:
		_observer_camera.make_current()
	else:
		_eyes.make_current()
	_end.hide()
	print("match seed %d" % config.match_seed)


## Takes up the settings screen's field of view, deck roll and view kick mid-match;
## the look's sensitivity and invert-Y are read from the same settings as they turn.
func apply_view(settings: ViewSettings) -> void:
	_eyes.setup(settings)
	_kick.set_strength(settings.view_kick)


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


## The sinking is felt before it is seen (D12): a light shake as a lurch is
## telegraphed, a full one as it swings, a lighter one as a deck gives way — read
## from every stepped tick's events, so a hitch never eats one.
func _shake_for_the_sinking(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SHIP_LURCHING:
				_kick.shake(LURCH_WARNING_SHAKE)
			SimEvent.Kind.SHIP_LURCHED:
				_kick.shake()
			SimEvent.Kind.PLATFORM_COLLAPSED:
				_kick.shake(COLLAPSE_SHAKE)


## Whether the local player's mouse and stick turn their look now: in play, and
## neither paused, at the results nor with the mouse let go.
func _looking() -> bool:
	return _local != null and not _paused and not _end.visible and not _mouse_freed


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
		"Overboard — %s of %d   ·   %s   ·   %s / %s to switch"
		% [
			EndOverlay.ordinal(mine["place"]),
			seats.size(),
			whose,
			_prompts.word(&"spectate_previous"),
			_prompts.word(&"spectate_next"),
		]
	)
