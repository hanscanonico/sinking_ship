class_name FirstPersonHud
extends CanvasLayer
## What the elevated view used to show at a glance, from a seat's eyes (D14, R10):
## a crosshair that lights when ShoveResolver.would_hit says a shove now would land
## (D13), the inclinometer, the room or deck the seat stands in, the height above or
## under the sea, the stamina and warmth slots on a plate of their own, a wedge at the
## screen's edge pointing at a shove winding up beside or behind, and a chevron, a
## ring and a name over every brawler in sight within CHEVRON_RANGE — the ring its
## stamina, or its warmth in the sea — kept under the clock and faded off the dials.
## In the sea frost grows in from the screen's edges as the warmth runs out, and a
## prompt says when pressing on would climb out (Surfaces.climb_out). The sinking is
## heard before it is seen: a flashing chip over the crosshair for every telegraph
## running — a lurch, a deck giving way — and a banner naming each phase as it begins.
## All of it reads the snapshot, SinkSchedule's pose, Surfaces, the ship's rooms and
## the bodies as drawn (D5), and none of it stays up over the results. From the
## observer camera only the inclinometer, the sinking's chips and banner, and where the
## watched seat stands show.

const FROST_SHADER := preload("res://scenes/match/frost.gdshader")
## The frost's crystal texture: its side in pixels, and how many crystals across it.
const CRYSTAL_SIZE := 512
const CRYSTAL_CELLS := 9.0
## How far away a brawler still gets its chevron, in metres.
const CHEVRON_RANGE := 15.0
## How far over the top of a body its chevron floats, in metres.
const CHEVRON_LIFT := 0.5
## The highest a chevron is drawn, in pixels from the top: its name clears the clock
## and the seats left, and a body at contact range keeps its chevron rather than
## losing it off the screen.
const CHEVRON_TOP := 90.0
## A chevron at CHEVRON_RANGE is drawn this much of its size, and fades out over the
## last share of the range past FADE_FROM.
const FAR_SCALE := 0.65
const FADE_FROM := 0.8
## A chevron whose name — about NAME_HALF either side of it — reaches over the dials
## is drawn this faint, so their reading stays clear.
const UNDER_DIALS := 0.2
const NAME_HALF := 36.0
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
## The cold meter reads as warmth, lamp-warm until under COLD_LOW of a full meter,
## then FREEZING.
const WARM := ArtPalette.LAMP_LIGHT
const FREEZING := Color(0.62, 0.85, 1.0)
const COLD_LOW := 0.35
## The plate behind the readouts, bottom left.
const PLATE := Color(INK, 0.55)
const PLATE_EDGE := Color(TEXT, 0.12)
const AIM := Color(1.0, 1.0, 1.0, 0.75)
const AIM_LIT := Color(1.0, 0.85, 0.3)
const DIAL_RADIUS := 30.0
## A stamina ring round a chevron.
const RING_RADIUS := 13.0
const RING_WIDTH := 3.0
## A windup wedge: how far along the screen's edge it spreads either side of its root
## and how far in it fades; how far it keeps off the readouts' plate; how far apart
## the wedges on one edge stand; the width of its bright line and of the dark keyline
## under it, so it reads on a pale wall too; its arrowhead's length, half width and
## notch; and how far in from the edge the arrowhead's tip sits, in pixels.
const WEDGE_HALF := 120.0
const WEDGE_DEPTH := 110.0
const WEDGE_CLEAR := 12.0
const WEDGE_SPREAD := 40.0
const WEDGE_ALPHA := 0.9
const WEDGE_LINE := 3.0
const WEDGE_KEYLINE := 7.0
const ARROW_LENGTH := 30.0
const ARROW_HALF := 13.0
const ARROW_NOTCH := 9.0
const ARROW_IN := 8.0
## Past this bearing off the view's middle, in radians, a shove is behind: its wedge
## fades from its side's edge into the bottom edge's, all of it there dead astern.
const BEHIND_FROM := PI * 0.75
## How wide a line of text may run under a dial, and elsewhere.
const DIAL_TEXT := 130.0
const READOUT_TEXT := 240.0
## Where the inclinometer's two dials and their readings sit, from the screen's top
## right corner, in pixels.
const DIALS := Vector2(285.0, 145.0)
## A telegraph's chip: red, blinking BLINK_TICKS on and off.
const WARNING := Color(1.0, 0.25, 0.2)
const BLINK_TICKS := 6
const CHIP_TEXT := 420.0
## How long a phase's name stays up once it begins.
const BANNER_SECONDS := 4.0
const BANNER_FONT_SIZE := 30

