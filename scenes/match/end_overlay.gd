class_name EndOverlay
extends CanvasLayer
## The results, once the match has ended: the local seat's verdict — "Last one
## dry!" or "Overboard — 4th of 6 — shoved by Bot 3" (the shove only if one sent it
## over), "Sunk — 4th of 6" inside her as she went, or under survival how long it
## lasted and its place, "Survived 02:14.0 · 3rd", and " — sunk with her" after it
## inside her as she went — then every seat's place, time dry (time survived, under
## survival), shoves landed and knock-outs credited, all from MatchStats and so from the
## events
## alone (D5), with rematch and back to the menu — or, online, back to the room and
## leave (offer_room), and what comes next (say_next) — on a plate over the world dimmed
## under a scrim, the HUDs having stood down. From a session's second match on, the
## session's standings stand beside the table (SessionTally): each name's points and
## rank over its matches. Under the table one line tells the ship's fate (setup_fate,
## MatchTranscript.fate_line): her name, how her sinking ends and how much of it the
## match played. A watcher has no seat (-1): the title names who won (watched_title) and
## no row is picked out. The plate stands whole inside the view whatever the seats: its
## rows set tighter, its names cut shorter, as it needs (_fit_plate).

signal rematch_requested
signal menu_requested
## Watch the match again (R6): offered for a local match once its replay is kept.
signal replay_requested

const HEADINGS: Array[String] = ["Place", "Seat", "Time dry", "Shoves landed", "Knock-outs"]
## The same under survival, where a seat's time in is the score.
const SURVIVAL_HEADINGS: Array[String] = [
	"Place", "Seat", "Survived", "Shoves landed", "Knock-outs"
]
const SESSION_HEADINGS: Array[String] = ["Rank", "Seat", "Points"]
const LOCAL_COLOUR := Color(1.0, 0.85, 0.3)
## How long the buttons ignore presses once the results show: Space and pad A both
## jump and accept, so a jump mashed as the match ends must not rematch unseen. A
## press begun inside the guard does nothing when it is let go after it.
const PRESS_GUARD_SECONDS := 0.7
## The widest a seat's name is shown, in pixels: a server's may be far longer.
const NAME_WIDTH := 200.0
## The widths a name is cut to in turn, widest first, until the plate is no wider than
## the view: the session's standings beside the table show every name twice.
const NAME_WIDTHS: Array[float] = [NAME_WIDTH, 170.0, 140.0, 110.0]
## The widest the fate line is shown, in pixels: the longest any ship's is, in any
## language, with all of her sinking played — a narrower plate widens to it.
const FATE_WIDTH := 640.0
## The least of the view left clear around the plate, in pixels a side.
const PLATE_MARGIN := 12.0
## How tightly the standings are set, loosest first: the plate takes the first it stands
## inside the view with (_fit_plate) — a small match the first, sixteen seats with the
## fate line and the session's standings a far tighter one. Each is its rows' font size,
## the gap between two rows and the gap between the plate's parts, in pixels.
const DENSITIES: Array[Vector3i] = [
	Vector3i(17, 6, 14),
	Vector3i(16, 4, 12),
	Vector3i(15, 3, 10),
	Vector3i(15, 1, 8),
	Vector3i(14, 0, 8),
	Vector3i(13, 0, 6),
	Vector3i(12, 0, 4),
]

var _guard := Timer.new()
## What the two buttons do, as the hint words them.
var _first_word := "rematch"
var _second_word := "menu"
## Whose fate the results tell, and the sinking that tells it (setup_fate).
var _ship_name := ""
var _schedule: SinkSchedule
## Every name on the plate, whole, by the cell that shows it: cut to fit as the plate is.
var _named: Dictionary[Label, String] = {}

@onready var _plate: PanelContainer = $Panel
@onready var _box: VBoxContainer = $Panel/Box
@onready var _title: Label = %Title
@onready var _table: GridContainer = %Table
@onready var _session: VBoxContainer = %Session
@onready var _session_title: Label = %SessionTitle
@onready var _session_table: GridContainer = %SessionTable
@onready var _fate: Label = %Fate
@onready var _seed: Label = %Seed
@onready var _next: Label = %Next
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
## [param survival] says the match was survival (MatchRules.Goal); [param session] is
## the session it was counted in, if any (show_session); [param aboard] says the local
## seat went out inside one of her rooms (Hud.out_word).
func show_results(
	stats: MatchStats,
	local_seat: int,
	names: PackedStringArray,
	match_seed: int,
	survival := false,
	session: SessionTally = null,
	aboard := false
) -> void:
	if visible or not stats.ended:
		return
	_title.text = _title_of(stats, local_seat, names, survival, aboard)
	for child in _table.get_children():
		_named.erase(child)
		_table.remove_child(child)
		child.queue_free()
	_table.columns = HEADINGS.size()
	for heading in SURVIVAL_HEADINGS if survival else HEADINGS:
		_cell(heading, UiTheme.MUTED)
	for line: MatchStats.SeatStats in stats.standings():
		var colour := LOCAL_COLOUR if line.seat == local_seat else UiTheme.TEXT
		_cell(ordinal(line.place), colour)
		_name_cell(_table, names[line.seat], colour)
		_cell(MatchTranscript.clock(line.dry_ticks), colour)
		_cell(str(line.shoves_landed), colour)
		_cell(str(line.knockouts), colour)
	show_session(session, names[local_seat] if local_seat >= 0 else "")
	_show_fate(stats.ended_tick)
	_seed.text = Language.t("Seed %d") % match_seed
	_fit_plate()
	_rematch.disabled = true
	_watch.disabled = true
	_menu.disabled = true
	show()
	_guard.start()


