class_name Hud
extends CanvasLayer
## Seats left, the match clock and the countdown, read from the latest snapshot,
## with what the match is played for and what to press under the countdown; and,
## once the local seat is out — or all match long for a watcher — whose eyes the view is
## in, none of it over the results. The tilt is the first-person HUD's inclinometer.

## How long "Go!" stays up once the countdown is over.
const GO_SECONDS := 0.8
## The least the hints for play keep clear of each side of the window (show_controls).
const CONTROLS_MARGIN := 48.0
## The widest the banner shows a seat's name, in pixels: a server's may be far longer.
const NAME_WIDTH := 130.0
## How far the spectating line keeps off the readouts' plate either side of it and
## off a shove's wedge on the bottom edge under it (FirstPersonHud), in pixels.
const SPECTATING_CLEAR := 12.0
## Whose view the spectating line names from the free camera: nobody's.
const FREE_VIEW := "free camera"
## Whose view it names from the ghost (GhostWalk): nobody's.
const GHOST_VIEW := "ghost"

## The views a watcher may look from (watching_text): a seat's eyes, the free camera or
## the ghost.
enum Camera { EYES, FREE, GHOST }

var _countdown_ticks: int

@onready var _seats_left: Label = %SeatsLeft
@onready var _clock: Label = %Clock
@onready var _countdown: Label = %Countdown
@onready var _spectating: Label = %Spectating
@onready var _controls: Label = %Controls
@onready var _goal: Label = %Goal


func _ready() -> void:
	UiTheme.apply_to(self)
	for label: Label in [_seats_left, _clock]:
		label.theme_type_variation = UiTheme.HUD_LABEL
	_place_spectating()


func setup(sim: MatchSim) -> void:
	_countdown_ticks = sim.config.countdown_ticks
	_goal.text = goal_text(sim.config.goal)


func show_snapshot(snapshot: Dictionary) -> void:
	var seats: Array = snapshot["seats"]
	var left := 0
	for entry: Dictionary in seats:
		if not entry["out"]:
			left += 1
	_seats_left.text = Language.t("Seats left %d / %d") % [left, seats.size()]
	_clock.text = MatchTranscript.clock(snapshot["tick"])
	var ended: bool = snapshot["phase"] == MatchState.Phase.ENDED
	_seats_left.visible = not ended
	_clock.visible = not ended
	_show_countdown(snapshot["tick"])
	_goal.visible = _countdown.visible


## What a seat plays for under [param goal] (MatchRules.Goal), in the end screen's
## words (EndOverlay): to be the last one dry, or to last as long as she does.
static func goal_text(goal: MatchRules.Goal) -> String:
	if goal == MatchRules.Goal.SURVIVAL:
		return "Stay aboard as long as she floats."
	return "Be the last one dry. Shove rivals into the sea."


## Whose view the spectating line names: [param name]'s eyes from a seat's view,
## [param name] watched from the observer camera — or, when [param own], the local
## seat's own (a capture may look through another seat while its own plays on).
static func whose_view(name: String, own: bool, observer: bool) -> String:
	if observer:
		return Language.t("watching you") if own else Language.t("watching %s") % name
	if own:
		return Language.t("through your own eyes")
	return Language.t("through %s's eyes") % name


## How a seat out of the match went, as the spectating line and the results' title say
## it: sunk when it was inside her as she went ([param cause]); frozen when the cold put
## it out [param aboard], inside one of her rooms (SeatRoom), which it never left; else
## overboard — each a word no wider than overboard, as the line has no room for more.
static func out_word(cause: PlayerState.Cause, aboard := false) -> String:
	if cause == PlayerState.Cause.WITH_HER:
		return Language.t("Sunk")
	return Language.t("Frozen" if aboard else "Overboard")


## The spectating line: how the local seat went out by [param cause], inside one of her
## rooms when [param aboard] (out_word), its
## [param place] of [param seats] and [param whose] view it is (whose_view) over what
## switches the view, [param previous] and [param next] — the prompts on a line of
## their own, as long as a pad's are — and, when [param free_key] names one, the key
## into the free camera, or back out of it to the eyes while [param free] says the view
## is the free camera; from it, on a line of its own, [param follow_key] (follow_text);
## and last, when [param ghost_key] names one, the key into the ghost, or back out of it
## while [param ghost] says the view is the ghost's (ghost_text).
static func spectating_text(
	place: String,
	seats: int,
	whose: String,
	previous: String,
	next: String,
	free_key := "",
	free := false,
	cause := PlayerState.Cause.COLD,
	follow_key := "",
	following := false,
	ghost_key := "",
	ghost := false,
	aboard := false
) -> String:
	if free:
		whose = Language.t(FREE_VIEW)
	elif ghost:
		whose = Language.t(GHOST_VIEW)
	var text := (
		Language.t("%s — %s of %d   ·   %s\n%s / %s to switch")
		% [out_word(cause, aboard), place, seats, whose, previous, next]
	)
	if not free_key.is_empty():
		text += "   ·   %s %s" % [free_key, Language.t("eyes" if free else "free camera")]
	return text + _last_line(free, follow_key, following, ghost_key, ghost)


## What [param ghost_key] does: into the ghost, or back to the eyes while [param ghost].
static func ghost_text(ghost_key: String, ghost: bool) -> String:
	return "%s %s" % [ghost_key, Language.t("eyes" if ghost else "ghost")]


