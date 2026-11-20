extends GutTest
## `make sim-bench` and `make net-bench` play the match the command line chooses, as
## `make match` does (#343): every choice past the seed and the seats used to be dropped
## without a word, so BONUSES=0, SHIP= or FAST=1 benched the default match.

const RunMatch := preload("res://tools/run_match.gd")
const SimBench := preload("res://tools/sim_bench.gd")
const NetBench := preload("res://tools/net_bench.gd")

const TRAWLER := "res://data/ships/trawler.tres"
const FLAGS := ["--seed=7", "--seats=4", "--ship=trawler", "--goal=survival", "--bonuses=0"]


func _args(flags: Array) -> MatchArgs:
	return MatchArgs.parse(PackedStringArray(flags))


func _expect_chosen(config: MatchConfig, bench: String) -> void:
	assert_not_null(config, bench)
	if config == null:
		return
	assert_eq(config.match_seed, 7, bench + ": the seed")
	assert_eq(config.seats, 4, bench + ": the seats")
	assert_eq(config.ship.resource_path, TRAWLER, bench + ": the ship")
	assert_eq(config.goal, MatchRules.Goal.SURVIVAL, bench + ": the goal")
	assert_null(config.bonus_rules, bench + ": no bonuses")


func test_sim_bench_plays_every_choice() -> void:
	_expect_chosen(SimBench.config_of(_args(FLAGS)), "sim-bench")


func test_net_bench_plays_every_choice() -> void:
	_expect_chosen(NetBench.config_of(_args(FLAGS)), "net-bench")


func test_benches_play_the_fast_clock() -> void:
	var fast := RunMatch.chosen_config(_args(["--seed=7", "--fast"]))
	var paced := RunMatch.chosen_config(_args(["--seed=7"]))
	for bench: Array in [["sim-bench", SimBench], ["net-bench", NetBench]]:
		var config: MatchConfig = bench[1].config_of(_args(["--seed=7", "--fast"]))
		assert_eq(config.data_hash(), fast.data_hash(), "%s plays her sinking fast" % bench[0])
		assert_ne(config.data_hash(), paced.data_hash(), "%s: not the paced one" % bench[0])
