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


## Every name problems() checks the range of is a knob's: a misspelt one would read as
## 0 through get() and pass every range.
func test_every_checked_name_is_a_knob() -> void:
	var knobs := PackedStringArray()
	for property: Dictionary in BotProfile.new().get_property_list():
		knobs.append(property["name"])
	for field: String in BotProfile.SHARES + BotProfile.NON_NEGATIVE:
		assert_has(knobs, field, "%s is a knob" % field)


## Each knob out of its range is named, alone.
func test_each_knob_out_of_range_is_named() -> void:
	var normal := BotProfile.for_tier(&"normal")
	for field: String in BotProfile.SHARES:
		for wrong: float in [-0.1, 1.1]:
			var broken: BotProfile = normal.duplicate()
			broken.set(field, wrong)
			assert_eq(
				broken.problems(),
				PackedStringArray(["bot: %s must be within 0…1" % field]),
				"%s at %s" % [field, wrong]
			)
	for field: String in BotProfile.NON_NEGATIVE:
		var broken: BotProfile = normal.duplicate()
		broken.set(field, -0.1)
		assert_eq(
			broken.problems(),
			PackedStringArray(["bot: %s must not be negative" % field]),
			"%s at -0.1" % field
		)
	var lonely: BotProfile = normal.duplicate()
	lonely.crowd_seats = 0
	assert_eq(lonely.problems(), PackedStringArray(["bot: crowd_seats must be at least 1"]))
	var eager: BotProfile = normal.duplicate()
	eager.hunt_at_seats = -1
	assert_eq(eager.problems(), PackedStringArray(["bot: hunt_at_seats must not be negative"]))


## The refuge reads what the bot has seen over a window of its own, and marks a zone
## down by the water it saw rise there (BotRefuge): neither is ever nothing.
func test_the_refuge_reads_a_window_of_what_was_seen() -> void:
	for tier: String in BotProfile.tiers():
		var profile := BotProfile.for_tier(StringName(tier))
		assert_gt(profile.refuge_window_s, 0.0, "%s: a window to compare across" % tier)
		assert_gt(profile.refuge_rise_s, 0.0, "%s: a rise seen counts" % tier)


## A bot spars only while the ship is level: its whole spar margin with every deck dry,
## less as they go under, none once spar_until of them are — and none at all for a
## spar_until of nothing.
func test_the_spar_margin_fades_as_the_ship_goes_under() -> void:
	for tier: String in BotProfile.tiers():
		var profile := BotProfile.for_tier(StringName(tier))
		var full := profile.spar_margin_m
		var until := profile.spar_until
		assert_gt(until, 0.0, "%s: it spars until some of the ship is under" % tier)
		assert_eq(profile.spar_margin(0.0, 0.0), full, "%s: dry, the whole margin" % tier)
		assert_almost_eq(profile.spar_margin(until * 0.5, 0.0), full * 0.5, 1e-9, tier)
		assert_eq(profile.spar_margin(until, 0.0), 0.0, "%s: from spar_until, none" % tier)
		assert_eq(profile.spar_margin(1.0, 0.0), 0.0, tier)
	var never: BotProfile = BotProfile.for_tier(&"normal").duplicate()
	never.spar_until = 0.0
	assert_eq(never.spar_margin(0.0, 0.0), 0.0, "spar_until 0: it never spars")


## A bot spars only while the match is young too: its whole margin as it goes live,
## half of it halfway through spar_for_s, none from spar_for_s on with nothing flooded
## — and the nearer of the two fades counts.
func test_the_spar_margin_fades_as_the_match_goes_on() -> void:
	for tier: String in BotProfile.tiers():
		var profile := BotProfile.for_tier(StringName(tier))
		var full := profile.spar_margin_m
		var spar_for := profile.spar_for_s
		assert_gt(spar_for, 0.0, "%s: it spars for a while from going live" % tier)
		assert_almost_eq(profile.spar_margin(0.0, spar_for * 0.5), full * 0.5, 1e-9, tier)
		assert_eq(profile.spar_margin(0.0, spar_for), 0.0, "%s: from spar_for_s, none" % tier)
		assert_eq(profile.spar_margin(0.0, spar_for * 4.0), 0.0, tier)
		var under := profile.spar_until * 0.25
		assert_almost_eq(
			profile.spar_margin(under, spar_for * 0.5), full * 0.5, 1e-9, "%s: the nearer" % tier
		)
		assert_almost_eq(
			profile.spar_margin(profile.spar_until * 0.75, spar_for * 0.5), full * 0.25, 1e-9, tier
		)
		assert_gte(profile.hunt_at_seats, 2, "%s: the last two hunt each other" % tier)
