extends GutTest
## MatchAudio looks each bus up by name once and keeps its index, and looks again as
## the bus layout changes: what it finds is always the bus of that name.


func test_a_bus_kept_is_found_again_once_the_layout_changes() -> void:
	var audio: MatchAudio = autofree(MatchAudio.new())
	var sea := AudioServer.get_bus_index(&"Sea")
	assert_ne(sea, -1, "the layout has a sea bus")
	assert_eq(audio._bus(&"Sea"), sea)
	AudioServer.add_bus(1)
	assert_eq(audio._bus(&"Sea"), sea + 1, "a bus put in before it")
	AudioServer.remove_bus(1)
	assert_eq(audio._bus(&"Sea"), sea, "and taken out again")


func test_a_bus_the_layout_lacks_is_none() -> void:
	var audio: MatchAudio = autofree(MatchAudio.new())
	assert_eq(audio._bus(&"NoSuchBus"), -1)
	assert_null(audio._filter(&"NoSuchBus"))


func test_the_room_s_buses_are_set_again_only_as_they_change() -> void:
	var audio: MatchAudio = autofree(MatchAudio.new())
	var room := AudioServer.get_bus_index(SoundBank.ROOM_BUS)
	assert_ne(room, -1, "the layout has a room bus")
	var reverb := AudioServer.get_bus_effect(room, 0) as AudioEffectReverb
	audio._set_enclosure(1.0, false, 0.016)
	assert_almost_eq(reverb.wet, AmbienceMix.reverb_wet(1.0), 0.0001, "enclosed")
	reverb.wet = 0.0
	audio._set_enclosure(1.0, false, 0.016)
	assert_eq(reverb.wet, 0.0, "as enclosed again: not set again")
	AudioServer.add_bus(1)
	AudioServer.remove_bus(1)
	audio._set_enclosure(1.0, false, 0.016)
	assert_almost_eq(
		reverb.wet, AmbienceMix.reverb_wet(1.0), 0.0001, "the layout changed: set again"
	)
	audio._set_enclosure(0.0)
	assert_almost_eq(reverb.wet, AmbienceMix.reverb_wet(0.0), 0.0001, "and left open-deck")
