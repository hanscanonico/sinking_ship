extends GutTest
## MatchAudio looks each bus up by name once and keeps its index, and looks again as
## the bus layout changes: what it finds is always the bus of that name. The poses it
## keeps, a second of them, are always the schedule's at their tick.


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


## A sinking whose pose at each tick says which tick it is: its sink, a centimetre a
## tick.
class TickedSchedule:
	extends SinkSchedule

	func _init() -> void:
		var stream := RandomNumberGenerator.new()
		stream.seed = 1701
		super(SimFixtures.tilted(0.0, 0.0), 3.0, stream)

	func _posed(tick: int) -> ShipPose:
		var pose: ShipPose = super(tick)
		pose.sink = tick * 0.01
		return pose


func test_a_pose_kept_is_the_schedule_s_at_that_tick() -> void:
	var audio: MatchAudio = autofree(MatchAudio.new())
	audio._schedule = TickedSchedule.new()
	audio._forget_poses()
	var slots := Ticks.RATE + 1
	# Each tick and the one a second before it, as _read_sinking asks, then ticks that
	# land in slots already taken, then the first ones again.
	var ticks: Array[int] = []
	for tick in range(600, 640):
		ticks.append_array([tick, tick - Ticks.RATE])
	ticks.append_array([600 + slots, 600 + 2 * slots, 600, 600 - Ticks.RATE, 601])
	for tick in ticks:
		assert_almost_eq(audio._pose_at(tick).sink, tick * 0.01, 1e-9, "tick %d" % tick)
