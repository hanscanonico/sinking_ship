extends GutTest
## The beds follow the water and the ship (D7): the sea swells and brightens as it
## nears, the wind blows harder higher up, the rush follows the sinking's pace, and
## a room — below deck or in the deckhouse — muffles the outside and rings with its
## own reverb; the sea over the ears muffles it more.


func test_the_sea_swells_and_brightens_as_it_nears() -> void:
	assert_gt(AmbienceMix.sea_db(0.5), AmbienceMix.sea_db(6.0))
	assert_gt(AmbienceMix.sea_cutoff_hz(0.5), AmbienceMix.sea_cutoff_hz(6.0))
	assert_almost_eq(AmbienceMix.sea_db(-1.0), AmbienceMix.SEA_NEAR_DB, 0.0001, "held at the water")
	assert_almost_eq(AmbienceMix.sea_db(100.0), AmbienceMix.SEA_FAR_DB, 0.0001, "and far above")


func test_the_wind_blows_harder_higher_and_drops_indoors() -> void:
	assert_gt(AmbienceMix.wind_db(10.0, 0.0), AmbienceMix.wind_db(1.0, 0.0))
	assert_lt(AmbienceMix.wind_db(10.0, 1.0), AmbienceMix.wind_db(10.0, 0.0))


func test_the_rush_follows_the_sinking() -> void:
	assert_almost_eq(AmbienceMix.rush_db(0.0, 2.0), AmbienceMix.SILENT_DB, 0.0001, "a still ship")
	assert_gt(AmbienceMix.rush_db(0.1, 2.0), AmbienceMix.rush_db(0.02, 2.0))
	assert_almost_eq(AmbienceMix.rush_db(1.0, 0.0), AmbienceMix.RUSH_DB, 0.0001, "the plunge")
	assert_lt(AmbienceMix.rush_db(1.0, 14.0), AmbienceMix.rush_db(1.0, 0.0), "fainter up high")


func test_a_room_muffles_the_outside_and_rings() -> void:
	assert_almost_eq(AmbienceMix.outside_cutoff_hz(0.0), AmbienceMix.OPEN_HZ, 0.01)
	assert_almost_eq(AmbienceMix.outside_cutoff_hz(1.0), AmbienceMix.ENCLOSED_HZ, 0.01)
	assert_eq(AmbienceMix.reverb_wet(0.0), 0.0, "no reverb on open deck")
	assert_gt(AmbienceMix.reverb_wet(1.0), 0.0)


func test_under_the_sea_the_outside_is_muffled_and_the_wind_drops() -> void:
	assert_lt(AmbienceMix.outside_cutoff_hz(0.0, true), AmbienceMix.ENCLOSED_HZ, "past a room's")
	assert_lt(AmbienceMix.wind_db(-1.0, 0.0, true), AmbienceMix.wind_db(-1.0, 1.0), "past a room's")


func test_feet_in_a_room_are_enclosed_and_open_deck_is_not() -> void:
	var steamer := SimFixtures.steamer()
	var step := SimFixtures.rules().step_height
	assert_eq(AmbienceMix.enclosure(steamer, Vector3(8.0, -2.6, -2.0), step), 1.0, "the hold")
	assert_eq(AmbienceMix.enclosure(steamer, Vector3(-1.5, 0.0, 0.0), step), 1.0, "deckhouse")
	assert_eq(
		AmbienceMix.enclosure(steamer, Vector3(-10.0, 0.0, 4.0), step),
		0.0,
		"open deck, over the cabins below"
	)
	assert_eq(AmbienceMix.enclosure(steamer, Vector3(1.5, 2.5, 2.5), step), 0.0, "on the boat deck")


func test_every_cue_kind_has_sounds_to_play() -> void:
	var bank := SoundBank.new()
	for kind: AudioCue.Kind in AudioCue.Kind.values():
		var named: String = AudioCue.Kind.keys()[kind]
		assert_true(SoundBank.CARRY.has(kind), "%s carries" % named)
		for ground: AudioCue.Ground in AudioCue.Ground.values():
			var picks := bank.stream(kind, ground) as AudioStreamRandomizer
			assert_gt(picks.streams_count, 0, "%s has files" % named)
			for index in picks.streams_count:
				assert_not_null(picks.get_stream(index), "%s's file %d loads" % [named, index])
