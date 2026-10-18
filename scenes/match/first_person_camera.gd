class_name FirstPersonCamera
extends Camera3D
## A seat's eyes (D14): 1.6 m above its drawn feet along the world's up — a crawler's
## as much lower as it is, eased down and up again — turned by its look and a pitch
## that only ever lives here. The horizon stays level while the deck
## tilts round it unless ViewSettings' deck roll asks for some of the list (Q17); the
## field of view is horizontal, so a wider window shows more to the sides, not less
## above. The look's yaw is in the plane of the face the seat stands on (Faces, SH32):
## on a wall of a ship on her side, or under her decks upside down, it turns about that
## face's up, never near the world's — the eye stays above the feet as the ship turns
## round it.

const EYE_HEIGHT := 1.6
## Close enough that a wall a body is pinned against (its radius away) is never cut.
const NEAR := 0.05
## How fast the eye eases to a new height, a share of the way left each second: down
## to a crawler's in about a quarter of a second.
const EYE_EASE := 12.0

var _deck_roll: float
## How high over the feet the eye stands now, and the seat it stood for.
var _eye := EYE_HEIGHT
var _eye_seat := -1


func setup(settings: ViewSettings) -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = settings.fov_deg
	near = NEAR
	_deck_roll = settings.deck_roll


## Eases the eye toward [param share] of EYE_HEIGHT — a body's height now over a
## standing one's — over [param delta] seconds; it stands there at once for a seat it
## did not stand for before, [param seat].
func ease_eye(seat: int, share: float, delta: float) -> void:
	var target := EYE_HEIGHT * share
	if seat != _eye_seat:
		_eye_seat = seat
		_eye = target
	_eye = lerpf(_eye, target, 1.0 - exp(-EYE_EASE * delta))


## How high over the feet the eye stands now.
func eye_height() -> float:
	return _eye


## How high over its feet [param camera] looks from: a seat's eyes' height now, or a
## standing body's for any other camera.
static func eye_height_of(camera: Camera3D) -> float:
	if camera is FirstPersonCamera:
		return (camera as FirstPersonCamera).eye_height()
	return EYE_HEIGHT


## Looks from the eye of feet at [param feet] (ship space) on a ship placed by
## [param ship_to_world], along [param yaw] in the plane of the faces the frame
## [param up] has as floors (Faces.Up) and [param pitch] above the horizon, turned on
## top of that by [param kick] — ViewKick's pitch, yaw and roll, which never feeds back
## into the look.
func look_from(
	ship_to_world: Transform3D,
	feet: Vector3,
	yaw: float,
	pitch: float,
	kick := Vector3.ZERO,
	up: int = Faces.Up.DECK
) -> void:
	var face_to_world := ship_to_world.basis.orthonormalized() * Faces.to_ship(up)
	var ahead := Vector3(cos(yaw), 0.0, sin(yaw))
	var level_ahead := face_to_world * ahead
	var level := Basis.from_euler(Vector3(pitch, atan2(-level_ahead.x, -level_ahead.z), 0.0))
	var rolled := face_to_world * Basis.from_euler(Vector3(pitch, atan2(-ahead.x, -ahead.z), 0.0))
	global_transform = Transform3D(
		level.slerp(rolled, _deck_roll) * Basis.from_euler(kick),
		ship_to_world * feet + Vector3.UP * _eye
	)