## The spectating and the watcher's lines' last: from the free camera ([param free]) its
## [param follow_key] (follow_text), and [param ghost_key] when it names one (ghost_text);
## empty for neither, else on a line of its own.
static func _last_line(
	free: bool, follow_key: String, following: bool, ghost_key: String, ghost: bool
) -> String:
	var keys := PackedStringArray()
	if free and not follow_key.is_empty():
		keys.append(follow_text(follow_key, following))
	if not ghost_key.is_empty():
		keys.append(ghost_text(ghost_key, ghost))
	return "" if keys.is_empty() else "\n" + "   ·   ".join(keys)


## What [param follow_key] does from the free camera: has it follow the seat watched, or
## lets go of it while [param following].
static func follow_text(follow_key: String, following: bool) -> String:
	return "%s %s" % [follow_key, Language.t("let go" if following else "follow")]


## The watcher's line (GLOSSARY: Watch), along the bottom all match long: whose view it
## is from [param camera] — [param seat_name]'s eyes, or the free camera, following that
## seat while [param following] says so —, then what switches the seat, [param previous]
## and [param next], and what flies the free camera, [param free_key], as the spectating
## line has them, and last, from the free camera, [param follow_key] (follow_text), and
## what walks the ghost, [param ghost_key] (ghost_text).
static func watching_text(
	seat_name: String,
	camera: Camera,
	following: bool,
	previous: String,
	next: String,
	free_key: String,
	follow_key: String,
	ghost_key := ""
) -> String:
	var free := camera == Camera.FREE
	var ghost := camera == Camera.GHOST
	var whose := whose_view(seat_name, false, false)
	if free:
		whose = Language.t("following %s") % seat_name if following else Language.t(FREE_VIEW)
	elif ghost:
		whose = Language.t(GHOST_VIEW)
	var text := (
		Language.t("Watching   ·   %s\n%s / %s to switch   ·   %s %s")
		% [whose, previous, next, free_key, Language.t("eyes" if free else "free camera")]
	)
	return text + _last_line(free, follow_key, following, ghost_key, ghost)


## [param text] along the bottom of the screen; empty hides it.
func show_spectating(text: String) -> void:
	_spectating.text = text
	_spectating.visible = not text.is_empty()


## [param seat_name] as the banner along the bottom shows it.
func fit_name(seat_name: String) -> String:
	var font := _spectating.get_theme_font(&"font")
	return UiTheme.fit(seat_name, font, _spectating.get_theme_font_size(&"font_size"), NAME_WIDTH)


## [param prompts]' hint line for play under the countdown while it shows, read only
## then; null hides it.
func show_controls(prompts: InputPrompts) -> void:
	_controls.visible = _countdown.visible and prompts != null
	if _controls.visible:
		var font := _controls.get_theme_font(&"font")
		var font_size := _controls.get_theme_font_size(&"font_size")
		var width := _controls.get_viewport_rect().size.x - 2.0 * CONTROLS_MARGIN
		_controls.text = controls_text(prompts.controls(), font, font_size, width)


## [param line], the hints for play (InputPrompts.controls), as lines no wider than
## [param width] in [param font] at [param font_size], broken between two hints as the
## replay's are (ReplayHud.hint_text): Spanish on a keyboard stood edge to edge in the
## narrowest window, and a longer key's name ran off both sides. Of two lines neither
## is left much the shorter.
static func controls_text(line: String, font: Font, font_size: int, width: float) -> String:
	var said := line.split(ReplayHud.SEPARATOR)
	var text := ReplayHud.hint_text(said, font, font_size, width)
	# As few lines, and those as even as they come: no last hint left alone under four.
	for tenth in range(5, 10):
		var evener := ReplayHud.hint_text(said, font, font_size, width * tenth / 10.0)
		if evener.count("\n") == text.count("\n"):
			return evener
	return text


## Centres the spectating line over the bottom edge, as spectating_box() has it on
## the narrowest canvas — wider ones only move it right, off the plate.
func _place_spectating() -> void:
	var narrowest := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	var box := spectating_box(narrowest)
	_spectating.offset_left = box.position.x - narrowest.x * 0.5
	_spectating.offset_right = box.end.x - narrowest.x * 0.5
	_spectating.offset_bottom = box.end.y - narrowest.y
	_spectating.offset_top = _spectating.offset_bottom
	_spectating.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spectating.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


## Where the spectating line runs on a canvas of [param size]: centred, as wide as
## clears the readouts' plate either side, its last line standing over a wedge's
## arrow on the bottom edge, and its lines — a long name wraps onto one more —
## growing up from there.
static func spectating_box(size: Vector2) -> Rect2:
	var left := FirstPersonHud.plate_rect(size).end.x + SPECTATING_CLEAR
	var bottom := size.y - FirstPersonHud.behind_arrow_reach() - SPECTATING_CLEAR
	return Rect2(left, bottom, size.x - left * 2.0, 0.0)


## Whole seconds left while the sim holds the brawl, then "Go!" for a moment.
func _show_countdown(tick: int) -> void:
	var left := _countdown_ticks - tick
	if left > 0:
		_countdown.text = str(ceili(Ticks.to_seconds(left)))
	elif _countdown_ticks > 0 and -left < Ticks.from_seconds(GO_SECONDS):
		_countdown.text = "Go!"
	else:
		_countdown.text = ""
	_countdown.visible = not _countdown.text.is_empty()
