class_name MatchScene
extends Node3D
## One match of the config Game hands in — the local player on the first seat (a
## bot when autoplaying), bots of the config's tier on the rest — spectated once
## the local seat is out, with the results at its end. Rematch and menu go back
## to Game, which builds every config through MatchConfig.from_menu (D13).

signal rematch_requested
signal menu_requested

const LOCAL_SEAT := 0

var _config: MatchConfig
var _stats: MatchStats
var _spectator: Spectator
var _names := PackedStringArray()

@onready var _driver: SimDriver = $SimDriver
@onready var _view: MatchView = $MatchView
@onready var _rig: CameraRig = $CameraRig
@onready var _hud: Hud = $Hud
@onready var _end: EndOverlay = $EndOverlay


func _ready() -> void:
	_end.rematch_requested.connect(rematch_requested.emit)
	_end.menu_requested.connect(menu_requested.emit)
	_driver.stepped.connect(func(events: Array[SimEvent]) -> void: _stats.add(events))


func _process(delta: float) -> void:
	if _driver.runner == null:
		return
	var snapshot := _driver.current
	var followed := _spectator.target(snapshot)
	_hud.show_snapshot(snapshot)
	_hud.show_spectating(_spectating(snapshot, followed))
	_end.show_results(_stats, LOCAL_SEAT, _names, _config.match_seed)
	_rig.follow(_view.seat_world_position(followed), delta)


func _unhandled_input(event: InputEvent) -> void:
	if _driver.runner == null:
		return
	if _end.visible and event.is_action_pressed("restart"):
		rematch_requested.emit()
	elif _end.visible and event.is_action_pressed("pause"):
		menu_requested.emit()
	elif event.is_action_pressed("spectate_next"):
		_spectator.cycle(_driver.current, 1)
	elif event.is_action_pressed("spectate_previous"):
		_spectator.cycle(_driver.current, -1)
	else:
		return
	get_viewport().set_input_as_handled()


## Starts [param config]'s match from its first tick; [param autoplay] puts a bot
## on the local seat.
func start(config: MatchConfig, autoplay: bool) -> void:
	_config = config
	var profile := BotProfile.for_tier(config.bot_tier)
	var sources: Array[InputSource] = []
	if config.humans > 0 and not autoplay:
		sources.append(LocalInputSource.new(LOCAL_SEAT, _rig))
	else:
		sources.append(BotInputSource.new(LOCAL_SEAT, profile, config))
	sources.append_array(BotInputSource.fill(config, profile, LOCAL_SEAT + 1))
	var sim := MatchSim.create(config)
	_stats = MatchStats.new(config.seats, config.countdown_ticks)
	_spectator = Spectator.new(LOCAL_SEAT, _stats)
	_names = _seat_names(config.seats)
	_driver.start(MatchRunner.new(sim, sources))
	_view.setup(_driver, sim, LOCAL_SEAT)
	_hud.setup(sim)
	_rig.reset(_view.seat_world_position(LOCAL_SEAT), _deck_bounds(config.ship))
	_end.hide()
	print("match seed %d" % config.match_seed)


## The latest snapshot.
func current() -> Dictionary:
	return _driver.current


## Whether the latest snapshot says the match has ended.
func is_over() -> bool:
	return _driver.current.get("phase", -1) == MatchState.Phase.ENDED


## Pausing stops the SimDriver and nothing else: it is never sim state.
func set_paused(paused: bool) -> void:
	_driver.set_process(not paused)


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


## The banner while the local seat is out and the match goes on; empty otherwise.
func _spectating(snapshot: Dictionary, followed: int) -> String:
	var seats: Array = snapshot["seats"]
	var mine: Dictionary = seats[LOCAL_SEAT]
	if not mine["out"] or snapshot["phase"] == MatchState.Phase.ENDED:
		return ""
	return (
		"Overboard — %s of %d   ·   watching %s   ·   Q / E or d-pad to switch"
		% [EndOverlay.ordinal(mine["place"]), seats.size(), _names[followed]]
	)
