class_name PinnedSeeds
extends Resource
## The steamer's pinned seeds (§5b.4), by name: a seed whose match hit — after the
## must-sink rule — sits far from every threshold, re-baked with its hole's area × 0.9
## and × 1.1 to the same outcome, so a Mac and Linux agree on it.

const PATH := "res://tests/fixtures/pinned_seeds.tres"

@export var seeds: Dictionary[StringName, int] = {}


static func seed_named(seed_name: StringName) -> int:
	return (load(PATH) as PinnedSeeds).seeds[seed_name]
