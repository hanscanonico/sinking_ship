class_name NextMatch
extends RefCounted
## The next blank-seed match the menu plays: its seed drawn ahead, and the match struck
## by --hit as every match the game plays is, so its sinking can be baked while the menu
## or the results show (R20). A Play with a blank seed takes it, and the sinking made of
## it so far; whatever happens to that sinking, the match after draws a seed of its own,
## so a blank seed is never played twice. It is drawn on the ship the menu picks.

var _rules: MatchRules
var _args: MatchArgs
var _seeds: RandomNumberGenerator
var _config: MatchConfig
## The ship of the Fleet the menu picks, by name: --ship's, else the data's.
var _ship: StringName


func _init(match_rules: MatchRules, args: MatchArgs, seeds: RandomNumberGenerator) -> void:
	_rules = match_rules
	_args = args
	_seeds = seeds
	_ship = args.ship() if not args.ship().is_empty() else Fleet.name_of(match_rules.ship)


## Draws the next match on [param ship_name] of the Fleet: one drawn ahead on another
## ship is dropped, its sinking with it.
func aim(ship_name: StringName) -> void:
	if ship_name == _ship:
		return
	_ship = ship_name
	_config = null


## The next blank-seed match, its seed drawn now if it was not yet.
func config() -> MatchConfig:
	if _config == null:
		_config = MatchConfig.from_rules(_rules, _seeds.randi(), 0, _ship)
		_config.scenario = _args.struck(_config.scenario)
	return _config


## The match the menu's choices make (MatchConfig.from_menu), struck by --hit; a blank
## [param seed_text] is the next match's seed, and its scenario that match's own. Null
## when from_menu's is.
func chosen(seats: int, tier: StringName, seed_text: String) -> MatchConfig:
	var typed := seed_text.strip_edges()
	var next: MatchConfig = config() if typed.is_empty() else null
	if next != null:
		typed = str(next.match_seed)
	var made := MatchConfig.from_menu(_rules, seats, tier, typed, _seeds, _ship)
	if made != null:
		made.scenario = next.scenario if next != null else _args.struck(made.scenario)
	return made


## [param played] starts: when it plays the next match's seed it takes that match's
## sinking, made or under way, and the next match draws a new seed.
func take(played: MatchConfig) -> void:
	if _config == null or played.match_seed != _config.match_seed:
		return
	played.share_sinking(_config)
	_config = null
