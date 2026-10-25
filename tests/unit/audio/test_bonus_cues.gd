extends GutTest
## What the bonuses sound like (#313), heard by CuePlanner from the snapshots and their
## events alone: a bonus aboard hums where it lies, faintly and only near it; taking one
## rings at the seat that took it, and a Double life spent sounds at the swimmer it kept in.

const GRAB := InputFrame.GRAB
const HUM := AudioCue.Kind.HUM
const TAKEN := AudioCue.Kind.BONUS_TAKEN
const SPENT := AudioCue.Kind.DOUBLE_LIFE_SPENT


## Heard through [param listener]'s ears.
func _planner(sim: MatchSim, listener: int) -> CuePlanner:
	var planner := CuePlanner.new(sim.config, sim.surfaces, sim.schedule, 0)
	planner.listener_seat = listener
	return planner


func _of(cues: Array[AudioCue], kind: AudioCue.Kind) -> Array[AudioCue]:
	return cues.filter(func(cue: AudioCue) -> bool: return cue.kind == kind)


## The cues of one step of [param sim], each seat sending its frame in [param frames].
func _step(planner: CuePlanner, sim: MatchSim, frames: Dictionary = {}) -> Array[AudioCue]:
	var previous := sim.snapshot()
	SimFixtures.step(sim, frames)
	return planner.plan(previous, sim.snapshot())


## Two seats in below_decks' hold with a Double life lying at its spot and no plan to bring
## another: seat 0 beside the bonus, facing it, seat 1 up on the deck.
func _with_a_bonus() -> MatchSim:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 2)
	SimFixtures.bring_aboard(sim, 0)
	SimFixtures.place(sim, 0, SimFixtures.by_hold_spot(), 0.0)
	SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
	return sim


## Each bonus aboard hums from its spot, for as long as it lies there — faintly, fainter than
## a footfall, and heard only near it, out of earshot a room's width off — a sound kept up
## rather than a cue of one step. None hums once taken.
func test_a_bonus_aboard_hums_faintly_from_where_it_lies() -> void:
	var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 2, SimFixtures.below_decks(2))
	SimFixtures.bring_aboard(sim, 1)
	SimFixtures.bring_aboard(sim, 0)
	SimFixtures.place(sim, 0, SimFixtures.by_hold_spot(0), 0.0)
	SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
	var planner := _planner(sim, 1)
	var hums := planner.hums(sim.snapshot())
	assert_eq(hums.size(), 2, "one per bonus aboard")
	for index in mini(hums.size(), 2):
		assert_eq(hums[index].kind, HUM)
		assert_true(hums[index].positional, "from a place")
		assert_eq(hums[index].position, SimFixtures.hold_spot([1, 0][index]), "its spot")
	assert_lt(SoundBank.db(HUM), SoundBank.db(AudioCue.Kind.FOOTSTEP), "faint")
	assert_lte(SoundBank.far(HUM), 6.0, "heard only near it")
	assert_eq(_of(_step(planner, sim), HUM), [], "never a step's cue")
	_step(planner, sim, {0: SimFixtures.frame(0, Vector2.ZERO, GRAB)})
	hums = planner.hums(sim.snapshot())
	assert_eq(hums.size(), 1, "the one taken hums no more")
	if hums.size() == 1:
		assert_eq(hums[0].position, SimFixtures.hold_spot(1), "the other hums on")


