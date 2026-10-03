class_name FirstPersonHud
extends CanvasLayer
## What the elevated view used to show at a glance, from a seat's eyes (D14, R10):
## a crosshair that lights when ShoveResolver.would_hit says a shove now would land
## (D13), the inclinometer, the height above the sea, the stamina and cold slots,
## an arc at the screen's edge for a shove winding up beside or behind, and a
## chevron and a name over every brawler in sight within CHEVRON_RANGE. All of it
## reads the snapshot, SinkSchedule's pose, Surfaces and the bodies as drawn (D5).
## From the observer camera only the inclinometer shows.

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
const AIM := Color(1.0, 1.0, 1.0, 0.75)
const AIM_LIT := Color(1.0, 0.85, 0.3)
const DIAL_RADIUS := 30.0
## Half the width of a windup arc, in radians round the screen.
const ARC_HALF := 0.3
## How wide a line of text may run under a dial, and elsewhere.
const DIAL_TEXT := 130.0
const READOUT_TEXT := 240.0

var _schedule: SinkSchedule
var _surfaces: Surfaces
var _rules: BrawlRules
var _names := PackedStringArray()
var _eyes: bool
var _canvas: Control
var _font: Font
var _snapshot: Dictionary
var _seat := -1
var _yaw: float
var _camera: Camera3D
var _view: MatchView


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_hud)


## [param eyes] is whether the view is a seat's eyes rather than the observer's.
func setup(sim: MatchSim, names: PackedStringArray, eyes: bool) -> void:
	_schedule = sim.schedule
	_surfaces = sim.surfaces
	_rules = sim.config.rules
	_names = names
	_eyes = eyes
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
	var pose := _schedule.pose_at(_snapshot["tick"])
	_draw_inclinometer(pose)
	if not _eyes:
		return
	var me := _entry(_seat)
	if me.is_empty() or me["out"]:
		return
	_draw_crosshair(ShoveResolver.would_hit(_snapshot, _seat, _rules, _surfaces))
	_draw_readouts(pose.world_height(me["pos"]))
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


## Bottom left: metres from the feet down to the sea, then the stamina and cold
## slots, empty until SH4 and SH5 fill them.
func _draw_readouts(above_sea: float) -> void:
	var at := Vector2(24.0, _canvas.size.y - 120.0)
	var colour := LOW if above_sea < 1.0 else TEXT
	_text(at, "%.1f m above the sea" % above_sea, colour, READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	for slot: String in ["Stamina", "Cold"]:
		at.y += 30.0
		_text(at, slot, Color(TEXT, 0.5), READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		var bar := Rect2(at + Vector2(80.0, -13.0), Vector2(140.0, 14.0))
		_canvas.draw_rect(bar, INK)
		_canvas.draw_rect(bar, Color(TEXT, 0.35), false, 1.5)


## A chevron in seat colour and the seat's name over every other brawler within
## CHEVRON_RANGE that no blocker hides from [param my_pos] — never through a wall.
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
		var over := (
			_view.seat_world_position(seat) + Vector3.UP * (_rules.body_height + CHEVRON_LIFT)
		)
		if _camera.is_position_behind(over):
			continue
		var at := _camera.unproject_position(over)
		at.y = maxf(at.y, CHEVRON_TOP)
		var colour := ArtPalette.seat_colour(seat)
		var chevron := PackedVector2Array(
			[at + Vector2(-9.0, -6.0), at + Vector2(9.0, -6.0), at + Vector2(0.0, 5.0)]
		)
		_canvas.draw_colored_polygon(chevron, colour)
		chevron.append(chevron[0])
		_canvas.draw_polyline(chevron, INK, 1.5, true)
		_text(at + Vector2(0.0, -12.0), _names[seat], colour, READOUT_TEXT)


## An arc at the screen's edge, toward each seat outside the field of view that
## winds up or throws a shove close enough to land on [param my_pos] before its
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
		if action != PlayerState.Action.WINDUP and action != PlayerState.Action.ACTIVE:
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


func _entry(seat: int) -> Dictionary:
	for entry: Dictionary in _snapshot["seats"]:
		if entry["seat"] == seat:
			return entry
	return {}


static func _low(signed_deg: float, positive: String, negative: String) -> String:
	if absf(signed_deg) < 0.05:
		return "level"
	return "%s low" % (positive if signed_deg > 0.0 else negative)