## The results' title: how [param stats]' match ended for [param local_seat] — under
## survival, [param survival], how long it lasted —, or for a watcher (-1) who won it.
## [param aboard] says the seat went out inside one of her rooms: frozen there by the
## cold, never overboard (Hud.out_word).
static func _title_of(
	stats: MatchStats, local_seat: int, names: PackedStringArray, survival: bool, aboard := false
) -> String:
	if local_seat < 0:
		return watched_title(stats, names, survival)
	var mine := stats.seats[local_seat]
	var gone := Hud.out_word(mine.out_cause, aboard)
	if survival:
		return survived(mine.dry_ticks, mine.place, mine.out_cause)
	if stats.winner == local_seat:
		return Language.t("Last one dry!")
	if stats.seats.size() == 1:
		return Language.t("%s — you stayed dry %s") % [gone, MatchTranscript.clock(mine.dry_ticks)]
	if stats.winner == -1 and mine.place == 1:
		return Language.t("The sea wins — nobody stays dry")
	var title := Language.t("%s — %s of %d") % [gone, ordinal(mine.place), stats.seats.size()]
	# A shove long before she went is no shove over the side.
	if mine.out_by >= 0 and mine.out_cause != PlayerState.Cause.WITH_HER:
		title += Language.t(" — shoved by %s") % names[mine.out_by]
	return title


## The results' title for a watcher, named by [param names]: the last one dry, or that
## nobody stayed dry; under survival, [param survival], who lasted longest and how long —
## every seat placed first, when several lasted as long.
static func watched_title(stats: MatchStats, names: PackedStringArray, survival: bool) -> String:
	if not survival:
		if stats.winner == -1:
			return Language.t("The sea wins — nobody stays dry")
		return Language.t("Last one dry: %s") % names[stats.winner]
	var first := PackedStringArray()
	var lasted := 0
	for line: MatchStats.SeatStats in stats.standings():
		if line.place == 1:
			first.append(names[line.seat])
			lasted = line.dry_ticks
	return Language.t("Lasted longest: %s · %s") % [", ".join(first), MatchTranscript.clock(lasted)]


## The ship the match is played on, by [param ship_name], and [param schedule], the
## sinking that tells her fate on the results; a null schedule tells none.
func setup_fate(ship_name: String, schedule: SinkSchedule) -> void:
	_ship_name = ship_name
	_schedule = schedule


## The fate line for a match ended on [param tick], fitted to the plate; hidden when
## there is no sinking to tell.
func _show_fate(tick: int) -> void:
	var line := "" if _schedule == null else fate_words(_ship_name, _schedule, tick)
	_fate.text = UiTheme.fit(
		line, _fate.get_theme_font(&"font"), _fate.get_theme_font_size(&"font_size"), FATE_WIDTH
	)
	_fate.visible = not line.is_empty()


## The fate line (MatchTranscript.fate_line) in the language in use: the ship by
## [param ship_name], how her sinking ends, and how much of it was played by [param tick].
static func fate_words(ship_name: String, schedule: SinkSchedule, tick: int) -> String:
	var timeline := schedule.timeline()
	if timeline == null:
		return ""
	return fate_of(
		ship_name,
		MatchTranscript.founders(OutcomeClassifier.labels(timeline)),
		MatchTranscript.share_played(schedule, tick)
	)


## The fate line of the ship by [param ship_name] whose sinking ends as [param ending]
## says (MatchTranscript.founders), [param share] of it played, in the language in use.
static func fate_of(ship_name: String, ending: String, share: float) -> String:
	return (
		Language.t("%s · %s · %.0f%% of her sinking played")
		% [
			Language.titled(ship_name.to_lower()),
			Language.t(ending),
			clampf(share, 0.0, 1.0) * 100.0,
		]
	)


## Online, a match's end leads back to its room or out of it: the rematch's button and
## key go back to the room, the menu's leave. No replay is kept online.
func offer_room() -> void:
	_first_word = "back to the room"
	_second_word = "leave"
	_rematch.text = "Back to the room"
	_menu.text = "Leave"
	_watch.visible = false


