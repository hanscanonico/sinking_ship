class_name FirstPersonHud
extends CanvasLayer
## What the elevated view used to show at a glance, from a seat's eyes (D14, R10):
## a crosshair that lights when ShoveResolver.would_hit says a shove now would land
## (D13), the inclinometer, the room or deck the seat stands in, the height above the
## sea, the stamina and cold slots, an arc at the screen's edge for a shove winding up
## beside or behind, and a chevron, a ring and a name over every brawler in sight
## within CHEVRON_RANGE — the ring its stamina, or its cold meter in the sea. In the
## sea the cold meter also frames the screen as it empties, and a prompt says when
## pressing on would climb out (Surfaces.climb_out). The sinking is heard before it is
## seen: a flashing chip over the crosshair for every telegraph running — a lurch, a
## deck giving way — and a banner naming each phase as it begins. All of it reads the
## snapshot, SinkSchedule's pose, Surfaces, the ship's rooms and the bodies as drawn
## (D5). From the observer camera only the inclinometer, the sinking's chips and
## banner, and where the watched seat stands show.

## How far away a brawler still gets its chevron, in metres.
const CHEVRON_RANGE := 15.0
## How far over the top of a body its chevron floats, in metres.
const CHEVRON_LIFT := 0.5
## The highest a chevron is drawn, in pixels from the top, clear of the clock: a
## body at contact range keeps its chevron rather than losing it off the screen.
const CHEVRON_TOP := 64.0
const FONT_SIZE := 18
const TEXT := Color(1.0, 1.0, 1.0)
const INK := Color(0.06, 0.09, 0.13, 0.9)
## Past the grip angle, the deck pulls: the inclinometer warns.
const STEEP := Color(1.0, 0.72, 0.2)
## Under a metre to the sea: the height readout warns.
const LOW := Color(1.0, 0.3, 0.25)
const STAMINA := Color(0.55, 0.9, 0.45)
## Run dry, stamina stays red until it is full again.
const EXHAUSTED := Color(0.95, 0.3, 0.25)
const COLD := Color(0.55, 0.8, 1.0)
## Under this share of a full meter, the cold slot and its ring turn red.
const COLD_LOW := 0.35
## The frame the emptying cold meter draws round the screen: its widest, in pixels.
const FRAME_WIDTH := 60.0
const FRAME := Color(0.75, 0.9, 1.0, 0.45)
const AIM := Color(1.0, 1.0, 1.0, 0.75)
const AIM_LIT := Color(1.0, 0.85, 0.3)
const DIAL_RADIUS := 30.0
## A stamina ring round a chevron.
const RING_RADIUS := 13.0
const RING_WIDTH := 3.0
## Half the width of a windup arc, in radians round the screen.
const ARC_HALF := 0.3
## How wide a line of text may run under a dial, and elsewhere.
const DIAL_TEXT := 130.0
const READOUT_TEXT := 240.0
## A telegraph's chip: red, blinking BLINK_TICKS on and off.
const WARNING := Color(1.0, 0.25, 0.2)
const BLINK_TICKS := 6
const CHIP_TEXT := 420.0
## How long a phase's name stays up once it begins.
const BANNER_SECONDS := 4.0
const BANNER_FONT_SIZE := 30

var _schedule: SinkSchedule
## Its own, honoured with the pose of the tick it draws: what a climb or a shove
## meets is the ship as that pose has it, and the sim's stays the sim's.
var _surfaces: Surfaces
var _rules: BrawlRules
var _ship: ShipLayout
var _names := PackedStringArray()
var _eyes: bool
var _canvas: Control
var _font: Font
var _snapshot: Dictionary
var _seat := -1
var _yaw: float
var _camera: Camera3D
var _view: MatchView
var _prompts: InputPrompts


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_hud)