var _schedule: SinkSchedule
## Its own, honoured with the pose, broken railings and crates of the snapshot it
## draws: what a climb, a shove or a look meets is the ship as that tick has it, and
## the sim's stays the sim's.
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
var _frost: ColorRect
var _plate := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	# Under the canvas, so the readouts stay legible through the frost.
	_frost = ColorRect.new()
	_frost.name = "Frost"
	var frost := ShaderMaterial.new()
	frost.shader = FROST_SHADER
	frost.set_shader_parameter(&"crystals", _crystals())
	_frost.material = frost
	_frost.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost.hide()
	add_child(_frost)
	_plate.bg_color = PLATE
	_plate.border_color = PLATE_EDGE
	_plate.set_border_width_all(1)
	_plate.set_corner_radius_all(6)
	_plate.anti_aliasing = true
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
	_show_frost()
	_canvas.queue_redraw()


func _draw_hud() -> void:
	if _over():
		return
	var tick: int = _snapshot["tick"]
	var pose := _schedule.pose_at(tick)
	# As the snapshot has them: the railings the match has broken, and its crates.
	_surfaces.honour(
		pose, MatchState.broken_in(_snapshot["railing_hp"]), PropState.from_snapshot(_snapshot)
	)
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
		_draw_climb_prompt(me, pose)
	_draw_readouts(me, pose.world_height(me["pos"]))
	_draw_chevrons(me["pos"], pose)
	_draw_windup_wedges(me["pos"])


## Whether there is nothing to draw: no snapshot yet, or the results are up.
func _over() -> bool:
	return _snapshot.is_empty() or _snapshot["phase"] == MatchState.Phase.ENDED


## Frost in from the screen's edges while the eyes swim, the further the emptier
## their cold meter.
func _show_frost() -> void:
	var cold := 0.0
	var me := {} if _over() or not _eyes else _entry(_seat)
	if not me.is_empty() and not me["out"] and me["state"] == PlayerState.Body.SWIMMING:
		cold = 1.0 - _cold(me)
	_frost.visible = cold > 0.0
	if _frost.visible:
		(_frost.material as ShaderMaterial).set_shader_parameter(&"cold", cold)


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


## Bottom left, over the readouts and on their plate: the name of the room
## [param feet] stand in, else of the platform [param surface] is.
func _draw_where(feet: Vector3, surface: int) -> void:
	var where := ""
	var room := _ship.room_at(feet, _rules.step_height)
	if room != -1:
		where = _ship.rooms[room].name
	elif surface >= 0 and surface < _ship.platforms.size():
		where = _ship.platforms[surface].name
	_draw_plate(not where.is_empty())
	var at := Vector2(24.0, _canvas.size.y - 150.0)
	_text(at, where.capitalize(), TEXT, READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)


## Bottom left, behind what of the readouts shows — the place when [param named],
## and from the eyes the rest of them — a dark plate, so they read over a bright deck.
func _draw_plate(named: bool) -> void:
	var rect := plate_rect(_canvas.size)
	if not named:
		rect = rect.grow_side(SIDE_TOP, -30.0)
	if not _eyes:
		rect.size.y = 32.0 if named else 0.0
	if rect.size.y > 0.0:
		_canvas.draw_style_box(_plate, rect)


