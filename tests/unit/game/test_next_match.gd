extends GutTest
## A Play with a blank seed takes the next match the menu drew ahead, and the sinking
## baked of it so far; the match after draws a seed of its own, so a blank seed is never
## played twice — under --hit, and before the menu baked anything, too.

const MATCH_DATA := "res://data/match/default.tres"
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"


func _next_match(arguments: PackedStringArray) -> NextMatch:
	var seeds := RandomNumberGenerator.new()
	seeds.seed = 1701
	return NextMatch.new(load(MATCH_DATA), MatchArgs.parse(arguments), seeds)


## Plays a blank seed from [param next] and returns the match it played.
func _play_blank(next: NextMatch) -> MatchConfig:
	var rules: MatchRules = load(MATCH_DATA)
	var played := next.chosen(rules.seats, rules.bot_tier, "")
	next.take(played)
	return played


func test_blank_seeds_under_a_hit_are_never_played_twice() -> void:
	var next := _next_match(PackedStringArray(["--hit=" + FAST_HIT]))
	next.config().bake_some(1)
	var first := _play_blank(next)
	var second := _play_blank(next)
	assert_ne(first.match_seed, second.match_seed)


func test_blank_seeds_played_before_any_bake_are_never_played_twice() -> void:
	var next := _next_match(PackedStringArray())
	var first := _play_blank(next)
	var second := _play_blank(next)
	assert_ne(first.match_seed, second.match_seed)


func test_a_blank_seed_under_a_hit_takes_the_sinking_baked_on_the_menu() -> void:
	var next := _next_match(PackedStringArray(["--hit=" + FAST_HIT]))
	var ahead := next.config()
	ahead.bake_some(1)
	var played := _play_blank(next)
	assert_eq(played.match_seed, ahead.match_seed)
	assert_eq(played.scenario.explicit_hit, load(FAST_HIT))
	assert_eq(played.bake_steps(), 1)


func test_a_typed_seed_leaves_the_next_match_drawn() -> void:
	var next := _next_match(PackedStringArray())
	var ahead := next.config()
	var rules: MatchRules = load(MATCH_DATA)
	var typed := str(ahead.match_seed + 1)
	var played := next.chosen(rules.seats, rules.bot_tier, typed)
	next.take(played)
	assert_eq(played.match_seed, ahead.match_seed + 1)
	assert_eq(next.config(), ahead)
