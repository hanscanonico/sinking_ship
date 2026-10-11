extends GutTest
## A Play with a blank seed takes the next match the menu drew ahead, and the sinking
## baked of it so far; the match after draws a seed of its own, so a blank seed is never
## played twice — under --hit, and before the menu baked anything, too. It is drawn on
## the choices that shape her sinking — ship, scenario, hit and pace — and kept while
## only the others change.

const MATCH_DATA := "res://data/match/default.tres"
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"


## The next match on the menu's choices as [param arguments] set it up.
func _next_match(arguments: PackedStringArray) -> NextMatch:
	var seeds := RandomNumberGenerator.new()
	seeds.seed = 1701
	var next := NextMatch.new(load(MATCH_DATA), seeds)
	next.aim(_choices(arguments))
	return next


## The menu's choices as [param arguments] set it up, its seed [param seed_text].
func _choices(arguments: PackedStringArray, seed_text := "") -> MatchChoices:
	return MatchArgs.parse(arguments).choices.filled(load(MATCH_DATA)).with_seed(seed_text)


## Plays [param choices] from [param next] and returns the match it played.
func _play(next: NextMatch, choices: MatchChoices) -> MatchConfig:
	var played := next.chosen(choices)
	next.take(played)
	return played


func test_blank_seeds_under_a_hit_are_never_played_twice() -> void:
	var arguments := PackedStringArray(["--hit=" + FAST_HIT])
	var next := _next_match(arguments)
	next.config().bake_some(1)
	var first := _play(next, _choices(arguments))
	var second := _play(next, _choices(arguments))
	assert_ne(first.match_seed, second.match_seed)


func test_blank_seeds_played_before_any_bake_are_never_played_twice() -> void:
	var next := _next_match(PackedStringArray())
	var first := _play(next, _choices(PackedStringArray()))
	var second := _play(next, _choices(PackedStringArray()))
	assert_ne(first.match_seed, second.match_seed)


func test_a_blank_seed_under_a_hit_takes_the_sinking_baked_on_the_menu() -> void:
	var arguments := PackedStringArray(["--hit=" + FAST_HIT])
	var next := _next_match(arguments)
	var ahead := next.config()
	ahead.bake_some(1)
	var played := _play(next, _choices(arguments))
	assert_eq(played.match_seed, ahead.match_seed)
	assert_eq(played.scenario.explicit_hit, load(FAST_HIT))
	assert_eq(played.bake_steps(), 1)


func test_a_typed_seed_leaves_the_next_match_drawn() -> void:
	var next := _next_match(PackedStringArray())
	var ahead := next.config()
	var played := _play(next, _choices(PackedStringArray(), str(ahead.match_seed + 1)))
	assert_eq(played.match_seed, ahead.match_seed + 1)
	assert_eq(next.config(), ahead)


func test_a_drawn_seed_typed_back_in_plays_the_same_match() -> void:
	var next := _next_match(PackedStringArray())
	var drawn := _play(next, _choices(PackedStringArray()))
	var typed := _play(next, _choices(PackedStringArray(), str(drawn.match_seed)))
	assert_eq(typed.match_seed, drawn.match_seed, "the drawn seed is recorded")
	assert_eq(typed.data_hash(), drawn.data_hash())


func test_the_next_match_goes_on_the_ship_the_menu_picks() -> void:
	var next := _next_match(PackedStringArray())
	var steamer := next.config()
	assert_eq(Fleet.name_of(steamer.ship), &"steamer", "the match data's ship to start with")
	var on_trawler := _choices(PackedStringArray(["--ship=trawler"]))
	next.aim(on_trawler)
	var trawler := next.config()
	assert_ne(trawler, steamer, "the one drawn on the steamer is dropped")
	assert_eq(Fleet.name_of(trawler.ship), &"trawler")
	var played := next.chosen(on_trawler)
	assert_eq(played.match_seed, trawler.match_seed, "a blank seed plays the one drawn ahead")
	assert_eq(played.ship, trawler.ship)
	assert_eq(played.scenario, trawler.scenario)
	next.aim(on_trawler)
	assert_eq(next.config(), trawler, "picking her again keeps her match")


func test_a_ship_named_at_launch_is_the_next_match_s() -> void:
	var next := _next_match(PackedStringArray(["--ship=trawler"]))
	assert_eq(Fleet.name_of(next.config().ship), &"trawler")


func test_another_pace_drops_the_drawn_match_and_a_hit_stays() -> void:
	var arguments := PackedStringArray(["--hit=" + FAST_HIT])
	var next := _next_match(arguments)
	var drawn := next.config()
	var fast := _choices(arguments)
	fast.fast = true
	var played := next.chosen(fast)
	assert_ne(played.match_seed, drawn.match_seed, "the normal one drawn ahead is dropped")
	assert_eq(played.scenario.clock, (load(MATCH_DATA) as MatchRules).fast_clock)
	assert_eq(played.scenario.explicit_hit, load(FAST_HIT), "struck by --hit still")


func test_seats_tier_and_goal_keep_the_drawn_match() -> void:
	var next := _next_match(PackedStringArray())
	var drawn := next.config()
	var other := _choices(PackedStringArray(["--seats=3", "--goal=survival"]))
	other.bot_tier = &"hard"
	var played := next.chosen(other)
	assert_eq(played.match_seed, drawn.match_seed, "none of them shapes her sinking")
	assert_eq(played.seats, 3)
	assert_eq(played.goal, MatchRules.Goal.SURVIVAL)
	assert_eq(played.bot_tier, &"hard")
