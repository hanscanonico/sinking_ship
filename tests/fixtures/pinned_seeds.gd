class_name PinnedSeeds
extends Resource
## Our ships' pinned seeds (§5b.4), by name — the steamer's, from SH30 the trawler's
## open_hatch, from SH31 the steamer's door_gives_way, funnel_on_the_bridge and
## lights_out_early, from SH32 the steamer's capsize_upside_down and on_her_side (on her
## coast) and the trawler's capsize_inverted: a seed whose match hit on her — after the
## must-sink rule — sits far from every threshold, re-baked with its hole's area × 0.9
## and × 1.1 to the same outcome, so a Mac and Linux agree on it.

const PATH := "res://tests/fixtures/pinned_seeds.tres"

@export var seeds: Dictionary[StringName, int] = {}


static func seed_named(seed_name: StringName) -> int:
	return (load(PATH) as PinnedSeeds).seeds[seed_name]
