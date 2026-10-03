class_name EndOverlay
extends CanvasLayer
## The results, once the match has ended: the local seat's verdict — "Last one
## dry!" or "Overboard — 4th of 6" — then every seat's place, time dry, shoves
## landed and knock-outs credited, all from MatchStats and so from the events
## alone (D5), with rematch and back to the menu.

signal rematch_requested
signal menu_requested

const HEADINGS: Array[String] = ["Place", "Seat", "Time dry", "Shoves landed", "Knock-outs"]
const LOCAL_COLOUR := Color(1.0, 0.85, 0.3)
## How long the buttons ignore presses once the results show: Space and pad A both
## jump and accept, so a jump mashed as the match ends must not rematch unseen. A
## press begun inside the guard does nothing when it is let go after it.
const PRESS_GUARD_SECONDS := 0.7

var _guard := Timer.new()

@onready var _title: Label = %Title
@onready var _table: GridContainer = %Table
@onready var _seed: Label = %Seed
@onready var _rematch: Button = %Rematch
@onready var _hint: Label = $Panel/Box/Hint
@onready var _menu: Button = %Menu


func _ready() -> void:
	hide()
	_rematch.pressed.connect(rematch_requested.emit)
	_menu.pressed.connect(menu_requested.emit)
	_guard.one_shot = true
	_guard.wait_time = PRESS_GUARD_SECONDS
	_guard.timeout.connect(_accept_presses)
	add_child(_guard)


## Shows [param stats] once they say the match has ended. [param names] labels
## each seat; [param match_seed] is printed so the match can be typed back in.
func show_results(
	stats: MatchStats, local_seat: int, names: PackedStringArray, match_seed: int
) -> void:
	if visible or not stats.ended:
		return
	var mine := stats.seats[local_seat]
	if stats.winner == local_seat:
		_title.text = "Last one dry!"
	elif stats.winner == -1 and mine.place == 1:
		_title.text = "The sea wins — nobody stays dry"
	else:
		_title.text = "Overboard — %s of %d" % [ordinal(mine.place), stats.seats.size()]
	for child in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	_table.columns = HEADINGS.size()
	for heading in HEADINGS:
		_cell(heading, Color(1.0, 1.0, 1.0, 0.6))
	for line: MatchStats.SeatStats in stats.standings():
		var colour := LOCAL_COLOUR if line.seat == local_seat else Color.WHITE
		_cell(ordinal(line.place), colour)
		_cell(names[line.seat], colour)
		_cell(MatchTranscript.clock(line.dry_ticks), colour)
		_cell(str(line.shoves_landed), colour)
		_cell(str(line.knockouts), colour)
	_seed.text = "Seed %d" % match_seed
	_rematch.disabled = true
	_menu.disabled = true
	show()
	_guard.start()


## Words the hint line for the device [param prompts] says was used last. On a
## pad rematch and pause share Start and rematch wins, so the hint names only the
## rematch there; the Menu button is the way back.
func show_prompts(prompts: InputPrompts) -> void:
	var rematch := prompts.word(&"restart")
	var menu := prompts.word(&"pause")
	var hint := "%s — rematch" % rematch
	if menu != rematch:
		hint += "   ·   %s — menu" % menu
	_hint.text = hint


func _accept_presses() -> void:
	_rematch.disabled = false
	_menu.disabled = false
	if visible:
		_rematch.grab_focus()


static func ordinal(place: int) -> String:
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][place % 10]
	return "%d%s" % [place, suffix]


func _cell(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colour)
	_table.add_child(label)
