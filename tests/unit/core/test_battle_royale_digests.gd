extends GutTest
## The battle royale must not change while other goals join it (#60–#62): a fixed set of
## bots-only matches under the default data's goal, struck by the fast explicit hit,
## played to a fixed stop — seed 1 past its end — keep the digests recorded before the
## goals came. Recorded per platform, as the golden match is (R6, Goldens):
##   tests/golden/battle_royale.<os>-<arch>.txt, one "seed stop digest" line per match,
## written by `make goldens`.

const RunMatch := preload("res://tools/run_match.gd")
const FAST_HIT := "res://tests/fixtures/sinking/hits/fast.tres"
const SEATS := 8
## Seed and stop, in seconds of match time: seed 1 ends at 1:46.
const MATCHES := [[1, 120.0], [2, 30.0], [3, 30.0]]


func _digest(seed_value: int, stop: float) -> String:
	var config := RunMatch.default_config(seed_value, SEATS)
	var struck: SinkScenario = config.scenario.duplicate()
	struck.explicit_hit = load(FAST_HIT)
	config.scenario = struck
	var runner := RunMatch.bots_only(config)
	runner.run(Ticks.from_seconds(stop))
	return "%d %d %s" % [seed_value, stop, runner.digest.hex()]


func test_battle_royale_digests_are_unchanged() -> void:
	var played := PackedStringArray()
	for entry: Array in MATCHES:
		played.append(_digest(entry[0], entry[1]))
	Goldens.check(self, "battle_royale", "\n".join(played) + "\n", "battle royale digests")