## The whole plate behind the readouts on a screen of [param size], bottom left.
static func plate_rect(size: Vector2) -> Rect2:
	return Rect2(12.0, size.y - 172.0, 252.0, 128.0)


## Bottom left: metres from [param me]'s feet to the sea, above or under it — or
## that it is in it — then the stamina and warmth slots, filled from [param me].
func _draw_readouts(me: Dictionary, above_sea: float) -> void:
	var at := Vector2(24.0, _canvas.size.y - 120.0)
	var colour := LOW if above_sea < 1.0 else TEXT
	var height := height_words(above_sea)
	if me["state"] == PlayerState.Body.SWIMMING:
		height = "In the sea"
	_text(at, height, colour, READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	for slot: String in ["Stamina", "Warmth"]:
		at.y += 30.0
		_text(at, slot, Color(TEXT, 0.6), READOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		var bar := Rect2(at + Vector2(88.0, -13.0), Vector2(140.0, 14.0))
		_canvas.draw_rect(bar, INK)
		var share := _stamina(me) if slot == "Stamina" else _cold(me)
		var fill := _stamina_colour(me) if slot == "Stamina" else _cold_colour(me)
		_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), fill)
		_canvas.draw_rect(bar, Color(TEXT, 0.35), false, 1.5)


## [param above_sea] metres from the feet to the sea, in words: above it, under it,
## or at the waterline when it rounds to nothing.
static func height_words(above_sea: float) -> String:
	if absf(above_sea) < 0.05:
		return "At the waterline"
	if above_sea < 0.0:
		return "%.1f m under the sea" % -above_sea
	return "%.1f m above the sea" % above_sea


## A chevron in seat colour, ringed by its stamina, and the seat's name over every
## other brawler within CHEVRON_RANGE whose eyes [param my_pos]'s see under
## [param pose] — Surfaces.line_of_sight, what the bots' view asks too: never through a
## wall, a floor or the hull.
func _draw_chevrons(my_pos: Vector3, pose: ShipPose) -> void:
	var eye := Vector3.UP * FirstPersonCamera.EYE_HEIGHT
	for entry: Dictionary in _snapshot["seats"]:
		var seat: int = entry["seat"]
		if seat == _seat or entry["out"]:
			continue
		var their_pos: Vector3 = entry["pos"]
		if my_pos.distance_to(their_pos) > CHEVRON_RANGE:
			continue
		if not _surfaces.line_of_sight(my_pos + eye, their_pos + eye, pose):
			continue
		var over := (
			_view.seat_world_position(seat) + Vector3.UP * (_rules.body_height + CHEVRON_LIFT)
		)
		if _camera.is_position_behind(over):
			continue
		var at := _camera.unproject_position(over)
		at.y = maxf(at.y, CHEVRON_TOP)
		if not chevron_shows(at, _canvas.size):
			continue
		var far := my_pos.distance_to(their_pos) / CHEVRON_RANGE
		var shrink := lerpf(1.0, FAR_SCALE, far)
		var alpha := 1.0 - smoothstep(FADE_FROM, 1.0, far)
		if at.x + NAME_HALF > _canvas.size.x - DIALS.x and at.y - RING_RADIUS < DIALS.y:
			alpha *= UNDER_DIALS
		_chevron(at, entry, shrink, alpha)


## [param entry]'s chevron at [param at], ringed by its stamina, under its seat's
## name, drawn [param shrink] of its size and [param alpha] opaque.
func _chevron(at: Vector2, entry: Dictionary, shrink: float, alpha: float) -> void:
	var seat: int = entry["seat"]
	var colour := Color(ArtPalette.seat_colour(seat), alpha)
	var ink := Color(INK, INK.a * alpha)
	var radius := RING_RADIUS * shrink
	_ring(at, entry, radius, alpha)
	var chevron := chevron_points(at, shrink)
	_canvas.draw_colored_polygon(chevron, colour)
	chevron.append(chevron[0])
	_canvas.draw_polyline(chevron, ink, 1.5, true)
	var name_at := at + Vector2(0.0, -radius - 6.0)
	var font_size := roundi(FONT_SIZE * shrink)
	var seat_name := UiTheme.fit(_names[seat], _font, font_size, READOUT_TEXT)
	_text(name_at, seat_name, colour, READOUT_TEXT, HORIZONTAL_ALIGNMENT_CENTER, font_size, ink)


