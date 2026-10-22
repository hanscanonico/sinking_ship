extends GutTest
## The results' title says how the match ended for the local seat (EndOverlay).

const MATCH_SCENE := preload("res://scenes/match/match.tscn")


## Everyone left out together on one tick is a draw: the sea's. Nothing else draws a
## match since SH32 follows her through any attitude.
func test_a_draw_says_the_sea_wins() -> void:
	var scene: Node = MATCH_SCENE.instantiate()
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


## Under survival the title says how long the local seat lasted and its place, and the
## time column is the time survived.
func test_survival_results_say_time_survived_and_place() -> void:
	var scene: Node = MATCH_SCENE.instantiate()
	add_child_autofree(scene)
	var ended: Array[SimEvent] = [
		SimEvent.seat_out(30 * Ticks.RATE, 2, 3, PlayerState.Cause.COLD, -1),
		SimEvent.seat_out(134 * Ticks.RATE, 0, 2, PlayerState.Cause.COLD, -1),
		SimEvent.match_ended(200 * Ticks.RATE, 1),
	]
	var stats := MatchStats.new(3, 0)
	stats.add(ended)
	var results: EndOverlay = scene.get_node("EndOverlay")
	var names := PackedStringArray(["You", "Bot 1", "Bot 2"])
	results.show_results(stats, 0, names, 1701, true)
	assert_eq((results.get_node("%Title") as Label).text, "Survived 02:14.0 · 2nd")
	var table: GridContainer = results.get_node("%Table")
	assert_eq((table.get_child(2) as Label).text, "Survived")
	var columns := table.columns
	assert_eq((table.get_child(columns) as Label).text, "1st", "the last one in first")
	assert_eq((table.get_child(columns + 2) as Label).text, "03:20.0", "in to the end")


## Shoved out, the title names the shover; gone in on its own, it names nobody.
func test_the_title_names_who_shoved_you() -> void:
	var names := PackedStringArray(["You", "Bot 1", "Bot 2"])
	var titles: Array[String] = []
	for credit: int in [2, -1]:
		var scene: Node = MATCH_SCENE.instantiate()
		add_child_autofree(scene)
		var stats := MatchStats.new(3, 0)
		(
			stats
			. add(
				[
					SimEvent.seat_out(90, 0, 3, PlayerState.Cause.COLD, credit),
					SimEvent.seat_out(120, 1, 2, PlayerState.Cause.COLD, -1),
					SimEvent.match_ended(120, 2),
				]
			)
		)
		var results: EndOverlay = scene.get_node("EndOverlay")
		results.show_results(stats, 0, names, 1701)
		titles.append((results.get_node("%Title") as Label).text)
	assert_eq(titles, ["Overboard — 3rd of 3 — shoved by Bot 2", "Overboard — 3rd of 3"])


func test_the_battle_royale_results_keep_their_words() -> void:
	var scene: Node = MATCH_SCENE.instantiate()
	add_child_autofree(scene)
	var ended: Array[SimEvent] = [
		SimEvent.seat_out(90, 1, 2, PlayerState.Cause.COLD, -1),
		SimEvent.match_ended(90, 0),
	]
	var stats := MatchStats.new(2, 0)
	stats.add(ended)
	var results: EndOverlay = scene.get_node("EndOverlay")
	results.show_results(stats, 0, PackedStringArray(["You", "Bot 1"]), 1701)
	assert_eq((results.get_node("%Title") as Label).text, "Last one dry!")
	assert_eq((results.get_node("%Table").get_child(2) as Label).text, "Time dry")