## [param eyes] is whether the view is a seat's eyes rather than the observer's;
## [param prompts] names the buttons a warning asks for.
func setup(sim: MatchSim, names: PackedStringArray, eyes: bool, prompts: InputPrompts) -> void:
	_schedule = sim.schedule
	_surfaces = Surfaces.new(sim.config.ship)
	_rules = sim.config.rules
	_ship = sim.config.ship
	_names = names
	_eyes = eyes
	_prompts = prompts
	_snapshot = {}


## Draws the HUD of [param seat]'s eyes over [param snapshot], looking along the
## ship-plane [param yaw] through [param camera], over the bodies [param view] draws.
func show_view(
	snapshot: Dictionary, seat: int, yaw: float, camera: Camera3D, view: MatchView
) -> void:
	_snapshot = snapshot
	_seat = seat
	_yaw = yaw
	_camera = camera
	_view = view
	_canvas.queue_redraw()


func _draw_hud() -> void:
	if _snapshot.is_empty():
		return
	var tick: int = _snapshot["tick"]
	var pose := _schedule.pose_at(tick)
	_surfaces.honour(pose)
	_draw_inclinometer(pose)
	_draw_warnings(pose, tick)
	_draw_phase(tick)
	var me := _entry(_seat)
	if me.is_empty() or me["out"]:
		return
	_draw_where(me["pos"], me["surface"])
	if not _eyes:
		return
	_draw_crosshair(ShoveResolver.would_hit(_snapshot, _seat, _rules, _surfaces))
	if me["state"] == PlayerState.Body.SWIMMING:
		_draw_cold_frame(me)
		_draw_climb_prompt(me, pose)
	_draw_readouts(me, pose.world_height(me["pos"]))
	_draw_chevrons(me["pos"])
	_draw_windup_arcs(me["pos"])


## Two dials, top right: the heel as the hull seen from astern (starboard on the
## right) and the trim as the hull seen from starboard (the bow on the right), each
## against a level line, signed and naming the low side.
func _draw_inclinometer(pose: ShipPose) -> void:
	var colour := STEEP if pose.slope_deg() > _rules.grip_angle_deg else TEXT
	var width := _canvas.size.x
	var heel_at := Vector2(width - 215.0, 60.0)
	var trim_at := Vector2(width - 80.0, 60.0)
	var r := DIAL_RADIUS
	var section := PackedVector2Array(
		[
			Vector2(-r * 0.8, 0.0),
			Vector2(-r * 0.55, r * 0.45),
			Vector2(r * 0.55, r * 0.45),
			Vector2(r * 0.8, 0.0),
			Vector2(-r * 0.8, 0.0),
		]
	)
	var profile := PackedVector2Array(
		[
			Vector2(-r * 0.8, -r * 0.05),
			Vector2(-r * 0.7, r * 0.3),
			Vector2(r * 0.6, r * 0.3),
			Vector2(r * 0.9, -r * 0.05),
			Vector2(-r * 0.8, -r * 0.05),
		]
	)
	_draw_dial(heel_at, section, deg_to_rad(pose.heel_deg), colour)
	_draw_dial(trim_at, profile, deg_to_rad(pose.trim_deg), colour)
	var below := Vector2(0.0, r + 22.0)
	var under := Vector2(0.0, r + 42.0)
	_text(heel_at + below, "Heel %+.1f°" % pose.heel_deg, colour, DIAL_TEXT)
	_text(heel_at + under, _low(pose.heel_deg, "starboard", "port"), colour, DIAL_TEXT)
	_text(trim_at + below, "Trim %+.1f°" % pose.trim_deg, colour, DIAL_TEXT)
	_text(trim_at + under, _low(pose.trim_deg, "bow", "stern"), colour, DIAL_TEXT)


