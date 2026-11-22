class_name KnockoutFeed
extends CanvasLayer
## Who went into the sea, top right under the inclinometer's dials: a line per
## SEAT_OUT, "Bot 2 shoved Bot 5 into the sea" when a shove has the credit, "Bot 5
## went into the sea" when none has, "Bot 5 went down with her" when it was inside her
## as she went — "You" when the local seat is either. Beside them the bonuses (#307), each
## line in its kind's colour: one coming aboard, "Double life: engine room" — its kind's
## title, and the room its bonus spot lies in as her layout names it — and one taken,
## "Bot 3 took Double life". The newest at the bottom, at most MAX_LINES, each fading out
## once it has stood LINE_SECONDS. Read from every stepped tick's events
## (SimDriver.stepped), so a hitch never eats one and nothing is posted twice; a replay
## sought clears it.

## The most lines standing at once: a newer one pushes the oldest off.
const MAX_LINES := 4
## How far toward white a bonus's line is written from its kind's mark (ink).
const INK_LIGHTER := 0.3
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
## The match's sim, null for none, and which of its seats went out aboard (feed_line).
var _sim: MatchSim
var _rooms := SeatRoom.new()
## Her layout, whose bonus spots and rooms a bonus's line names, and the kinds the match's
## bonuses may be (BonusRules.kinds): none in a match without bonuses.
var _layout: ShipLayout
var _kinds: Array[BonusKind] = []
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
## [param own_seat] is the one said as "You"; played on [param layout] with
## [param bonus_rules], null for a match without bonuses.
func setup(
	names: PackedStringArray,
	own_seat: int,
	layout: ShipLayout = null,
	bonus_rules: BonusRules = null,
	sim: MatchSim = null
) -> void:
	_sim = sim
	_rooms.forget()
	_own_seat = own_seat
	_names = PackedStringArray()
	for seat_name in names:
		_names.append(seat_name)
	_layout = layout
	_kinds.clear()
	if bonus_rules != null:
		_kinds.assign(bonus_rules.kinds)
	clear()


## Posts a line for each SEAT_OUT in [param events], each bonus come aboard and each one
## taken.
func add(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SEAT_OUT:
				var aboard := _sim != null and _rooms.out_aboard(_sim, _sim.snapshot(), event.seat)
				var line := feed_line(
					_fitted(), event.seat, event.credit, _own_seat, event.cause, aboard
				)
				_post(line)
			SimEvent.Kind.BONUS_CAME:
				var kind := _kinds[event.bonus]
				var room := _layout.rooms[_layout.bonus_spots[event.spot].room].name
				var came := Language.t("%s: %s") % [Language.t(kind.title), Language.named(room)]
				_in_colour(_post(came), kind)
			SimEvent.Kind.BONUS_TAKEN:
				var kind := _kinds[event.bonus]
				var title := Language.t(kind.title)
				var line := (
					Language.t("You took %s") % title
					if event.seat == _own_seat
					else Language.t("%s took %s") % [_fitted()[event.seat], title]
				)
				_in_colour(_post(line), kind)


## Every line taken down.
func clear() -> void:
	for label: Label in _ages.keys():
		_drop(label)


## The feed's line for [param out_seat] going out by [param cause]: into the sea, with
## [param credit] the seat whose shove sent it, or -1 — or down with her, inside her as
## she went, whoever shoved it last; [param own_seat] is said as "You". [param names]
## labels each seat. A seat no shove sent, out [param aboard] — in a room of hers or on
## a deck the water came over (SeatRoom.out_aboard) — went into no sea: the cold got it.
static func feed_line(
	names: PackedStringArray,
	out_seat: int,
	credit: int,
	own_seat: int,
	cause := PlayerState.Cause.COLD,
	aboard := false
) -> String:
	var own_out := out_seat == own_seat
	if cause == PlayerState.Cause.WITH_HER:
		if own_out:
			return Language.t("You went down with her")
		return Language.t("%s went down with her") % names[out_seat]
	if credit < 0 and aboard:
		if own_out:
			return Language.t("The cold got you")
		return Language.t("The cold got %s") % names[out_seat]
	if credit < 0:
		if own_out:
			return Language.t("You went into the sea")
		return Language.t("%s went into the sea") % names[out_seat]
	if own_out:
		return Language.t("%s shoved you into the sea") % names[credit]
	if credit == own_seat:
		return Language.t("You shoved %s into the sea") % names[out_seat]
	return Language.t("%s shoved %s into the sea") % [names[credit], names[out_seat]]


func _process(delta: float) -> void:
	for label: Label in _ages.keys():
		var age: float = _ages[label] + delta
		if age >= LINE_SECONDS:
			_drop(label)
			continue
		_ages[label] = age
		label.modulate.a = clampf((LINE_SECONDS - age) / FADE_SECONDS, 0.0, 1.0)


## Posts [param text]: the newest line, which it returns.
func _post(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.HUD_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	_ages[label] = 0.0
	while _ages.size() > MAX_LINES:
		_drop(_box.get_child(0) as Label)
	return label


## Writes [param line] in the colour of bonus [param kind].
static func _in_colour(line: Label, kind: BonusKind) -> void:
	line.add_theme_color_override(&"font_color", ink(kind))


## The colour a line about bonus [param kind] is written in: its mark, lightened —
## Steady's deep purple on the feed's dark outline could not be read.
static func ink(kind: BonusKind) -> Color:
	return kind.mark.lerp(Color.WHITE, INK_LIGHTER)


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