## Whether a chevron at [param at] reaches onto a screen of [param size] — its name
## spreads READOUT_TEXT wide — and so is drawn: a body over the eye's shoulder, its
## head by the camera's plane, projects tens of thousands of pixels off, where the
## chevron is never seen and too far out for its points to be told apart.
static func chevron_shows(at: Vector2, size: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(READOUT_TEXT * 0.5).has_point(at)


## The chevron's triangle at [param at], [param shrink] of its size.
static func chevron_points(at: Vector2, shrink: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			at + Vector2(-9.0, -6.0) * shrink,
			at + Vector2(9.0, -6.0) * shrink,
			at + Vector2(0.0, 5.0) * shrink,
		]
	)


## [param entry]'s stamina — its warmth in the sea — as a ring of [param radius]
## round [param centre], filled clockwise from the top, [param alpha] opaque.
func _ring(centre: Vector2, entry: Dictionary, radius: float, alpha: float) -> void:
	_canvas.draw_arc(centre, radius, 0.0, TAU, 32, Color(INK, INK.a * alpha), RING_WIDTH, true)
	var swimming: bool = entry["state"] == PlayerState.Body.SWIMMING
	var share := _cold(entry) if swimming else _stamina(entry)
	if share > 0.0:
		var top := -PI * 0.5
		var fill := _cold_colour(entry) if swimming else _stamina_colour(entry)
		_canvas.draw_arc(
			centre, radius, top, top + TAU * share, 32, Color(fill, alpha), RING_WIDTH, true
		)


## A wedge at the screen's edge with an arrow pointing out at each seat outside the
## field of view that winds up, charges or throws a shove close enough to land on
## [param my_pos] before its active window ends — its reach plus a walk through windup
## and active — in that seat's colour: on its side's edge while it is beside, fading
## into the bottom edge as it comes round behind. Wedges only ever warn of a shove on
## the same level, so none stands on the top edge. Several on one edge stand apart
## (wedges_apart), in the order of their seats, so none hides another.
func _draw_windup_wedges(my_pos: Vector3) -> void:
	var reach := (
		_rules.shove_reach + _rules.walk_speed * (_rules.shove_windup + _rules.shove_active)
	)
	var half_view := deg_to_rad(_camera.fov * 0.5)
	var seats := PackedInt32Array()
	var bearings := PackedFloat32Array()
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
		seats.append(entry["seat"])
		bearings.append(bearing)
	var roots := wedges_apart(_canvas.size, bearings)
	for index in seats.size():
		var colour := ArtPalette.seat_colour(seats[index])
		var behind := behind_share(bearings[index])
		if behind < 1.0:
			_draw_wedge(roots[index * 2], bearings[index], colour, 1.0 - behind)
		if behind > 0.0:
			_draw_wedge(roots[index * 2 + 1], bearings[index], colour, behind)


