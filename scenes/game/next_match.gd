class_name NextMatch
extends RefCounted
## The next blank-seed match the menu plays: its seed drawn ahead, and the match struck
## by --hit as every match the game plays is, so its sinking can be baked while the menu
## or the results show (R20). A Play with a blank seed takes it, and the sinking made of
## it so far; whatever happens to that sinking, the match after draws a seed of its own,
## so a blank seed is never played twice. It is drawn on the ship the menu picks, at the
## pace it picks (Fast sinking).

var _rules: MatchRules
var _args: MatchArgs
var _seeds: RandomNumberGenerator
var _config: MatchConfig
## The ship of the Fleet the menu picks, by name: --ship's, else the data's.
var _ship: StringName
## Whether it sinks on the data's fast_clock: the menu's Fast sinking, --fast's at first.
var _fast: bool


func _init(match_rules: MatchRules, args: MatchArgs, seeds: RandomNumberGenerator) -> void:
	_rules = match_rules
	_args = args
	_seeds = seeds
	_ship = args.ship() if not args.ship().is_empty() else Fleet.name_of(match_rules.ship)
	_fast = args.fast


## Draws the next match on [param ship_name] of the Fleet: one drawn ahead on another
## ship is dropped, its sinking with it.
func aim(ship_name: StringName) -> void:
	if ship_name == _ship:
		return
	_ship = ship_name
	_config = null


## Draws the next match fast when [param fast]: one drawn ahead at the other pace is
## dropped, its sinking with it.
func pace(fast: bool) -> void:
	if fast == _fast:
		return
	_fast = fast
	_config = null


## The next blank-seed match, its seed drawn now if it was not yet.
func config() -> MatchConfig:
	if _config == null:
		_config = MatchConfig.from_rules(_rules, _seeds.randi(), 0, _ship, _fast)
		_config.scenario = _args.struck(_config.scenario, _clock())
	return _config


## The match the menu's choices make (MatchConfig.from_menu), struck by --hit and fast
## when [param fast]; a blank [param seed_text] is the next match's seed, and its
## scenario that match's own. Null when from_menu's is.
func chosen(seats: int, tier: StringName, seed_text: String, fast := false) -> MatchConfig:
	pace(fast)
	var typed := seed_text.strip_edges()
	var next: MatchConfig = config() if typed.is_empty() else null
	if next != null:
		typed = str(next.match_seed)
	var made := MatchConfig.from_menu(_rules, seats, tier, typed, _seeds, _ship, _fast)
	if made != null:
		made.scenario = next.scenario if next != null else _args.struck(made.scenario, _clock())
	return made


## [param played] starts: when it plays the next match's seed it takes that match's
## sinking, made or under way, and the next match draws a new seed.
func take(played: MatchConfig) -> void:
	if _config == null or played.match_seed != _config.match_seed:
		return
	played.share_sinking(_config)
	_config = null


## The clock --scenario's and --hit's sinking is struck on: the data's fast one for a
## fast match, else 0 — her own.
func _clock() -> float:
	return _rules.fast_clock if _fast else 0.0
