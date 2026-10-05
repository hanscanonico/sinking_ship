class_name FreeCamera
extends RefCounted
## The free camera a local seat that is out may fly instead of looking through a
## survivor's eyes: detached from every seat, turned by the mouse and the right stick
## as the first-person look is, flown level along where it looks by the move, up by
## the jump and down by the brace, frame by frame. It never touches the ship, and keeps
## inside a box round the decks and over the sea — the world plane y = 0 (D7), as
## Underwater and MatchAudio have it. Presentation only: nothing of it is ever sent,
## and no rule reads it. Its state is world space; the scene reads transform().

## How fast it flies level and climbs, in metres per second.
const SPEED := 8.0
const CLIMB_SPEED := 6.0
## How far it may look up or down, short of straight.
const PITCH_LIMIT_DEG := 80.0
## How far past the decks' edges it may fly, how far over the sea it keeps, and how
## high it may go, in metres.
const MARGIN := 20.0
const SEA_CLEARANCE := 1.0
const CEILING := 40.0
## Where it starts: this far behind and over the seat it was watching, looking at it.
const START_BACK := 6.0
const START_RISE := 4.0

## Whether the view is the free camera rather than a seat's eyes.
var active := false
## Where it is in the world, and its world yaw and pitch, in radians.
var position := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
## The world box it keeps inside: over the sea and nowhere else until set_bounds().
var bounds := AABB(Vector3(-1e6, SEA_CLEARANCE, -1e6), Vector3(2e6, 1e6, 2e6))
## The look's sensitivity and invert-Y, as the first-person look reads them.
var settings: ViewSettings


func _init(view_settings: ViewSettings = null) -> void:
	settings = view_settings if view_settings != null else ViewSettings.new()


## Switches between the free camera and a seat's eyes, while [param spectating] — the
## local seat out and the match going on; never otherwise.
func toggle(spectating: bool) -> void:
	active = spectating and not active


## Back to a seat's eyes once the local seat is no longer [param spectating].
func keep(spectating: bool) -> void:
	active = active and spectating


## Back to a seat's eyes: cycling to another seat.
func leave() -> void:
	active = false


## Keeps it within [constant MARGIN] of [param deck] — every platform's area in the
## ship plane, taken as the world's x/z as ObserverCamera takes it — over the sea and
## under the ceiling.
func set_bounds(deck: Rect2) -> void:
	var area := deck.grow(MARGIN)
	bounds = AABB(
		Vector3(area.position.x, SEA_CLEARANCE, area.position.y),
		Vector3(area.size.x, CEILING - SEA_CLEARANCE, area.size.y)
	)


## Stands it behind and over [param target] — whose view looks along [param ahead],
## in the world — looking at it, so the switch out of its eyes keeps the bearings.
func start(target: Vector3, ahead: Vector3) -> void:
	var level := Vector3(ahead.x, 0.0, ahead.z)
	level = Vector3.FORWARD if level.is_zero_approx() else level.normalized()
	position = clamped(target - level * START_BACK + Vector3.UP * START_RISE, bounds)
	var to := target - position
	if not to.is_zero_approx():
		yaw = atan2(-to.x, -to.z)
		pitch = _limit(atan2(to.y, Vector2(to.x, to.z).length()))


## Turns it by [param by] radians — right and down positive, as the mouse moves — down
## looking down unless [param invert_y].
func turn(by: Vector2, invert_y: bool) -> void:
	yaw = wrapf(yaw - by.x, -PI, PI)
	var down := -by.y if invert_y else by.y
	pitch = _limit(pitch - down)


## Flies it by [param move] — the move's stick, right and back positive — and
## [param rise], up positive, held for [param delta] seconds.
func fly(move: Vector2, rise: float, delta: float) -> void:
	position = clamped(position + step(yaw, move, rise, delta), bounds)


## Turns it by a mouse motion of [param pixels].
func look_by_mouse(pixels: Vector2) -> void:
	turn(pixels * deg_to_rad(settings.mouse_deg_per_pixel), settings.invert_y)


## Turns it by the right stick and flies it by the move, the jump and the brace, held
## for [param delta] seconds.
func fly_by_input(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	turn(stick * deg_to_rad(settings.stick_deg_per_second) * delta, settings.invert_y)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	fly(move, Input.get_action_strength("jump") - Input.get_action_strength("brace"), delta)


## Where it is and how it looks, in the world.
func transform() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), position)


## How far [param move] and [param rise] carry it in [param delta] seconds looking
## along [param yaw]: level whatever its pitch, so looking down never dives.
static func step(look_yaw: float, move: Vector2, rise: float, delta: float) -> Vector3:
	var level := Vector3(move.x, 0.0, move.y).limit_length(1.0).rotated(Vector3.UP, look_yaw)
	return (level * SPEED + Vector3.UP * clampf(rise, -1.0, 1.0) * CLIMB_SPEED) * delta


## [param at] held inside [param box].
static func clamped(at: Vector3, box: AABB) -> Vector3:
	return at.clamp(box.position, box.end)


static func _limit(angle: float) -> float:
	var limit := deg_to_rad(PITCH_LIMIT_DEG)
	return clampf(angle, -limit, limit)
