extends GutTest
## The results' title says how the match ended for the local seat (EndOverlay).


## Everyone left out together on one tick is a draw: the sea's. Nothing else draws a
## match since SH32 follows her through any attitude.
func test_a_draw_says_the_sea_wins() -> void:
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
	results.show_results(stats, 0, PackedStringArray(["You", "Bot 1"]), 1701)
	assert_eq((results.get_node("%Title") as Label).text, "The sea wins — nobody stays dry")
