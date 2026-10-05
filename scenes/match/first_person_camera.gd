class_name FirstPersonCamera
extends Camera3D
## A seat's eyes (D14): 1.6 m above its drawn feet along the world's up, turned by its
## look and a pitch that only ever lives here. The horizon stays level while the deck
## tilts round it unless ViewSettings' deck roll asks for some of the list (Q17); the
## field of view is horizontal, so a wider window shows more to the sides, not less
## above.

const EYE_HEIGHT := 1.6
## Close enough that a wall a body is pinned against (its radius away) is never cut.
const NEAR := 0.05

var _deck_roll: float


func setup(settings: ViewSettings) -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = settings.fov_deg
	near = NEAR
	_deck_roll = settings.deck_roll


## Looks from the eye of feet at [param feet] (ship space) on a ship placed by
## [param ship_to_world], along the ship-plane [param yaw] and [param pitch] above
## the horizon, turned on top of that by [param kick] — ViewKick's pitch, yaw and
## roll, which never feeds back into the look.
func look_from(
	ship_to_world: Transform3D, feet: Vector3, yaw: float, pitch: float, kick := Vector3.ZERO
) -> void:
	var ahead := Vector3(cos(yaw), 0.0, sin(yaw))
	var level_ahead := ship_to_world.basis * ahead
	var level := Basis.from_euler(Vector3(pitch, atan2(-level_ahead.x, -level_ahead.z), 0.0))
	var rolled := (
		ship_to_world.basis.orthonormalized()
		* Basis.from_euler(Vector3(pitch, atan2(-ahead.x, -ahead.z), 0.0))
	)
	global_transform = Transform3D(
		level.slerp(rolled, _deck_roll) * Basis.from_euler(kick),
		ship_to_world * feet + Vector3.UP * EYE_HEIGHT
	)
