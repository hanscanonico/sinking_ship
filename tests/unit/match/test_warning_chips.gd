extends GutTest
## What the sinking's chips say (WarningChips): a lurch's tells the player to brace, by
## its key, only where there is a key to press — a watcher, a seat out of the match and a
## replay's viewer read the lurch alone.


func test_a_lurch_names_the_brace_key_only_for_who_may_brace() -> void:
	assert_eq(WarningChips.lurch_words(1.0, "Shift"), "LURCH TO STARBOARD — BRACE (Shift)")
	assert_eq(WarningChips.lurch_words(-1.0, "Shift"), "LURCH TO PORT — BRACE (Shift)")
	assert_eq(WarningChips.lurch_words(1.0, ""), "LURCH TO STARBOARD")
	assert_eq(WarningChips.lurch_words(-1.0, ""), "LURCH TO PORT")


## The lurch alone is the catalog's line up to its dash, in every language: no key, no
## brackets left open, and each side its own words.
func test_the_lurch_alone_reads_whole_in_every_language() -> void:
	for language: String in Language.locales():
		Language.use(language)
		var sides := PackedStringArray()
		for side: float in [1.0, -1.0]:
			var alone := WarningChips.lurch_words(side, "")
			assert_false(alone.is_empty(), language)
			for mark: String in ["%s", "(", "—"]:
				assert_false(alone.contains(mark), "%s: %s" % [language, alone])
			assert_true(WarningChips.lurch_words(side, "Shift").begins_with(alone + " — "))
			sides.append(alone)
		assert_ne(sides[0], sides[1], language)
	Language.use(Language.SOURCE)


## A lurch telegraphed is one chip, with the key or without it, as the pose has it.
func test_the_chips_of_a_pose_say_its_lurch() -> void:
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	assert_eq(WarningChips.words(pose, 0, "Shift"), PackedStringArray())
	pose.lurch_warning = -1.0
	assert_eq(WarningChips.words(pose, 0, ""), PackedStringArray(["LURCH TO PORT"]))
	assert_eq(
		WarningChips.words(pose, 0, "Shift"), PackedStringArray(["LURCH TO PORT — BRACE (Shift)"])
	)
