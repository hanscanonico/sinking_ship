extends GutTest
## The results' title says how the match ended for the local seat (EndOverlay).


## Everyone left out together on one tick is a draw: the sea's — or, on the tick she
## leans past what a match follows (§5b.3's interim rule), hers, everyone still dry.
func test_a_draw_as_she_lies_too_far_over_says_so() -> void:
	var titles := PackedStringArray()
	for unsupported: int in [-1, 90]:
		var scene: Node = load("res://scenes/match/match.tscn").instantiate()
		add_child_autofree(scene)
		var ended: Array[SimEvent] = [
			SimEvent.seat_out(90, 0, 1, PlayerState.Cause.COLD, -1),
			SimEvent.seat_out(90, 1, 1, PlayerState.Cause.COLD, -1),
			SimEvent.match_ended(90, -1),
		]
		var stats := MatchStats.new(2, 0)
		stats.add(ended)
		assert_eq(stats.ended_tick, 90, "the stats keep the tick it ended on")
		var results: EndOverlay = scene.get_node("EndOverlay")
		results.show_results(stats, 0, PackedStringArray(["You", "Bot 1"]), 1701, unsupported)
		titles.append((results.get_node("%Title") as Label).text)
	assert_eq(titles[0], "The sea wins — nobody stays dry", "the sea's draw")
	assert_eq(titles[1], "She lies too far over — the match ends here", "hers")
