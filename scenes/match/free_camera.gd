class_name FreeCamera
extends RefCounted
## The free camera: the one detached view (D14) — a local seat's once it is out, a
## watcher's (GLOSSARY: Watch) and the replay viewer's (R5) — in place of a seat's eyes:
## detached from every seat, turned by the mouse and the right stick as the first-person
## look is, flown level along where it looks by the move, up by the jump and down by the
## brace, frame by frame. Following, it trails the seat watched at the offset it stood
## from it as it locked on, until flown by hand or let go. It never touches the ship, and
## keeps inside a box round the decks, from under the sea — the world plane y = 0 (D7) —
## to its ceiling: it dives under her keel and follows her down, the view under the water
## Underwater's and MatchAudio's, as a seat's eyes have it, and a coast's bottom
## (SinkScenario.sea_depth) stops it. It opens over the sea. Presentation only: nothing of it is
## ever sent, and no rule reads it. Its state is world space; the scene reads transform().

## How fast it flies level and climbs, in metres per second.
const SPEED := 8.0
const CLIMB_SPEED := 6.0
## How far it may look up or down, short of straight.
const PITCH_LIMIT_DEG := 80.0
## How far past the decks' edges it may fly, how deep under the sea and how high over it
## it may go, and how far over a coast's bottom it keeps, in metres. DEPTH reaches under
## the deepest keel of the fleet as her sinking ends — the Titanic's, 42 m under her
## boat deck, once all of her is 10 m under (SeaPhysics.gone_depth) — so it gets under
## her keel at rest (she draws 9.8 m) and stays with her all the way down.
const MARGIN := 20.0
const DEPTH := 60.0
const CEILING := 40.0
const BED_CLEARANCE := 1.0
## How far over the sea it opens (start), whatever the seat it opens at.
const SEA_CLEARANCE := 1.0
## Where it starts: this far behind and over the seat it was watching, looking at it.
const START_BACK := 6.0
const START_RISE := 4.0
## How it frames the whole ship (frame_ship), as the observer camera does: looking this
## far down at the middle of her decks from her starboard side, this far off a short hull
## and a share of a long one's length (ObserverCamera.LONG_HULL).
const FRAME_PITCH_DEG := 50.0
const FRAME_DISTANCE := 24.0
## How quickly following closes on where it trails the seat, per second.
const FOLLOW_RATE := 6.0

## Whether the view is the free camera rather than a seat's eyes.
var active := false
## Whether it trails the seat watched (toggle_follow).
var following := false
## Where it is in the world, and its world yaw and pitch, in radians.
var position := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
## The world box it keeps inside: no deeper than DEPTH and nowhere else until set_bounds().
var bounds := AABB(Vector3(-1e6, -DEPTH, -1e6), Vector3(2e6, 1e6 + DEPTH, 2e6))
## The look's sensitivity and invert-Y, as the first-person look reads them.
var settings: ViewSettings

## Where it stands from the seat it follows, in the world.
var _offset := Vector3.ZERO


func _init(view_settings: ViewSettings = null) -> void:
	settings = view_settings if view_settings != null else ViewSettings.new()


## Switches between the free camera and a seat's eyes, while [param spectating] — the
## local seat out and the match going on; never otherwise.
func toggle(spectating: bool) -> void:
	active = spectating and not active
	following = following and active


## Back to a seat's eyes once the local seat is no longer [param spectating].
func keep(spectating: bool) -> void:
	active = active and spectating
	following = following and active


## Back to a seat's eyes: cycling to another seat — unless it follows, when it goes on
## to trail the seat cycled to.
func leave() -> void:
	active = following


## Keeps it within [constant MARGIN] of [param deck] — every platform's area in the
## ship plane, taken as the world's x/z as ObserverCamera takes it — between its floor
## (floor_under) in a sea [param sea_depth] deep and the ceiling.
func set_bounds(deck: Rect2, sea_depth := INF) -> void:
	var area := deck.grow(MARGIN)
	var bottom := floor_under(sea_depth)
	bounds = AABB(
		Vector3(area.position.x, bottom, area.position.y),
		Vector3(area.size.x, CEILING - bottom, area.size.y)
	)


## How low it may go, in the world, in a sea [param sea_depth] deep: [constant DEPTH]
## under the surface, or [constant BED_CLEARANCE] over a shallower bottom — never over
## the surface. A depth of 0 or less is no bottom (an authored fixture's).
static func floor_under(sea_depth: float) -> float:
	if sea_depth <= 0.0:
		return -DEPTH
	return minf(maxf(-DEPTH, BED_CLEARANCE - sea_depth), 0.0)


## Stands it behind and over [param target] — whose view looks along [param ahead],
## in the world — looking at it, so the switch out of its eyes keeps the bearings; at
## least [constant SEA_CLEARANCE] over the sea, however deep the seat went down.
func start(target: Vector3, ahead: Vector3) -> void:
	var level := Vector3(ahead.x, 0.0, ahead.z)
	level = Vector3.FORWARD if level.is_zero_approx() else level.normalized()
	var at := target - level * START_BACK + Vector3.UP * START_RISE
	at.y = maxf(at.y, SEA_CLEARANCE)
	position = clamped(at, bounds)
	var to := target - position
	if not to.is_zero_approx():
		yaw = atan2(-to.x, -to.z)
		pitch = _limit(atan2(to.y, Vector2(to.x, to.z).length()))


## Stands it over the sea off her starboard side, looking down at the middle of
## [param deck] — every platform's area in the ship plane, as set_bounds() takes it —
## from far enough off to frame her whole, its box grown to hold it there: where a
## watcher's and a replay's free camera opens.
func frame_ship(deck: Rect2) -> void:
	var long_hull := deck.size.x > FRAME_DISTANCE * ObserverCamera.LONG_HULL
	var distance := deck.size.x * ObserverCamera.LONG_HULL_DISTANCE if long_hull else FRAME_DISTANCE
	var down := deg_to_rad(FRAME_PITCH_DEG)
	var middle := deck.get_center()
	position = Vector3(middle.x, sin(down) * distance, middle.y + cos(down) * distance)
	bounds = bounds.expand(position)
	yaw = 0.0
	pitch = -down
	following = false


## Starts trailing [param target] — the seat watched, in the world — at the offset it
## stands from it now; or, following already, lets go. Only the free camera follows.
func toggle_follow(target: Vector3) -> void:
	following = active and not following
	_offset = position - target


## Drawn toward where it keeps its offset from [param target] while it follows, at
## [constant FOLLOW_RATE] over [param delta] seconds, inside its box: down under the sea
## with a seat that goes there.
func trail(target: Vector3, delta: float) -> void:
	if following:
		var weight := clampf(FOLLOW_RATE * delta, 0.0, 1.0)
		position = clamped(position.lerp(target + _offset, weight), bounds)


## Turns it by [param by] radians — right and down positive, as the mouse moves — down
## looking down unless [param invert_y].
func turn(by: Vector2, invert_y: bool) -> void:
	yaw = wrapf(yaw - by.x, -PI, PI)
	var down := -by.y if invert_y else by.y
	pitch = _limit(pitch - down)


## Flies it by [param move] — the move's stick, right and back positive — and
## [param rise], up positive, held for [param delta] seconds: flown at all, it lets go of
## the seat it follows. Turning it never does.
func fly(move: Vector2, rise: float, delta: float) -> void:
	if not move.is_zero_approx() or not is_zero_approx(rise):
		following = false
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
