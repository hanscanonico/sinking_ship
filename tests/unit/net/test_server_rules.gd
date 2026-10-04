extends GutTest
## A server's limits (SH12, R9) are checked before it listens: the shipped ones hold,
## and a silence too short for a ping's round trip is refused.


func test_the_shipped_rules_have_no_problems() -> void:
	assert_eq(ServerRules.load_default().problems(), PackedStringArray())


## A healthy client in a waiting room is heard only through its pongs, at most a
## ping_interval apart plus the round trip: silence_timeout must outlast two pings
## and a second more.
func test_silence_outlasts_two_pings_and_a_second() -> void:
	for silence: float in [1.1, 2.0, 2.9]:
		var rules := RoomFixtures.rules_with({"ping_interval": 1.0, "silence_timeout": silence})
		assert_true(_names(rules.problems(), "silence_timeout"), "%.1f s is refused" % silence)
	var rules := RoomFixtures.rules_with({"ping_interval": 1.0, "silence_timeout": 3.0})
	assert_eq(rules.problems(), PackedStringArray(), "3 s is enough")


static func _names(problems: PackedStringArray, field: String) -> bool:
	for problem: String in problems:
		if problem.contains(field):
			return true
	return false
