extends GutTest
## BotsAhead's bots decide each beat on a worker thread, a beat ahead, and play the very
## match they play deciding when the runner asks: the same snapshot every tick, a seat
## that is no bot of theirs among them or not, to the match's end, where no beat is left
## under way.

## How long the matches here run, in ticks.
const TICKS := 600


## The steamer, eight seats on the golden seed, sinking as the fixture's scenario has her.
static func _config() -> MatchConfig:
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SCRIPT)
	return SimFixtures.config(8, sinking, 1701, SimFixtures.steamer())


## [param config]'s match played by [param sources] for [param ticks] ticks at most: every
## tick's snapshot, in order.
static func _played(config: MatchConfig, sources: Array[InputSource], ticks: int) -> Array:
	var runner := MatchRunner.new(MatchSim.create(config), sources)
	var snapshots := [runner.snapshot]
	while runner.tick() < ticks and not runner.is_over():
		runner.step()
		snapshots.append(runner.snapshot)
	return snapshots


func after_each() -> void:
	BotsAhead.finish_all()


func test_bots_deciding_ahead_play_the_match_they_play_when_asked() -> void:
	var config := _config()
	var profile: BotProfile = load(SimFixtures.NORMAL_BOT)
	var asked := _played(config, BotInputSource.fill(config, profile), TICKS)
	var ahead := _played(config, BotsAhead.of(BotInputSource.fill(config, profile)), TICKS)
	assert_eq(ahead.size(), asked.size(), "as many ticks")
	var differing := 0
	for tick in mini(ahead.size(), asked.size()):
		if ahead[tick] != asked[tick]:
			differing += 1
	assert_eq(differing, 0, "the same snapshot at every one of %d ticks" % asked.size())


func test_a_seat_that_is_no_bot_is_left_as_it_is() -> void:
	# Seat 0 walks straight on, its own way, among bots deciding ahead.
	var config := _config()
	var profile: BotProfile = load(SimFixtures.NORMAL_BOT)
	var asked := BotInputSource.fill(config, profile, 1)
	asked.push_front(Walker.new())
	var bots := BotInputSource.fill(config, profile, 1)
	bots.push_front(null)
	var ahead := BotsAhead.of(bots)
	assert_null(ahead[0], "no source made of none")
	ahead[0] = Walker.new()
	assert_eq(_played(config, ahead, TICKS), _played(config, asked, TICKS), "the same match")


func test_a_match_played_to_its_end_leaves_no_beat_under_way() -> void:
	var config := _config()
	var profile: BotProfile = load(SimFixtures.NORMAL_BOT)
	var played := _played(config, BotsAhead.of(BotInputSource.fill(config, profile)), 1 << 30)
	assert_eq(played.back()["phase"], MatchState.Phase.ENDED, "the match ends")
	assert_eq(BotsAhead.under_way(), 0, "and its bots decided nothing past it")


## A seat walking forward every tick, seat 0's.
class Walker:
	extends InputSource

	func next_frame(tick: int) -> InputFrame:
		return InputFrame.new(0, tick, Vector2i(0, 1))
