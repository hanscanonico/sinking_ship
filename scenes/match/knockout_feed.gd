class_name KnockoutFeed
extends CanvasLayer
## Who went into the sea, top right under the inclinometer's dials: a line per
## SEAT_OUT, "Bot 2 shoved Bot 5 into the sea" when a shove has the credit, "Bot 5
## went into the sea" when none has, "Bot 5 went down with her" when it was inside her
## as she went — "You" when the local seat is either — the
## newest at the bottom, at most MAX_LINES, each fading out once it has stood
## LINE_SECONDS. Read from every stepped tick's events (SimDriver.stepped), so a
## hitch never eats one and nothing is posted twice; a replay sought clears it.

## The most lines standing at once: a newer one pushes the oldest off.
const MAX_LINES := 4
## How long a line stands before it is gone, and the last part of it it fades over.
const LINE_SECONDS := 5.0
const FADE_SECONDS := 1.0
## The widest the feed shows a seat's name, in pixels: a server's may be far longer.
const NAME_WIDTH := 130.0
## Off the canvas's right edge, and under the dials (FirstPersonHud.DIALS).
const MARGIN := 18.0
const WIDTH := 420.0

var _names := PackedStringArray()
var _own_seat := -1
var _box := VBoxContainer.new()
## Each standing line's age in seconds, by its label.
var _ages: Dictionary[Label, float] = {}


func _ready() -> void:
	UiTheme.apply_to(self)
	_box.name = "Lines"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_box.offset_left = -MARGIN - WIDTH
	_box.offset_right = -MARGIN
	_box.offset_top = FirstPersonHud.DIALS.y + MARGIN
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_box)


## A new match or replay: [param names] labels each seat, as the results do, and
## [param own_seat] is the one said as "You".
func setup(names: PackedStringArray, own_seat: int) -> void:
	_own_seat = own_seat
	_names = PackedStringArray()
	for seat_name in names:
		_names.append(seat_name)
	clear()


## Posts a line for each SEAT_OUT in [param events].
func add(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.SEAT_OUT:
			_post(feed_line(_fitted(), event.seat, event.credit, _own_seat, event.cause))


## Every line taken down.
func clear() -> void:
	for label: Label in _ages.keys():
		_drop(label)


## The feed's line for [param out_seat] going out by [param cause]: into the sea, with
## [param credit] the seat whose shove sent it, or -1 — or down with her, inside her as
## she went, whoever shoved it last; [param own_seat] is said as "You". [param names]
## labels each seat.
static func feed_line(
	names: PackedStringArray,
	out_seat: int,
	credit: int,
	own_seat: int,
	cause := PlayerState.Cause.COLD
) -> String:
	var gone := "You" if out_seat == own_seat else names[out_seat]
	if cause == PlayerState.Cause.WITH_HER:
		return "%s went down with her" % gone
	if credit < 0:
		return "%s went into the sea" % gone
	var shover := "You" if credit == own_seat else names[credit]
	var shoved := "you" if out_seat == own_seat else names[out_seat]
	return "%s shoved %s into the sea" % [shover, shoved]


func _process(delta: float) -> void:
	for label: Label in _ages.keys():
		var age: float = _ages[label] + delta
		if age >= LINE_SECONDS:
			_drop(label)
			continue
		_ages[label] = age
		label.modulate.a = clampf((LINE_SECONDS - age) / FADE_SECONDS, 0.0, 1.0)


func _post(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.HUD_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	_ages[label] = 0.0
	while _ages.size() > MAX_LINES:
		_drop(_box.get_child(0) as Label)


func _drop(label: Label) -> void:
	_ages.erase(label)
	_box.remove_child(label)
	label.free()


## The names cut to NAME_WIDTH in the lines' font.
func _fitted() -> PackedStringArray:
	var font := _box.get_theme_font(&"font", &"Label")
	var size := _box.get_theme_font_size(&"font_size", &"Label")
	var fitted := PackedStringArray()
	for seat_name in _names:
		fitted.append(UiTheme.fit(seat_name, font, size, NAME_WIDTH))
	return fitted