## A wedge of [param colour], [param strength] of its full brightness, fading in from
## [param root] on the screen's edge with a bright line along it, and an arrowhead at
## its root pointing toward the shove at [param bearing].
func _draw_wedge(root: Vector2, bearing: float, colour: Color, strength: float) -> void:
	var inward := wedge_inward(_canvas.size, root)
	var along := inward.orthogonal().abs()
	var lit := Color(colour, WEDGE_ALPHA * strength)
	var clear := Color(colour, 0.0)
	var deep := root + inward * WEDGE_DEPTH
	for end: Vector2 in [root - along * WEDGE_HALF, root + along * WEDGE_HALF]:
		_canvas.draw_primitive(
			PackedVector2Array([end, root, deep]), PackedColorArray([clear, lit, clear]), []
		)
	var line := along * WEDGE_HALF * 0.6
	_canvas.draw_line(root - line, root + line, Color(INK, INK.a * strength), WEDGE_KEYLINE)
	_canvas.draw_line(root - line, root + line, lit, WEDGE_LINE)
	var direction := wedge_arrow(bearing)
	var tip := root + inward * ARROW_IN
	var base := tip - direction * ARROW_LENGTH
	var side := direction.orthogonal() * ARROW_HALF
	var arrow := PackedVector2Array(
		[tip, base + side, base + direction * ARROW_NOTCH, base - side, tip]
	)
	_canvas.draw_polyline(arrow, Color(INK, INK.a * strength), 5.0, true)
	arrow.remove_at(arrow.size() - 1)
	_canvas.draw_colored_polygon(arrow, Color(colour, strength))


## The root on its side's edge of the wedge for a shove [param bearing] off the view's
## middle — positive to the right — on a screen of [param size]: mid-height while the
## shove is beside, lower the further behind it comes, never down to the plate.
static func wedge_on_side(size: Vector2, bearing: float) -> Vector2:
	var round_behind := clampf(absf(bearing) / (PI * 0.5) - 1.0, 0.0, 1.0)
	var lowest := plate_rect(size).position.y - WEDGE_CLEAR - WEDGE_HALF
	var y := lerpf(size.y * 0.5, maxf(lowest, size.y * 0.5), round_behind)
	return Vector2(size.x if bearing > 0.0 else 0.0, y)


## The root on the bottom edge of the wedge for a shove [param bearing] off the view's
## middle on a screen of [param size]: under the middle dead astern, toward the
## shove's side the further round it is from there, never along the plate.
static func wedge_behind(size: Vector2, bearing: float) -> Vector2:
	var off_astern := clampf((PI - absf(bearing)) / (PI - BEHIND_FROM), 0.0, 1.0)
	var furthest := size.x * 0.5 - (plate_rect(size).end.x + WEDGE_CLEAR + WEDGE_HALF)
	return Vector2(size.x * 0.5 + signf(bearing) * off_astern * furthest, size.y)


## The roots of the wedges for shoves at [param bearings], on a screen of [param size]:
## for each, its side's (wedge_on_side) then its bottom edge's (wedge_behind). The
## parts that show on one edge (behind_share) stand WEDGE_SPREAD apart along it, or
## as far as the edge leaves them, round the middle of where they would stand alone,
## in the order the bearings come in — the seats' order, so each keeps its place
## frame to frame.
static func wedges_apart(size: Vector2, bearings: PackedFloat32Array) -> PackedVector2Array:
	var roots := PackedVector2Array()
	var edges := {-1.0: [], 1.0: [], 0.0: []}
	for index in bearings.size():
		roots.append(wedge_on_side(size, bearings[index]))
		roots.append(wedge_behind(size, bearings[index]))
		var behind := behind_share(bearings[index])
		if behind < 1.0:
			(edges[signf(bearings[index])] as Array).append(index * 2)
		if behind > 0.0:
			(edges[0.0] as Array).append(index * 2 + 1)
	var plate := plate_rect(size)
	# Along the sides, from under the dials down to over the plate; along the bottom,
	# from past the plate to as far the other side.
	var side := Vector2(DIALS.y + WEDGE_CLEAR + WEDGE_HALF, plate.position.y - WEDGE_CLEAR)
	side.y -= WEDGE_HALF
	var bottom := Vector2(plate.end.x + WEDGE_CLEAR + WEDGE_HALF, 0.0)
	bottom.y = size.x - bottom.x
	for edge: float in edges:
		var placed: Array = edges[edge]
		if placed.size() < 2:
			continue
		var axis := 0 if edge == 0.0 else 1
		var span := bottom if edge == 0.0 else side
		var spread := minf(WEDGE_SPREAD, (span.y - span.x) / (placed.size() - 1))
		var middle := 0.0
		for slot: int in placed:
			middle += roots[slot][axis] / placed.size()
		var reach := spread * (placed.size() - 1) * 0.5
		middle = clampf(middle, span.x + reach, maxf(span.y - reach, span.x + reach))
		for rank in placed.size():
			var root := roots[placed[rank]]
			root[axis] = middle - reach + spread * rank
			roots[placed[rank]] = root
	return roots


