extends GutTest
## A piece of her deck gear made of more than its one envelope (DeckGear, #381): every
## piece of the fleet's gear is laid as its parts, its foot on its deck and each other part
## a blocker of its own where its model's space puts it; and every part of every model
## stands inside its envelope, its foot on the deck.

## How near a laid part stands to the place its piece's model gives it, in metres.
const NEAR := 0.001


## Whether [param laid], a part of a piece as DeckGear lays it, is [param blocker].
func _is(laid: ShipBlocker, blocker: ShipBlocker) -> bool:
	if laid.name != blocker.name or laid.shape != blocker.shape:
		return false
	if absf(laid.bottom - blocker.bottom) > NEAR or absf(laid.top - blocker.top) > NEAR:
		return false
	if laid.shape == ShipBlocker.Shape.CYLINDER:
		return (
			laid.centre.distance_to(blocker.centre) <= NEAR
			and absf(laid.radius - blocker.radius) <= NEAR
		)
	return (
		laid.area.position.distance_to(blocker.area.position) <= NEAR
		and laid.area.size.distance_to(blocker.area.size) <= NEAR
	)


func test_every_piece_of_the_fleet_s_gear_is_laid_as_its_parts() -> void:
	var pieces := 0
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		var gear: Array[ShipBlocker] = []
		for blocker: ShipBlocker in layout.blockers:
			if DeckFurniture.is_gear(blocker):
				gear.append(blocker)
		var placed := {}
		for blocker in gear:
			if DeckGear.foot_of(blocker) == Vector3.ZERO:
				continue
			pieces += 1
			for part: ShipBlocker in DeckGear.laid(blocker):
				var found := gear.filter(func(other: ShipBlocker) -> bool: return _is(part, other))
				var at := (
					part.centre if part.shape == ShipBlocker.Shape.CYLINDER else part.area.position
				)
				assert_eq(found.size(), 1, "%s's %s at %s, laid once" % [ship, part.name, at])
				for other: ShipBlocker in found:
					placed[other] = placed.get(other, 0) + 1
		for blocker in gear:
			assert_eq(
				placed.get(blocker, 0),
				1,
				"%s's %s from %s: a part of one piece" % [ship, blocker.name, blocker.bottom]
			)
	assert_gt(pieces, 0, "the Titanic's gear")


func test_every_model_s_parts_stand_inside_its_envelope_on_its_foot() -> void:
	for kind: StringName in DeckFurniture.GEAR:
		for size: Vector3 in DeckFurniture.GEAR[kind]:
			var made: String = DeckFurniture.GEAR[kind][size]
			var envelope := DeckGear.envelope(size).grow(NEAR)
			var parts := DeckGear.parts_of(kind, size)
			var foot: Array = parts[0]
			assert_eq(foot[0], kind, "%s's foot is named its kind" % made)
			assert_almost_eq(
				(foot[2] as AABB).position.y, 0.0, NEAR, "%s's foot on the deck" % made
			)
			var low := INF
			var high := -INF
			for part: Array in parts:
				var box: AABB = part[2]
				assert_true(envelope.encloses(box), "%s's %s inside its envelope" % [made, part[0]])
				if part[1] == DeckGear.ROUND:
					assert_almost_eq(
						box.size.x, box.size.z, NEAR, "%s's %s round" % [made, part[0]]
					)
				low = minf(low, box.position.y)
				high = maxf(high, box.end.y)
			assert_almost_eq(low, 0.0, NEAR, "%s from the deck" % made)
			assert_almost_eq(high, size.y, NEAR, "%s up to its height" % made)
			if foot[1] == DeckGear.BOX:
				var plan: Vector3 = (foot[2] as AABB).size
				assert_gte(plan.x, plan.z, "%s's foot longer along its x" % made)


func test_every_model_with_parts_is_one_her_gear_is_made_as() -> void:
	var made := {}
	for kind: StringName in DeckFurniture.GEAR:
		for size: Vector3 in DeckFurniture.GEAR[kind]:
			made[DeckFurniture.GEAR[kind][size]] = true
	for model: String in DeckGear.PARTS:
		assert_has(made, model, "%s is one of GEAR's models" % model)


func test_a_piece_across_her_is_turned_its_x_to_port_and_its_z_forward() -> void:
	var turn := DeckGear.turn()
	assert_almost_eq(
		turn * Vector3.RIGHT, Vector3.FORWARD, Vector3.ONE * NEAR, "its x along her -z"
	)
	assert_almost_eq(turn * Vector3.BACK, Vector3.RIGHT, Vector3.ONE * NEAR, "its z along her +x")
	assert_almost_eq(turn * Vector3.UP, Vector3.UP, Vector3.ONE * NEAR, "upright")