## Online, what is coming after these results — a quick game's countdown to its next
## match, say — as [param line] words it, over the hint; "" for nothing.
func say_next(line: String) -> void:
	_next.text = line
	var shown := not line.is_empty()
	if _next.visible != shown:
		_next.visible = shown
		_fit_plate()


## Whether the results offer to watch the match again (replay_requested).
func offer_replay(offered: bool) -> void:
	_watch.visible = offered


## Words the hint line for the device [param prompts] says was used last. On a
## pad rematch and pause share Start and rematch wins, so the hint names only the
## rematch there; the Menu button is the way back.
func show_prompts(prompts: InputPrompts) -> void:
	var rematch := prompts.word(&"restart")
	var menu := prompts.word(&"pause")
	var hint := "%s — %s" % [rematch, Language.t(_first_word)]
	if menu != rematch:
		hint += "   ·   %s — %s" % [menu, Language.t(_second_word)]
	_hint.text = hint


func _accept_presses() -> void:
	_rematch.disabled = false
	_watch.disabled = false
	_menu.disabled = false
	if visible:
		_rematch.grab_focus()


## A seat's survival, as its title says it: "Survived 02:14.0 · 3rd" — and, gone out by
## [param cause] inside her as she went, " — sunk with her" after it: the last one in
## as she goes is placed first though nothing it could see put it out.
static func survived(ticks: int, place: int, cause := PlayerState.Cause.COLD) -> String:
	var title := Language.t("Survived %s · %s") % [MatchTranscript.clock(ticks), ordinal(place)]
	if cause == PlayerState.Cause.WITH_HER:
		title += Language.t(" — sunk with her")
	return title


static func ordinal(place: int) -> String:
	return Language.ordinal(place)


## The session's standings beside the table — "Session · match 3", then every name's
## rank and points, [param local_name]'s row picked out — once [param session] has
## counted two matches or more; hidden with none, or only the one this is.
func show_session(session: SessionTally, local_name: String) -> void:
	for child in _session_table.get_children():
		_named.erase(child)
		_session_table.remove_child(child)
		child.queue_free()
	_session.visible = session != null and session.matches >= 2
	if not _session.visible:
		return
	_session_title.text = Language.t("Session · match %d") % session.matches
	_session_title.add_theme_color_override("font_color", UiTheme.MUTED)
	for heading in SESSION_HEADINGS:
		_cell_in(_session_table, heading, UiTheme.MUTED)
	for line: SessionTally.Line in session.standings():
		var colour := LOCAL_COLOUR if line.name == local_name else UiTheme.TEXT
		_cell_in(_session_table, ordinal(line.rank), colour)
		_name_cell(_session_table, line.name, colour)
		_cell_in(_session_table, str(line.points), colour)


## Sets the plate inside the view: the standings as loosely as it stands no taller than
## the view with (DENSITIES), then the names as wide as it stands no wider with
## (NAME_WIDTHS). Twelve seats and up ran it off the top and the bottom of the screen,
## its buttons with it; the session's standings beside sixteen long names off its sides.
func _fit_plate() -> void:
	var room := _plate.get_viewport_rect().size - Vector2.ONE * 2.0 * PLATE_MARGIN
	for density: Vector3i in DENSITIES:
		_set_density(density)
		_fit_names(NAME_WIDTH)
		if _plate.get_combined_minimum_size().y <= room.y:
			break
	for width: float in NAME_WIDTHS:
		_fit_names(width)
		if _plate.get_combined_minimum_size().x <= room.x:
			break


## Sets the standings as [param density] says (DENSITIES).
func _set_density(density: Vector3i) -> void:
	for grid: GridContainer in [_table, _session_table]:
		grid.add_theme_constant_override("v_separation", density.y)
		for cell: Node in grid.get_children():
			(cell as Label).add_theme_font_size_override("font_size", density.x)
	_session.add_theme_constant_override("separation", density.y)
	_box.add_theme_constant_override("separation", density.z)


## Cuts every name on the plate to [param width] pixels.
func _fit_names(width: float) -> void:
	for cell: Label in _named:
		cell.text = UiTheme.fit(
			_named[cell],
			cell.get_theme_font(&"font"),
			cell.get_theme_font_size(&"font_size"),
			width
		)


## A cell of [param grid] for the name [param seat_name], shown as the server sent it
## and cut to fit by _fit_plate.
func _name_cell(grid: GridContainer, seat_name: String, colour: Color) -> void:
	var cell := _cell_in(grid, seat_name, colour)
	cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_named[cell] = seat_name


func _cell(text: String, colour: Color) -> Label:
	return _cell_in(_table, text, colour)


func _cell_in(grid: GridContainer, text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colour)
	grid.add_child(label)
	return label