func _draw_dial(centre: Vector2, hull: PackedVector2Array, angle: float, colour: Color) -> void:
	_canvas.draw_circle(centre, DIAL_RADIUS + 4.0, INK)
	_canvas.draw_arc(centre, DIAL_RADIUS, 0.0, TAU, 32, Color(colour, 0.5), 1.5, true)
	var level := Vector2(DIAL_RADIUS, 0.0)
	_canvas.draw_line(centre - level, centre + level, Color(TEXT, 0.35), 1.0, true)
	var drawn := PackedVector2Array()
	for point: Vector2 in hull:
		drawn.append(centre + point.rotated(angle))
	_canvas.draw_polyline(drawn, colour, 2.5, true)
	var mast := Vector2(0.0, -DIAL_RADIUS * 0.6).rotated(angle)
	_canvas.draw_line(centre, centre + mast, colour, 2.0, true)


## Over the crosshair, one chip per telegraph [param pose] runs — what a player who
## cannot see the whole ship must not miss — blinking with [param tick].
func _draw_warnings(pose: ShipPose, tick: int) -> void:
	var warnings := PackedStringArray()
	if pose.lurch_warning != 0.0:
		var side := "STARBOARD" if pose.lurch_warning > 0.0 else "PORT"
		warnings.append("LURCH TO %s — BRACE (%s)" % [side, _prompts.word(&"brace")])
	for going: StringName in pose.collapsing:
		warnings.append("THE %s IS GOING" % String(going).to_upper())
	if warnings.is_empty() or tick / BLINK_TICKS % 2 == 1:
		return
	var at := Vector2(_canvas.size.x * 0.5, _canvas.size.y * 0.5 - 90.0)
	for warning: String in warnings:
		var chip := Rect2(at - Vector2(CHIP_TEXT * 0.5, 24.0), Vector2(CHIP_TEXT, 34.0))
		_canvas.draw_rect(chip, INK)
		_canvas.draw_rect(chip, WARNING, false, 2.5)
		_text(at, warning, WARNING, CHIP_TEXT)
		at.y -= 44.0


## Under the clock, the name of the sinking's phase for BANNER_SECONDS after it
## begins at or before [param tick].
func _draw_phase(tick: int) -> void:
	var phase := _schedule.phase_at(tick)
	if phase == "" or phase == _schedule.phase_at(tick - Ticks.from_seconds(BANNER_SECONDS)):
		return
	var left := Vector2(_canvas.size.x * 0.5 - READOUT_TEXT, 110.0)
	_canvas.draw_string_outline(
		_font,
		left,
		phase,
		HORIZONTAL_ALIGNMENT_CENTER,
		READOUT_TEXT * 2.0,
		BANNER_FONT_SIZE,
		6,
		INK
	)
	_canvas.draw_string(
		_font, left, phase, HORIZONTAL_ALIGNMENT_CENTER, READOUT_TEXT * 2.0, BANNER_FONT_SIZE, TEXT
	)


## A ring with four ticks at the centre of the view, lit while a shove now would land.
func _draw_crosshair(lit: bool) -> void:
	var centre := _canvas.size * 0.5
	var colour := AIM_LIT if lit else AIM
	var gap := 7.0 if lit else 5.0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from := centre + direction * gap
		_canvas.draw_line(from, from + direction * 7.0, INK, 4.0, true)
		_canvas.draw_line(from, from + direction * 7.0, colour, 2.0, true)
	_canvas.draw_circle(centre, 1.5, colour)
	if lit:
		_canvas.draw_arc(centre, 16.0, 0.0, TAU, 32, colour, 2.5, true)


## Bottom left, over the readouts: the name of the room [param feet] stand in, else
## of the platform [param surface] is.
func _draw_where(feet: Vector3, surface: int) -> void:
	var where := ""
	var room := _ship.room_at(feet, _rules.step_height)
	if room != -1:
		where = _ship.rooms[room].name
	elif surface >= 0 and surface < _ship.platforms.size():
		where = _ship.platforms[surface].name
	var at := Vector2(24.0, _canvas.size.y - 150.0)
	_text(at, where.capitalize(), TEXT, READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)


