class_name EndOverlay
extends CanvasLayer
## The results, once the match has ended: the local seat's verdict — "Last one
## dry!" or "Overboard — 4th of 6 — shoved by Bot 3" (the shove only if one sent it
## over), or under survival how long it lasted and its place,
## "Survived 02:14.0 · 3rd" — then every seat's place, time dry (time survived, under
## survival), shoves landed and knock-outs credited, all from MatchStats and so from the
## events
## alone (D5), with rematch and back to the menu — or, online, back to the room and
## leave (offer_room) — on a plate over the world dimmed under a scrim, the HUDs having
## stood down.

signal rematch_requested
signal menu_requested
## Watch the match again (R6): offered for a local match once its replay is kept.
signal replay_requested

const HEADINGS: Array[String] = ["Place", "Seat", "Time dry", "Shoves landed", "Knock-outs"]
## The same under survival, where a seat's time in is the score.
const SURVIVAL_HEADINGS: Array[String] = [
	"Place", "Seat", "Survived", "Shoves landed", "Knock-outs"
]
const LOCAL_COLOUR := Color(1.0, 0.85, 0.3)
## How long the buttons ignore presses once the results show: Space and pad A both
## jump and accept, so a jump mashed as the match ends must not rematch unseen. A
## press begun inside the guard does nothing when it is let go after it.
const PRESS_GUARD_SECONDS := 0.7
## The widest a seat's name is shown, in pixels: a server's may be far longer.
const NAME_WIDTH := 200.0

var _guard := Timer.new()
## What the two buttons do, as the hint words them.
var _first_word := "rematch"
var _second_word := "menu"

@onready var _title: Label = %Title
@onready var _table: GridContainer = %Table
@onready var _seed: Label = %Seed
@onready var _rematch: Button = %Rematch
@onready var _hint: Label = $Panel/Box/Hint
@onready var _watch: Button = %WatchReplay
@onready var _menu: Button = %Menu


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiTheme.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	move_child(scrim, 0)
	_rematch.pressed.connect(rematch_requested.emit)
	_watch.pressed.connect(replay_requested.emit)
	_menu.pressed.connect(menu_requested.emit)
	_guard.one_shot = true
	_guard.wait_time = PRESS_GUARD_SECONDS
	_guard.timeout.connect(_accept_presses)
	add_child(_guard)


## Shows [param stats] once they say the match has ended. [param names] labels
## each seat; [param match_seed] is printed so the match can be typed back in;
## [param survival] says the match was survival (MatchRules.Goal).
func show_results(
	stats: MatchStats, local_seat: int, names: PackedStringArray, match_seed: int, survival := false
) -> void:
	if visible or not stats.ended:
		return
	var mine := stats.seats[local_seat]
	if survival:
		_title.text = survived(mine.dry_ticks, mine.place)
	elif stats.winner == local_seat:
		_title.text = "Last one dry!"
	elif stats.seats.size() == 1:
		_title.text = "Overboard — you stayed dry %s" % MatchTranscript.clock(mine.dry_ticks)
	elif stats.winner == -1 and mine.place == 1:
		_title.text = "The sea wins — nobody stays dry"
	else:
		_title.text = "Overboard — %s of %d" % [ordinal(mine.place), stats.seats.size()]
		if mine.out_by >= 0:
			_title.text += " — shoved by %s" % names[mine.out_by]
	for child in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	_table.columns = HEADINGS.size()
	for heading in SURVIVAL_HEADINGS if survival else HEADINGS:
		_cell(heading, UiTheme.MUTED)
	for line: MatchStats.SeatStats in stats.standings():
		var colour := LOCAL_COLOUR if line.seat == local_seat else UiTheme.TEXT
		_cell(ordinal(line.place), colour)
		var name_cell := _cell(names[line.seat], colour)
		name_cell.text = UiTheme.fit(
			name_cell.text,
			name_cell.get_theme_font(&"font"),
			name_cell.get_theme_font_size(&"font_size"),
			NAME_WIDTH
		)
		_cell(MatchTranscript.clock(line.dry_ticks), colour)
		_cell(str(line.shoves_landed), colour)
		_cell(str(line.knockouts), colour)
	_seed.text = "Seed %d" % match_seed
	_rematch.disabled = true
	_watch.disabled = true
	_menu.disabled = true
	show()
	_guard.start()


## Online, a match's end leads back to its room or out of it: the rematch's button and
## key go back to the room, the menu's leave. No replay is kept online.
func offer_room() -> void:
	_first_word = "back to the room"
	_second_word = "leave"
	_rematch.text = "Back to the room"
	_menu.text = "Leave"
	_watch.visible = false


## Whether the results offer to watch the match again (replay_requested).
func offer_replay(offered: bool) -> void:
	_watch.visible = offered


## Words the hint line for the device [param prompts] says was used last. On a
## pad rematch and pause share Start and rematch wins, so the hint names only the
## rematch there; the Menu button is the way back.
func show_prompts(prompts: InputPrompts) -> void:
	var rematch := prompts.word(&"restart")
	var menu := prompts.word(&"pause")
	var hint := "%s — %s" % [rematch, _first_word]
	if menu != rematch:
		hint += "   ·   %s — %s" % [menu, _second_word]
	_hint.text = hint


func _accept_presses() -> void:
	_rematch.disabled = false
	_watch.disabled = false
	_menu.disabled = false
	if visible:
		_rematch.grab_focus()


## A seat's survival, as its title says it: "Survived 02:14.0 · 3rd".
static func survived(ticks: int, place: int) -> String:
	return "Survived %s · %s" % [MatchTranscript.clock(ticks), ordinal(place)]


static func ordinal(place: int) -> String:
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][place % 10]
	return "%d%s" % [place, suffix]


func _cell(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colour)
	_table.add_child(label)
	return label
