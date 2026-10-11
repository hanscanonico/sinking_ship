class_name NextMatch
extends RefCounted
## The next blank-seed match the menu plays: its seed drawn ahead on the choices that
## shape her sinking — ship, scenario, hit and pace —, so the sinking can be baked while
## the menu or the results show (R20). A Play with a blank seed takes it, and the
## sinking made of it so far; whatever happens to that sinking, the match after draws a
## seed of its own, so a blank seed is never played twice. Every config it holds or hands
## out is the match choices' own (MatchChoices.config): this is only the bake-ahead cache.

var _rules: MatchRules
var _seeds: RandomNumberGenerator
## The choices the next match is drawn on, their seed blank.
var _choices := MatchChoices.new()
var _config: MatchConfig


func _init(match_rules: MatchRules, seeds: RandomNumberGenerator) -> void:
	_rules = match_rules
	_seeds = seeds


## Draws the next match on [param choices]: one drawn ahead on choices that shape another
## sinking — another ship, scenario, hit or pace — is dropped, its sinking with it.
func aim(choices: MatchChoices) -> void:
	var kept := _config != null and choices.sinks_alike(_choices, _rules)
	_choices = choices.with_seed("")
	if not kept:
		_config = null


## The next blank-seed match, its seed drawn now if it was not yet; null while the
## choices it is drawn on make no match (MatchChoices.problems).
func config() -> MatchConfig:
	if _config == null and _choices.problems(_rules).is_empty():
		_config = _choices.with_seed(str(_seeds.randi())).config(_rules)
	return _config


## The match [param choices] make, free of problems (MatchChoices.problems): a blank
## seed is the next match's seed, drawn on them, and its sinking that match's own.
func chosen(choices: MatchChoices) -> MatchConfig:
	aim(choices)
	if not choices.seed_text.strip_edges().is_empty():
		return choices.config(_rules)
	var next := config()
	var made := choices.with_seed(str(next.match_seed)).config(_rules)
	made.scenario = next.scenario
	return made


## [param played] starts: when it plays the next match's seed it takes that match's
## sinking, made or under way, and the next match draws a new seed.
func take(played: MatchConfig) -> void:
	if _config == null or played.match_seed != _config.match_seed:
		return
	played.share_sinking(_config)
	_config = null
