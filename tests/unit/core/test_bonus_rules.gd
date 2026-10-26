extends GutTest
## Bonus kinds and bonus rules (#307, #310, #316) are data — data/bonuses/NAME.tres, and
## data/rules/bonuses.tres, which the match data points at — checked with the match
## (MatchConfig.problems) as the kinds of her props are: a kind's title and size, and what
## it gives beside the brawl rules; the rules' kinds and their odds, their times and the
## most aboard at once.

const DEFAULT_MATCH := "res://data/match/default.tres"
const SURVIVAL_MATCH := "res://data/match/survival.tres"
const BONUS_RULES := "res://data/rules/bonuses.tres"
## How far apart, in RGB, any two kinds' marks stand: far enough to read apart in a fight.
const MARKS_APART := 0.3


## The default match, and the survival one: bonuses are on in both goals, on the default
## bonus rules — Double life, High jump, Steady and Strong arms, every one as likely, the
## first 20 s in, then every 45 s ± 15 s, at most two aboard: estimates, to tune after a
## playtest — and the command line's match plays them as the data does.
func test_the_match_data_plays_four_kinds_on_the_default_bonus_rules() -> void:
	var rules: BonusRules = load(BONUS_RULES)
	for match_rules: MatchRules in [load(DEFAULT_MATCH), load(SURVIVAL_MATCH)]:
		var config := MatchConfig.from_rules(match_rules, 1701)
		var path := match_rules.resource_path
		assert_eq(config.bonus_rules, rules, "%s points at the bonus rules" % path)
		assert_eq(config.problems(), PackedStringArray(), path)
	var chosen := MatchArgs.parse(PackedStringArray()).choices.with_seed("7")
	assert_eq(chosen.config(load(DEFAULT_MATCH)).bonus_rules, rules, "the command line's match too")
	var titles: Array[String] = []
	for kind: BonusKind in rules.kinds:
		titles.append(kind.title)
	assert_eq(titles, ["Double life", "High jump", "Steady", "Strong arms"])
	assert_eq(rules.odds, PackedFloat64Array([1.0, 1.0, 1.0, 1.0]), "every one as likely")
	assert_eq([rules.first, rules.interval, rules.jitter, rules.most_aboard], [20.0, 45.0, 15.0, 2])
	assert_eq(rules.kinds[0], SimFixtures.double_life())
	for kind: BonusKind in rules.kinds:
		assert_gt(kind.radius, 0.0, "%s: a size its model stays inside" % kind.title)
		assert_gt(kind.height, 0.0, kind.title)


## What each kind gives its taker, and nothing more (est.): Double life a spare cold meter;
## High jump a 1.5 m jump; Steady three quarters of a shove's knockback; Strong arms a 1.2 m
## reach out of the sea and ladders at 1.5 times the pace. A field a kind leaves unset — a
## jump or a reach of 0, a share or a ladder's pace of 1 — leaves that rule the brawl
## rules'.
func test_each_kind_gives_its_own_edge_and_leaves_the_rest_as_it_is() -> void:
	var rules: BonusRules = load(BONUS_RULES)
	var gives := {}
	for kind: BonusKind in rules.kinds:
		gives[kind.title] = [
			kind.spare_meter,
			kind.jump_height,
			kind.knockback_share,
			kind.climb_reach,
			kind.ladder_speed_mult,
		]
	assert_eq(gives["Double life"], [true, 0.0, 1.0, 0.0, 1.0])
	assert_eq(gives["High jump"], [false, 1.5, 1.0, 0.0, 1.0])
	assert_eq(gives["Steady"], [false, 0.0, 0.75, 0.0, 1.0])
	assert_eq(gives["Strong arms"], [false, 0.0, 1.0, 1.2, 1.5])


## Every brawler with a bonus wears its kind's mark (#313): each kind's colour stands apart
## from every other's, so a fight reads who has what.
func test_every_kind_is_marked_in_a_colour_of_its_own() -> void:
	var kinds: Array[BonusKind] = (load(BONUS_RULES) as BonusRules).kinds
	for one in kinds.size():
		for other in range(one + 1, kinds.size()):
			var a := kinds[one].mark
			var b := kinds[other].mark
			var apart := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			assert_gt(apart, MARKS_APART, "%s and %s" % [kinds[one].title, kinds[other].title])


## Every way the bonus rules or a kind of theirs cannot be played is a problem of the match:
## among them, a kind giving a shove share outside 0…1, a jump or a climb reach under 0, a
## ladder at no pace, or a climb reach lower than the brawl rules' own.
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
		"a share past whole": func(rules: BonusRules) -> void: rules.kinds[0].knockback_share = 1.5,
		"a negative share": func(rules: BonusRules) -> void: rules.kinds[0].knockback_share = -0.1,
		"a negative jump": func(rules: BonusRules) -> void: rules.kinds[0].jump_height = -1.0,
		"a negative reach": func(rules: BonusRules) -> void: rules.kinds[0].climb_reach = -0.5,
		"no ladder pace": func(rules: BonusRules) -> void: rules.kinds[0].ladder_speed_mult = 0.0,
		"a reach under theirs": func(rules: BonusRules) -> void: rules.kinds[0].climb_reach = 0.5,
	}
	for what: String in breaks:
		var config := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
		var rules: BonusRules = config.bonus_rules.duplicate()
		var kinds: Array[BonusKind] = [SimFixtures.double_life().duplicate()]
		rules.kinds = kinds
		rules.odds = PackedFloat64Array([1.0])
		config.bonus_rules = rules
		assert_eq(config.problems(), PackedStringArray(), "%s: whole before it" % what)
		(breaks[what] as Callable).call(rules)
		assert_false(config.problems().is_empty(), what)
	var off := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
	off.bonus_rules = null
	assert_eq(off.problems(), PackedStringArray(), "a match without bonuses has none to check")


## No speed a kind gives — a jump's take-off, a ladder's climb — may reach the fastest the
## rules move anything across her deck (BrawlRules.fastest_speed: a full charge's knockback,
## as shipped), which the online prediction leans on (ContactWatch). A 2.5 m jump leaves a
## level deck at 10.3 m/s and a ladder at 7 times the pace climbs at 10.5, both under a
## full charge's 11; a 3 m jump, at 11.3, and a ladder at 8 times the pace, at 12, are
## refused.
func test_no_speed_a_kind_gives_reaches_the_fastest_the_rules_move_anything() -> void:
	var config := MatchConfig.from_rules(load(DEFAULT_MATCH), 1701)
	assert_eq(config.rules.fastest_speed(), config.rules.charged_knockback, "a full charge's")
	for case: Array in [[2.5, 1.0, true], [3.0, 1.0, false], [0.0, 7.0, true], [0.0, 8.0, false]]:
		var kind := SimFixtures.plain_kind()
		kind.jump_height = case[0]
		kind.ladder_speed_mult = case[1]
		var kinds: Array[BonusKind] = [kind]
		config.bonus_rules = SimFixtures.bonus_rules(1.0, 45.0, 0.0, 2, kinds)
		var what := "a %.1f m jump, ladders at %.0f times the pace" % [case[0], case[1]]
		assert_eq(config.problems().is_empty(), case[2], what)


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