## Bottom left: metres from [param me]'s feet down to the sea — or that it is in
## it — then the stamina and cold slots, filled from [param me].
func _draw_readouts(me: Dictionary, above_sea: float) -> void:
	var at := Vector2(24.0, _canvas.size.y - 120.0)
	var colour := LOW if above_sea < 1.0 else TEXT
	var height := "%.1f m above the sea" % above_sea
	if me["state"] == PlayerState.Body.SWIMMING:
		height = "In the sea"
	_text(at, height, colour, READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	for slot: String in ["Stamina", "Cold"]:
		at.y += 30.0
		_text(at, slot, Color(TEXT, 0.5), READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		var bar := Rect2(at + Vector2(80.0, -13.0), Vector2(140.0, 14.0))
		_canvas.draw_rect(bar, INK)
		var share := _stamina(me) if slot == "Stamina" else _cold(me)
		var fill := _stamina_colour(me) if slot == "Stamina" else _cold_colour(me)
		_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), fill)
		_canvas.draw_rect(bar, Color(TEXT, 0.35), false, 1.5)


## A chevron in seat colour, ringed by its stamina, and the seat's name over every
## other brawler within CHEVRON_RANGE that no blocker or deck hides from
## [param my_pos] — never through a wall or a floor.
func _draw_chevrons(my_pos: Vector3) -> void:
	for entry: Dictionary in _snapshot["seats"]:
		var seat: int = entry["seat"]
		if seat == _seat or entry["out"]:
			continue
		var their_pos: Vector3 = entry["pos"]
		if my_pos.distance_to(their_pos) > CHEVRON_RANGE:
			continue
		if _surfaces.blocked(my_pos, their_pos, _rules.body_height, _rules.step_height):
			continue
		if _deck_between(my_pos, their_pos):
			continue
		var over := (
			_view.seat_world_position(seat) + Vector3.UP * (_rules.body_height + CHEVRON_LIFT)
		)
		if _camera.is_position_behind(over):
			continue
		var at := _camera.unproject_position(over)
		at.y = maxf(at.y, CHEVRON_TOP)
		_ring(at, entry)
		var colour := ArtPalette.seat_colour(seat)
		var chevron := PackedVector2Array(
			[at + Vector2(-9.0, -6.0), at + Vector2(9.0, -6.0), at + Vector2(0.0, 5.0)]
		)
		_canvas.draw_colored_polygon(chevron, colour)
		chevron.append(chevron[0])
		_canvas.draw_polyline(chevron, INK, 1.5, true)
		_text(at + Vector2(0.0, -RING_RADIUS - 6.0), _names[seat], colour, READOUT_TEXT)


## [param entry]'s stamina — its cold meter in the sea — as a ring round
## [param centre], filled clockwise from the top.
func _ring(centre: Vector2, entry: Dictionary) -> void:
	_canvas.draw_arc(centre, RING_RADIUS, 0.0, TAU, 32, INK, RING_WIDTH, true)
	var swimming: bool = entry["state"] == PlayerState.Body.SWIMMING
	var share := _cold(entry) if swimming else _stamina(entry)
	if share > 0.0:
		var top := -PI * 0.5
		_canvas.draw_arc(
			centre,
			RING_RADIUS,
			top,
			top + TAU * share,
			32,
			_cold_colour(entry) if swimming else _stamina_colour(entry),
			RING_WIDTH,
			true
		)


## Whether a deck hides [param b] from [param a]: they stand a storey or more apart
## and either is indoors. Surfaces.blocked sees the walls between rooms, never the
## deck between a room and the floor over it.
func _deck_between(a: Vector3, b: Vector3) -> bool:
	if absf(a.y - b.y) < _rules.body_height:
		return false
	return _ship.room_at(a, _rules.step_height) != -1 or _ship.room_at(b, _rules.step_height) != -1


