extends GutTest
## Bonus kinds and bonus rules (#307, #310) are data — data/bonuses/NAME.tres, and
## data/rules/bonuses.tres, which the match data points at — checked with the match
## (MatchConfig.problems) as the kinds of her props are: a kind's title and size; the
## rules' kinds and their odds, their times and the most aboard at once.

const DEFAULT_MATCH := "res://data/match/default.tres"
const SURVIVAL_MATCH := "res://data/match/survival.tres"
const BONUS_RULES := "res://data/rules/bonuses.tres"


## The default match, and the survival one: bonuses are on in both goals, on the default
## bonus rules — Double life alone for now, the first 20 s in, then every 45 s ± 15 s, at
## most two aboard: estimates, to tune after a playtest — and the command line's match
## plays them as the data does.
func test_the_match_data_plays_double_life_on_the_default_bonus_rules() -> void:
	var rules: BonusRules = load(BONUS_RULES)
	for match_rules: MatchRules in [load(DEFAULT_MATCH), load(SURVIVAL_MATCH)]:
		var config := MatchConfig.from_rules(match_rules, 1701)
		var path := match_rules.resource_path
		assert_eq(config.bonus_rules, rules, "%s points at the bonus rules" % path)
		assert_eq(config.problems(), PackedStringArray(), path)
	var chosen := MatchArgs.parse(PackedStringArray()).choices.with_seed("7")
	assert_eq(chosen.config(load(DEFAULT_MATCH)).bonus_rules, rules, "the command line's match too")
	assert_eq(rules.kinds.size(), 1, "one kind so far")
	assert_eq(rules.odds, PackedFloat64Array([1.0]))
	assert_eq([rules.first, rules.interval, rules.jitter, rules.most_aboard], [20.0, 45.0, 15.0, 2])
	var kind: BonusKind = rules.kinds[0]
	assert_eq(kind, SimFixtures.double_life())
	assert_eq(kind.title, "Double life")
	assert_true(kind.spare_meter, "a spare cold meter")
	assert_gt(kind.radius, 0.0, "a size its model stays inside")
	assert_gt(kind.height, 0.0)


## Every way the bonus rules or a kind of theirs cannot be played is a problem of the match.
func test_a_match_is_checked_for_its_bonus_rules_and_kinds() -> void:
	var breaks := {
		"no title": func(rules: BonusRules) -> void: rules.kinds[0].title = " ",
		"no size": func(rules: BonusRules) -> void: rules.kinds[0].radius = 0.0,
		"no height": func(rules: BonusRules) -> void: rules.kinds[0].height = -0.1,
		"a kind missing": func(rules: BonusRules) -> void: rules.kinds[0] = null,
		"no kinds": func(rules: BonusRules) -> void: rules.kinds.clear(),
		"odds for none": func(rules: BonusRules) -> void: rules.odds.append(1.0),
		"odds of nothing": func(rules: BonusRules) -> void: rules.odds[0] = 0.0,
		"negative odds": func(rules: BonusRules) -> void: rules.odds[0] = -1.0,
		"before the start": func(rules: BonusRules) -> void: rules.first = -1.0,
		"no interval": func(rules: BonusRules) -> void: rules.interval = 0.0,
		"jitter past it": func(rules: BonusRules) -> void: rules.jitter = rules.interval,
		"negative jitter": func(rules: BonusRules) -> void: rules.jitter = -1.0,
		"none aboard": func(rules: BonusRules) -> void: rules.most_aboard = 0,
	}
	for what: String in breaks:
		var config := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
		var rules: BonusRules = config.bonus_rules.duplicate()
		var kinds: Array[BonusKind] = [SimFixtures.double_life().duplicate()]
		rules.kinds = kinds
		rules.odds = rules.odds.duplicate()
		(breaks[what] as Callable).call(rules)
		config.bonus_rules = rules
		assert_false(config.problems().is_empty(), what)
	var off := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
	off.bonus_rules = null
	assert_eq(off.problems(), PackedStringArray(), "a match without bonuses has none to check")


## The bonus rules and their kinds are the match's data (D4): a log recorded with bonuses
## refuses to play against other bonus numbers, or none; and a match without bonuses
## hashes as one did before they came.
func test_the_bonus_rules_and_their_kinds_are_in_the_data_hash() -> void:
	var config := SimFixtures.config(1, null, 1701, SimFixtures.below_decks())
	var without := config.data_hash()
	var rules := SimFixtures.bonus_rules()
	config.bonus_rules = rules
	var with := config.data_hash()
	assert_ne(with, without, "bonuses or none")
	rules.interval += 1.0
	assert_ne(config.data_hash(), with, "the rules' numbers")
	rules.interval -= 1.0
	assert_eq(config.data_hash(), with, "and its own again")
	var kind := SimFixtures.double_life()
	kind.radius += 0.1
	var bigger := config.data_hash()
	kind.radius -= 0.1
	assert_ne(bigger, with, "a kind's numbers")
	config.bonus_rules = null
	assert_eq(config.data_hash(), without, "none: as before bonuses came")
