extends GutTest
## The bot tiers under data/bots/ (§7's knobs): each loads and validates, they list
## easiest first, and every knob that makes a bot better moves the same way.


func test_tiers_load_and_validate() -> void:
	var tiers := BotProfile.tiers()
	assert_eq(tiers, PackedStringArray(["easy", "normal", "hard"]), "in difficulty order")
	var profiles: Array[BotProfile] = []
	for tier: String in tiers:
		var profile := BotProfile.for_tier(StringName(tier))
		assert_not_null(profile, tier)
		if profile == null:
			return
		assert_eq(profile.problems(), PackedStringArray(), "%s validates" % tier)
		profiles.append(profile)
	var easy := profiles[0]
	var normal := profiles[1]
	var hard := profiles[2]
	# §7's table.
	assert_eq([easy.reaction_ticks, normal.reaction_ticks, hard.reaction_ticks], [12, 7, 4])
	assert_eq([easy.think_period, normal.think_period, hard.think_period], [6, 4, 2])
	for knob: String in ["aim_error_deg", "edge_margin_m", "mistake_rate"]:
		assert_gt(float(easy.get(knob)), float(normal.get(knob)), "%s: easy over normal" % knob)
		assert_gt(float(normal.get(knob)), float(hard.get(knob)), "%s: normal over hard" % knob)
	for knob: String in ["brace_read", "charge_read", "lineup_weight", "king_of_hill_bias"]:
		assert_lt(float(easy.get(knob)), float(normal.get(knob)), "%s: easy under normal" % knob)
		assert_lt(float(normal.get(knob)), float(hard.get(knob)), "%s: normal under hard" % knob)
	assert_eq(hard.mistake_rate, 0.0, "hard never lapses")
	assert_eq(
		[easy.dodges_cargo, normal.dodges_cargo, hard.dodges_cargo],
		[false, true, true],
		"normal and hard step out of a sliding crate's path; easy does not"
	)
	# Every tier perceives as a person does: the same eyes, ears and memory.
	for profile: BotProfile in profiles:
		assert_eq(
			[profile.eye_height_m, profile.hearing_m, profile.memory_seconds], [1.6, 6.0, 3.0]
		)

	# A broken profile says what is wrong with it, and an unknown tier is none.
	var broken: BotProfile = normal.duplicate()
	broken.think_period = 0
	broken.brace_read = 1.5
	broken.hearing_m = -1.0
	assert_eq(
		broken.problems(),
		PackedStringArray(
			[
				"bot: think_period must be at least 1",
				"bot: brace_read must be within 0…1",
				"bot: hearing_m must not be negative",
			]
		)
	)
	assert_null(BotProfile.for_tier(&"heroic"))