## An arc at the screen's edge, toward each seat outside the field of view that
## winds up, charges or throws a shove close enough to land on [param my_pos] before its
## active window ends — its reach plus a walk through windup and active.
func _draw_windup_arcs(my_pos: Vector3) -> void:
	var reach := (
		_rules.shove_reach + _rules.walk_speed * (_rules.shove_windup + _rules.shove_active)
	)
	var half_view := deg_to_rad(_camera.fov * 0.5)
	var centre := _canvas.size * 0.5
	var radius := minf(centre.x, centre.y) * 0.9
	for entry: Dictionary in _snapshot["seats"]:
		if entry["seat"] == _seat or entry["out"]:
			continue
		var action: PlayerState.Action = entry["action"]
		if action == PlayerState.Action.IDLE or action == PlayerState.Action.RECOVERY:
			continue
		var their_pos: Vector3 = entry["pos"]
		var offset := Vector2(their_pos.x - my_pos.x, their_pos.z - my_pos.z)
		if offset.length() - _rules.body_radius * 2.0 > reach:
			continue
		if absf(their_pos.y - my_pos.y) >= _rules.body_height:
			continue
		var bearing := angle_difference(_yaw, offset.angle())
		if absf(bearing) <= half_view:
			continue
		var around := bearing - PI * 0.5
		var colour := ArtPalette.seat_colour(entry["seat"])
		_canvas.draw_arc(centre, radius, around - ARC_HALF, around + ARC_HALF, 24, INK, 14.0, true)
		_canvas.draw_arc(
			centre, radius, around - ARC_HALF, around + ARC_HALF, 24, colour, 9.0, true
		)


## [param text] on a baseline at [param at], centred in [param width] unless
## [param align] says left.
func _text(
	at: Vector2,
	text: String,
	colour: Color,
	width: float,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	var left := at - Vector2(width * 0.5, 0.0) if align == HORIZONTAL_ALIGNMENT_CENTER else at
	_canvas.draw_string_outline(_font, left, text, align, width, FONT_SIZE, 5, INK)
	_canvas.draw_string(_font, left, text, align, width, FONT_SIZE, colour)


## A frame round the screen, wider and more opaque the emptier [param me]'s cold
## meter is.
func _draw_cold_frame(me: Dictionary) -> void:
	var empty := 1.0 - _cold(me)
	var width := FRAME_WIDTH * empty
	if width <= 0.0:
		return
	var size := _canvas.size
	var colour := Color(FRAME, FRAME.a * empty)
	for side: Rect2 in [
		Rect2(0.0, 0.0, size.x, width),
		Rect2(0.0, size.y - width, size.x, width),
		Rect2(0.0, width, width, size.y - width * 2.0),
		Rect2(size.x - width, width, width, size.y - width * 2.0),
	]:
		_canvas.draw_rect(side, colour)


## Under the crosshair, while [param me] swims and pressing on where it looks would
## start a climb out: the move-forward key by the layout's label, Z on AZERTY.
func _draw_climb_prompt(me: Dictionary, pose: ShipPose) -> void:
	if me["climb"] > 0 or me["stagger"] > 0:
		return
	if _surfaces.climb_out(me["pos"], Vector2.from_angle(_yaw), pose, _rules) == null:
		return
	var at := _canvas.size * 0.5 + Vector2(0.0, 70.0)
	_text(at, "Hold %s to climb" % _prompts.word(&"move_up"), TEXT, READOUT_TEXT)


## [param entry]'s cold meter, as a share of a full one.
func _cold(entry: Dictionary) -> float:
	return entry["cold"] / _rules.cold_meter


func _cold_colour(entry: Dictionary) -> Color:
	return LOW if _cold(entry) < COLD_LOW else COLD


## [param entry]'s stamina, as a share of the most there is.
func _stamina(entry: Dictionary) -> float:
	return entry["stamina"] / _rules.stamina_max


func _stamina_colour(entry: Dictionary) -> Color:
	return EXHAUSTED if entry["exhausted"] else STAMINA


func _entry(seat: int) -> Dictionary:
	for entry: Dictionary in _snapshot["seats"]:
		if entry["seat"] == seat:
			return entry
	return {}


static func _low(signed_deg: float, positive: String, negative: String) -> String:
	if absf(signed_deg) < 0.05:
		return "level"
	return "%s low" % (positive if signed_deg > 0.0 else negative)
