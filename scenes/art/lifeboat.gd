class_name Lifeboat
extends Node3D
## A run of lifeboats on one side, hung from their davits' heads (ShipFittings): plumb
## in the world as she lists, so on the low side they swing out clear of her; on the
## high side they swing in, and past the list beyond which they could not be lowered
## (ShipFitting, §5b.1) they lie in against her and hang there, plainly useless. A
## lurch sets them swinging. Presentation only (D5): it reads where the view has put the
## ship, never a rule.

## How fast a hanging boat swings toward plumb: its pendulum's rate, per second, and
## how much of its swing dies away each second.
const SWING_RATE := 3.0
const SWING_DAMPING := 2.2

## 1 for her starboard side, -1 for her port side; how far in, in radians, they can
## swing before they lie against her; and their swing now, and how fast it goes —
## positive toward starboard.
var _side := 1.0
var _limit := 0.0
var _swing := 0.0
var _swinging := 0.0


## Hangs [param hung] — boats drawn in ship space — on [param side] of [param layout]
## from the line through [param pivot], in [param paints] (ShipArt.paints), swinging in
## no further than her lifeboats' list limit on that side (ShipFitting) — or, for a ship
## without one, never in.
func setup(
	side: int, pivot: Vector3, hung: ShipMesh, paints: Dictionary, layout: ShipLayout
) -> void:
	_side = float(side)
	if layout.structure != null:
		for fitting: ShipFitting in layout.structure.fittings:
			if fitting.kind == ShipFitting.Kind.LIFEBOAT and fitting.side == side:
				_limit = deg_to_rad(fitting.list_limit_deg)
	name = "Lifeboats%s" % ("Starboard" if side == 1 else "Port")
	position = pivot
	var drawn := Node3D.new()
	drawn.position = -pivot
	add_child(drawn)
	hung.commit(drawn, paints)


func _process(delta: float) -> void:
	var ship := get_parent_node_3d()
	if ship == null:
		return
	# The world's down in her axes: the way a boat hanging free would point.
	var down := ship.global_transform.basis.inverse() * Vector3.DOWN
	var plumb := atan2(down.z, -down.y)
	# In toward her centreline no further than its limit: there it lies against her.
	var inward := -plumb * _side
	if inward > _limit:
		plumb = -_limit * _side
	_swinging += ((plumb - _swing) * SWING_RATE * SWING_RATE - _swinging * SWING_DAMPING) * delta
	_swing += _swinging * delta
	if _swing * -_side > _limit:
		_swing = -_limit * _side
		_swinging = 0.0
	transform.basis = Basis(Vector3.RIGHT, -_swing)
