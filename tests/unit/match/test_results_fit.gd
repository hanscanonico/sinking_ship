extends GutTest
## The results plate (EndOverlay) stands whole inside the view at every seat count a
## ship seats, in every language, and the fate line under its standings reads whole. At
## 16 seats the plate was 789 px tall in a 648 px view — its title above the screen, its
## buttons under it — and in French and Spanish the fate line ended on an ellipsis.

const MATCH_SCENE := preload("res://scenes/match/match.tscn")
const MOST_SEATS := 16
## The smallest view the game is laid out for.
const VIEW := Vector2i(1152, 648)
## A name far past the widest the table shows: every name at its cap.
const LONG_NAME := "Wilhelmina Wolfeschlegelstein %d"
## Every ship's name, as a match hands it to the results (MatchScene).
const SHIPS: Array[String] = [
	"Barque",
	"Ferry",
	"Flat Deck",
	"Freighter",
	"Small Titanic",
	"Steamer",
	"Titanic",
	"Trawler",
	"Tug"
]

var _schedule: SinkSchedule


func before_all() -> void:
	var scenario: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	_schedule = SimFixtures.config(8, scenario, 1701, SimFixtures.steamer()).schedule()


func after_each() -> void:
	Language.use(Language.SOURCE)


## A match of [param seats] seat 0 won, every other out in turn.
func _stats(seats: int) -> MatchStats:
	var events: Array[SimEvent] = []
	for seat in range(1, seats):
		var tick := (600 + seat) * Ticks.RATE
		events.append(SimEvent.seat_out(tick, seat, seats - seat + 1, PlayerState.Cause.COLD, -1))
	events.append(SimEvent.match_ended(_ended(), 0))
	var stats := MatchStats.new(seats, 0)
	stats.add(events)
	return stats


## A tick past the end of the sinking: all of it played.
func _ended() -> int:
	return _schedule.end_tick() + 3600 * Ticks.RATE


func _names(seats: int) -> PackedStringArray:
	var names := PackedStringArray()
	for seat in seats:
		names.append(LONG_NAME % seat)
	return names


func _results() -> EndOverlay:
	var window := SubViewport.new()
	window.size = VIEW
	add_child_autofree(window)
	var scene: Node = MATCH_SCENE.instantiate()
	window.add_child(scene)
	var results: EndOverlay = scene.get_node("EndOverlay")
	results.offer_replay(true)
	return results


func _inside(view: Rect2, node: Control) -> bool:
	return node.is_visible_in_tree() and view.encloses(node.get_global_rect())


func test_the_plate_stands_inside_the_view_at_every_seat_count() -> void:
	var results := _results()
	var view := results.get_viewport().get_visible_rect()
	assert_eq(view.size, Vector2(VIEW), "the view the plate is laid out for")
	var plate: Control = results.get_node("Panel")
	var parts: Array[Control] = [
		results.get_node("%Title"),
		results.get_node("%Table"),
		results.get_node("%Rematch"),
		results.get_node("%WatchReplay"),
		results.get_node("%Menu"),
	]
	var out := PackedStringArray()
	for language: String in Language.locales():
		Language.use(language)
		for seats in range(2, MOST_SEATS + 1):
			var stats := _stats(seats)
			var names := _names(seats)
			var session := SessionTally.new()
			session.count(stats, names)
			session.count(stats, names)
			for told: bool in [false, true]:
				for counted: bool in [false, true]:
					results.hide()
					results.setup_fate("Small Titanic", _schedule if told else null)
					# The local seat is the last placed: the row furthest down.
					results.show_results(
						stats, 1, names, 4294967295, false, session if counted else null
					)
					await wait_frames(2)
					var size := plate.get_global_rect().size
					var what := (
						"%s, %d seats%s%s: %.0f×%.0f"
						% [
							language,
							seats,
							", fate" if told else "",
							", session" if counted else "",
							size.x,
							size.y
						]
					)
					if seats == 12 or seats == MOST_SEATS:
						gut.p(what)
					var whole := _inside(view, plate)
					for part: Control in parts:
						whole = whole and _inside(view, part)
					if counted:
						whole = whole and _inside(view, results.get_node("%SessionTable"))
					if not whole:
						out.append(what)
	assert_eq(out.size(), 0, "off the screen: " + "; ".join(out))


## The local seat's own row is on the plate whatever its place, and no row is left out.
func test_every_seat_keeps_its_row() -> void:
	var results := _results()
	var view := results.get_viewport().get_visible_rect()
	var stats := _stats(MOST_SEATS)
	for local in MOST_SEATS:
		results.hide()
		results.show_results(stats, local, _names(MOST_SEATS), 1701)
		await wait_frames(2)
		var mine := 0
		var rows := 0
		for cell: Label in results.get_node("%Table").find_children("*", "Label", true, false):
			rows += 1
			if cell.get_theme_color(&"font_color") == EndOverlay.LOCAL_COLOUR:
				mine += 1
				assert_true(_inside(view, cell), "seat %d's own row on the screen" % local)
		assert_eq(mine, EndOverlay.HEADINGS.size(), "seat %d's row picked out" % local)
		assert_eq(rows, (MOST_SEATS + 1) * EndOverlay.HEADINGS.size(), "every seat's row")


func test_the_fate_line_reads_whole_in_every_language() -> void:
	var results := _results()
	var fate: Label = results.get_node("%Fate")
	var stats := _stats(2)
	for language: String in Language.locales():
		Language.use(language)
		for ship: String in SHIPS:
			results.hide()
			results.setup_fate(ship, _schedule)
			results.show_results(stats, 0, _names(2), 1701)
			assert_true(fate.visible)
			assert_eq(fate.text, EndOverlay.fate_words(ship, _schedule, _ended()), language)


## Every ship, however her sinking ends, all of it played: the longest her line gets.
func test_no_ship_s_fate_is_cut_however_she_ends() -> void:
	var results := _results()
	var fate: Label = results.get_node("%Fate")
	var font := fate.get_theme_font(&"font")
	var font_size := fate.get_theme_font_size(&"font_size")
	var endings: Array[String] = ["her end untold"]
	endings.append_array(MatchTranscript.FOUNDERS.values())
	var widest := 0.0
	for language: String in Language.locales():
		Language.use(language)
		for ship: String in SHIPS:
			for ending: String in endings:
				var line := EndOverlay.fate_of(ship, ending, 1.0)
				assert_eq(UiTheme.fit(line, font, font_size, EndOverlay.FATE_WIDTH), line, language)
				var wide := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				if wide > widest:
					widest = wide
					gut.p("%.0f px: %s" % [wide, line])
	assert_gt(widest, 400.0, "measured")