## MatchAudio keeps a voice humming at each hum, where its bonus lies as the ship is drawn —
## on the room's bus, at the hum's level and carry, looping — and lets it go as the bonus
## goes, or as everything falls silent for a replay sought.
func test_match_audio_keeps_a_voice_humming_where_each_bonus_lies() -> void:
	var audio: MatchAudio = add_child_autofree(MatchAudio.new())
	var hums: Array[AudioCue] = [AudioCue.new(HUM, 0), AudioCue.new(HUM, 0)]
	hums[0].position = Vector3(1.0, -2.0, 3.0)
	hums[1].position = Vector3(-4.0, -2.0, 0.5)
	var drawn := Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.0, 1.5, 2.0))
	audio._keep_humming(hums, drawn)
	var voices := audio.find_children("Hum*", "AudioStreamPlayer3D", false, false)
	assert_eq(voices.size(), 2, "one per hum")
	for index in mini(voices.size(), 2):
		var voice := voices[index] as AudioStreamPlayer3D
		var at := drawn * hums[index].position
		assert_almost_eq(voice.global_position, at, Vector3.ONE * 1e-5, "where it lies")
		assert_eq(voice.bus, SoundBank.ROOM_BUS)
		assert_eq(voice.volume_db, SoundBank.db(HUM))
		assert_eq(voice.unit_size, SoundBank.near(HUM))
		assert_eq(voice.max_distance, SoundBank.far(HUM), "heard only near it")
		var file := (voice.stream as AudioStreamRandomizer).get_stream(0) as AudioStreamWAV
		assert_eq(file.loop_mode, AudioStreamWAV.LOOP_FORWARD, "kept up: it loops")
	audio._keep_humming(hums.slice(0, 1), drawn)
	await wait_process_frames(1)
	var left := audio.find_children("Hum*", "AudioStreamPlayer3D", false, false)
	assert_eq(left.size(), 1, "the bonus gone goes quiet")
	audio._silence()
	await wait_process_frames(1)
	assert_eq(audio.find_children("Hum*", "", false, false), [], "and every hum with the rest")


## A bonus the sea takes (#311) hums no more; nor is there any hum without bonuses.
func test_a_bonus_lost_to_the_sea_hums_no_more() -> void:
	var sim := SimFixtures.bonus_sim(
		SimFixtures.bonus_rules(600.0), 1, null, SimFixtures.flooding(1.0)
	)
	SimFixtures.bring_aboard(sim, 0)
	var planner := _planner(sim, 0)
	assert_eq(planner.hums(sim.snapshot()).size(), 1, "while it lies dry")
	SimFixtures.step(sim, {}, Ticks.RATE + 2)
	assert_true(sim.state.bonuses.is_empty(), "lost to the sea")
	assert_eq(planner.hums(sim.snapshot()), [], "and its hum with it")
	var without := SimFixtures.sim(1, null, SimFixtures.below_decks())
	assert_eq(_planner(without, 0).hums(without.snapshot()), [], "no bonuses, no hum")


## A Grab press taking a bonus rings once, at the seat that took it: from where it stands to
## anyone else's ears, in the head to its own.
func test_taking_a_bonus_rings_at_the_seat_that_took_it() -> void:
	for listener: int in [1, 0]:
		var sim := _with_a_bonus()
		var planner := _planner(sim, listener)
		var rung := _of(_step(planner, sim, {0: SimFixtures.frame(0, Vector2.ZERO, GRAB)}), TAKEN)
		assert_eq(rung.size(), 1, "one ring as it takes it, heard by seat %d" % listener)
		if rung.size() == 1:
			assert_eq(rung[0].seat, 0, "the taker's")
			assert_eq(rung[0].positional, listener != 0, "in the head only to the taker")
		assert_true(sim.state.bonuses.is_empty(), "taken")
		assert_eq(_of(_step(planner, sim), TAKEN), [], "and none after")


## A Double life spent as the cold meter runs out in the sea sounds once, at the swimmer
## it kept in: from where it swims to anyone else's ears, in the head to its own.
func test_a_double_life_spent_sounds_at_the_swimmer_it_kept_in() -> void:
	for listener: int in [1, 0]:
		var sim := SimFixtures.bonus_sim(SimFixtures.bonus_rules(600.0), 2)
		SimFixtures.place(sim, 1, Vector3(10.0, 0.0, 0.0))
		SimFixtures.swim(sim, 0, Vector3(0.0, 0.0, 6.0))
		sim.state.seats[0].cold = Ticks.SECONDS_PER_TICK
		sim.state.seats[0].bonus = 0
		var planner := _planner(sim, listener)
		var spent := _of(_step(planner, sim), SPENT)
		assert_eq(spent.size(), 1, "once, as the meter fills again, heard by seat %d" % listener)
		if spent.size() == 1:
			assert_eq(spent[0].seat, 0, "the swimmer's")
			assert_eq(spent[0].positional, listener != 0, "in the head only to the swimmer")
		assert_eq(sim.state.seats[0].bonus, -1, "spent")
		assert_eq(_of(_step(planner, sim), SPENT), [], "and none after")