## How far up from the bottom edge a wedge's arrow there reaches, in pixels.
static func behind_arrow_reach() -> float:
	return ARROW_IN + Vector2(ARROW_LENGTH, ARROW_HALF).length()


## How much of the wedge for a shove at [param bearing] stands on the bottom edge
## rather than its side's: none until BEHIND_FROM, all of it dead astern.
static func behind_share(bearing: float) -> float:
	return smoothstep(BEHIND_FROM, PI, absf(bearing))


## Which way a wedge's arrow points for a shove at [param bearing]: straight out to its
## side while it is beside, turning down as it comes round behind — never up, as a
## shove never comes from above.
static func wedge_arrow(bearing: float) -> Vector2:
	return Vector2(sin(bearing), maxf(-cos(bearing), 0.0)).normalized()


## Into the screen of [param size] from the edge [param root] stands on.
static func wedge_inward(size: Vector2, root: Vector2) -> Vector2:
	if root.y == size.y:
		return Vector2.UP
	return Vector2.LEFT if root.x == size.x else Vector2.RIGHT


## What a wedge rooted at [param root], fading in along [param inward], covers.
static func wedge_box(root: Vector2, inward: Vector2) -> Rect2:
	var along := inward.orthogonal().abs() * WEDGE_HALF
	return Rect2(root - along, along * 2.0).expand(root + inward * WEDGE_DEPTH)


## [param text] on a baseline at [param at], centred in [param width] unless
## [param align] says left, [param font_size] high and outlined in [param ink].
func _text(
	at: Vector2,
	text: String,
	colour: Color,
	width: float,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
	font_size: int = FONT_SIZE,
	ink: Color = INK
) -> void:
	var left := at - Vector2(width * 0.5, 0.0) if align == HORIZONTAL_ALIGNMENT_CENTER else at
	_canvas.draw_string_outline(_font, left, text, align, width, font_size, 5, ink)
	_canvas.draw_string(_font, left, text, align, width, font_size, colour)


## Under the crosshair, while [param me] swims and pressing on where it looks would
## start a climb out: the move-forward key by the layout's label, Z on AZERTY.
func _draw_climb_prompt(me: Dictionary, pose: ShipPose) -> void:
	if me["climb"] > 0 or me["stagger"] > 0:
		return
	if _surfaces.climb_out(me["pos"], Vector2.from_angle(_yaw), pose, _rules) == null:
		return
	var at := _canvas.size * 0.5 + Vector2(0.0, 70.0)
	_text(at, "Hold %s to climb" % _prompts.word(&"move_up"), TEXT, READOUT_TEXT)


## The frost's crystals: the edges between the cells of a seamless cellular noise,
## white on black.
static func _crystals() -> NoiseTexture2D:
	var cells := FastNoiseLite.new()
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.frequency = CRYSTAL_CELLS / CRYSTAL_SIZE
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.76, 0.93])
	ramp.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color.WHITE])
	var texture := NoiseTexture2D.new()
	texture.width = CRYSTAL_SIZE
	texture.height = CRYSTAL_SIZE
	texture.seamless = true
	texture.invert = true
	texture.generate_mipmaps = true
	texture.color_ramp = ramp
	texture.noise = cells
	return texture


## [param entry]'s cold meter, as a share of a full one.
func _cold(entry: Dictionary) -> float:
	return entry["cold"] / _rules.cold_meter


func _cold_colour(entry: Dictionary) -> Color:
	return FREEZING if _cold(entry) < COLD_LOW else WARM


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
