class_name OrbitCamera
extends RefCounted
## The replay viewer's orbit camera (R5, #213): an eye orbiting a pivot above the
## ship — turned by a mouse drag or the right stick, the pivot panned by a middle drag
## or the left stick, the distance zoomed by the wheel or the triggers — held over the
## sea and outside her hull's box (OrbitMath). Locked, the pivot follows the seat
## watched; unlocked, it stays where it was panned. It opens framing the whole ship as
## the observer camera does. The one elevated view a player ever has (D14, replay
## only); presentation only, as FreeCamera is: nothing of it is sent or read by a rule.

## The pitch the eye may be raised to above the level, in degrees, and the distances it
## may stand off at, in metres.
const PITCH_LIMITS_DEG := Vector2(5.0, 85.0)
const DISTANCE_LIMITS := Vector2(2.0, 160.0)
## How the pitch opens, and how far off: ObserverCamera's framing.
const OPENING_PITCH_DEG := 50.0
const NEAR_DISTANCE := 24.0
## A wheel notch's zoom, as a share of the distance; the triggers' per second held.
const ZOOM_STEP := 0.88
const TRIGGER_ZOOM_PER_SECOND := 0.6
## A pan's metres per pixel dragged, per metre of distance; the stick's per second.
const PAN_PER_PIXEL := 0.0018
const STICK_PAN_PER_SECOND := 0.5
## How far past the decks' edges the pivot may be panned, and how far over the sea the
## eye keeps, in metres; how quickly the lock closes on the seat, per second.
const MARGIN := 20.0
const SEA_CLEARANCE := 1.0
const FOLLOW_RATE := 6.0
## How far under her lowest deck the hull's box reaches: her draught, roughly.
const DRAUGHT := 4.0

## Whether the view is the orbit camera rather than a seat's eyes.
var active := false
## Whether the pivot follows the seat watched.
var locked := false
## What the eye looks at and turns about, in the world; its yaw and pitch, in radians;
## how far off it stands.
var pivot := Vector3.ZERO
var yaw := 0.0
var pitch := deg_to_rad(OPENING_PITCH_DEG)
var distance := NEAR_DISTANCE
## The look's sensitivity, as the first-person look reads it.
var settings: ViewSettings

## The decks' bounds in the ship plane, grown by MARGIN, the pivot keeps inside; the
## hull's box in ship space the eye keeps out of; and the eye, as advance() last put it.
var _bounds := Rect2()
var _hull := AABB()
var _eye := Vector3.ZERO


func _init(view_settings: ViewSettings = null) -> void:
	settings = view_settings if view_settings != null else ViewSettings.new()


## The ship it watches: [param layout]'s decks and the box round her hull.
func set_ship(layout: ShipLayout) -> void:
	var deck := layout.platforms[0].area
	var lowest := INF
	var highest := -INF
	for platform: ShipPlatform in layout.platforms:
		deck = deck.merge(platform.area)
		lowest = minf(lowest, platform.height)
		highest = maxf(highest, platform.height)
	for blocker: ShipBlocker in layout.blockers:
		highest = maxf(highest, blocker.top)
	_bounds = deck.grow(MARGIN)
	_hull = AABB(
		Vector3(deck.position.x, lowest - DRAUGHT, deck.position.y),
		Vector3(deck.size.x, highest - lowest + DRAUGHT, deck.size.y)
	)


## Opens framing the whole ship from her starboard side, as the observer camera does,
## the pivot over the middle of her decks, unlocked.
func open() -> void:
	var deck := _bounds.grow(-MARGIN)
	var middle := deck.get_center()
	pivot = Vector3(middle.x, 0.0, middle.y)
	yaw = 0.0
	pitch = deg_to_rad(OPENING_PITCH_DEG)
	distance = clampf(
		OrbitMath.whole_ship_distance(deck, NEAR_DISTANCE), DISTANCE_LIMITS.x, DISTANCE_LIMITS.y
	)
	locked = false


## Turns the eye about the pivot by a mouse motion of [param pixels]: dragging down
## raises it.
func orbit_by_mouse(pixels: Vector2) -> void:
	turn(pixels * deg_to_rad(settings.mouse_deg_per_pixel))


## Turns the eye by [param by] radians: right and up positive.
func turn(by: Vector2) -> void:
	yaw = wrapf(yaw - by.x, -PI, PI)
	pitch = clampf(pitch + by.y, deg_to_rad(PITCH_LIMITS_DEG.x), deg_to_rad(PITCH_LIMITS_DEG.y))


## Pans the pivot by a mouse motion of [param pixels], the further the further off the
## eye stands; the lock lets go.
func pan_by_mouse(pixels: Vector2) -> void:
	pan(pixels * distance * PAN_PER_PIXEL)


## Pans the pivot [param by] metres, right and back positive in the eye's frame.
func pan(by: Vector2) -> void:
	pivot = OrbitMath.pan(pivot, yaw, by, _bounds)
	locked = false


## Zooms [param notches] in (positive) or out, a wheel notch each.
func zoom(notches: float) -> void:
	distance = clampf(distance * pow(ZOOM_STEP, notches), DISTANCE_LIMITS.x, DISTANCE_LIMITS.y)


## A mouse [param motion] with a button held: the left drag orbits, the middle pans.
func drag(motion: InputEventMouseMotion) -> void:
	if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		orbit_by_mouse(motion.screen_relative)
	elif motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		pan_by_mouse(motion.screen_relative)


## The frame's worth of the pad: the right stick orbits, the left pans, the triggers
## zoom; then the pivot follows [param target] (the seat watched, in the world) while
## locked, and the eye is put where that leaves it — over the sea, and out of the hull
## placed by [param ship_to_world].
func advance(delta: float, target: Vector3, ship_to_world: Transform3D) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if not look.is_zero_approx():
		turn(Vector2(look.x, -look.y) * deg_to_rad(settings.stick_deg_per_second) * delta)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not move.is_zero_approx():
		pan(move * distance * STICK_PAN_PER_SECOND * delta)
	var squeeze := (
		Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	)
	if absf(squeeze) > 0.05:
		zoom(squeeze * TRIGGER_ZOOM_PER_SECOND * delta / (1.0 - ZOOM_STEP))
	if locked:
		pivot = OrbitMath.follow(pivot, target, FOLLOW_RATE, delta)
	var eye := OrbitMath.eye_of(pivot, yaw, pitch, distance)
	eye = OrbitMath.over_sea(eye, SEA_CLEARANCE)
	_eye = OrbitMath.out_of(eye, pivot, ship_to_world * _hull)


## Where the eye is and how it looks, in the world: at the pivot.
func transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(-pitch, yaw, 0.0)), _eye)
