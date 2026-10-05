class_name Hud
extends CanvasLayer
## Seats left, the match clock and the countdown, read from the latest snapshot,
## with what to press under the countdown; and, once the local seat is out, whose
## eyes the view is in — none of it over the results. The tilt is the first-person
## HUD's inclinometer.

## How long "Go!" stays up once the countdown is over.
const GO_SECONDS := 0.8
## The widest the banner shows a seat's name, in pixels: a server's may be far longer.
const NAME_WIDTH := 130.0
## How far the spectating line keeps off the readouts' plate either side of it and
## off a shove's wedge on the bottom edge under it (FirstPersonHud), in pixels.
const SPECTATING_CLEAR := 12.0

var _countdown_ticks: int

@onready var _seats_left: Label = %SeatsLeft
@onready var _clock: Label = %Clock
@onready var _countdown: Label = %Countdown
@onready var _spectating: Label = %Spectating
@onready var _controls: Label = %Controls


func _ready() -> void:
	UiTheme.apply_to(self)
	for label: Label in [_seats_left, _clock]:
		label.theme_type_variation = UiTheme.HUD_LABEL
	_place_spectating()


func setup(sim: MatchSim) -> void:
	_countdown_ticks = sim.config.countdown_ticks


func show_snapshot(snapshot: Dictionary) -> void:
	var seats: Array = snapshot["seats"]
	var left := 0
	for entry: Dictionary in seats:
		if not entry["out"]:
			left += 1
	_seats_left.text = "Seats left %d / %d" % [left, seats.size()]
	_clock.text = MatchTranscript.clock(snapshot["tick"])
	var ended: bool = snapshot["phase"] == MatchState.Phase.ENDED
	_seats_left.visible = not ended
	_clock.visible = not ended
	_show_countdown(snapshot["tick"])


## Whose view the spectating line names: [param name]'s eyes from a seat's view,
## [param name] watched from the observer camera — or, when [param own], the local
## seat's own (a capture may look through another seat while its own plays on).
static func whose_view(name: String, own: bool, observer: bool) -> String:
	if observer:
		return "watching you" if own else "watching %s" % name
	return "through your own eyes" if own else "through %s's eyes" % name


## The spectating line: the local seat's [param place] of [param seats] and
## [param whose] view it is (whose_view) over what switches the view, [param previous]
## and [param next] — the prompts on a line of their own, as long as a pad's are.
static func spectating_text(
	place: String, seats: int, whose: String, previous: String, next: String
) -> String:
	return (
		"Overboard — %s of %d   ·   %s\n%s / %s to switch" % [place, seats, whose, previous, next]
	)


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
		_controls.text = prompts.controls()


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
