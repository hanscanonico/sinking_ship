extends GutTest
## A piece of her deck gear made of more than its one envelope (DeckGear, #381): every
## piece of the fleet's gear is laid as its parts, its foot on its deck and each other part
## a blocker of its own where its model's space puts it; and every part of every model
## stands inside its envelope, its foot on the deck. Her electric cranes are stowed, each
## jib level on a crutch post on the deck under its head, pointing the way Plate III's
## elevation draws its pair's.

## How near a laid part stands to the place its piece's model gives it, in metres.
const NEAR := 0.001
## The way each pair of the Titanic's electric cranes points its jib along her (Plate
## III's elevation), by the deck it stands on: her poop's forward, her after well's and A
## deck's aft, her forward well's forward (tools/gen_titanic.py's CRANE_JIBS).
const JIBS := {3.3125: 1.0, 0.0: -1.0, 5.5: -1.0, 1.5625: 1.0}

var _rules: BrawlRules = load("res://data/rules/brawl.tres")


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
			for part: ShipBlocker in DeckGear.laid(layout, blocker):
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
			var envelope := DeckGear.envelope_of(made, size).grow(NEAR)
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
			var drop: float = DeckGear.DROPS.get(made, 0.0)
			assert_almost_eq(low, -drop, NEAR, "%s from the deck, or the one under it" % made)
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


func test_a_piece_the_other_way_about_is_turned_half_round() -> void:
	var half := DeckGear.half_turn()
	assert_eq(half * Vector3.RIGHT, Vector3.LEFT, "its x along her -x, exactly")
	assert_eq(half * Vector3.BACK, Vector3.FORWARD, "its z along her -z, exactly")
	assert_eq(half * Vector3.UP, Vector3.UP, "upright")


## Each of her electric cranes stands as its parts say: its jib the way Plate III draws its
## pair's, lying level along her from its house's face, its top flush with the house's
## and its underside over a standing body on every deck under it; and its crutch post
## under its head, on a deck there, up to the jib.
func test_her_cranes_jibs_lie_stowed_on_their_crutch_posts() -> void:
	var titanic := Fleet.layout(&"titanic")
	var cranes := 0
	for blocker: ShipBlocker in titanic.blockers:
		if blocker.name != &"electric crane":
			continue
		cranes += 1
		var at := "the crane at %s" % blocker.centre
		var parts := DeckGear.laid(titanic, blocker)
		assert_eq(parts.size(), 4, "%s: its pedestal, house, jib and crutch" % at)
		if parts.size() != 4:
			continue
		var house: ShipBlocker = parts[1]
		var jib: ShipBlocker = parts[2]
		var crutch: ShipBlocker = parts[3]
		assert_eq(jib.name, &"electric crane jib", at)
		assert_eq(crutch.name, &"electric crane crutch", at)
		var way: float = JIBS.get(blocker.bottom, 0.0)
		assert_ne(way, 0.0, "%s: on a deck she has cranes on" % at)
		var heel := house.area.end.x if way > 0.0 else house.area.position.x
		var head := jib.area.end.x if way > 0.0 else jib.area.position.x
		var foot := jib.area.position.x if way > 0.0 else jib.area.end.x
		assert_almost_eq(foot, heel, NEAR, "%s: its jib from its house" % at)
		assert_gt((head - heel) * way, 6.0, "%s: its jib the way the plate draws it" % at)
		assert_almost_eq(jib.top, house.top, NEAR, "%s: its jib's top flush with its house's" % at)
		assert_almost_eq(jib.area.get_center().y, blocker.centre.y, NEAR, "%s: along her" % at)
		assert_almost_eq(crutch.top, jib.bottom, NEAR, "%s: its crutch up to its jib" % at)
		assert_almost_eq(crutch.centre.y, blocker.centre.y, NEAR, "%s: its crutch under it" % at)
		assert_almost_eq(
			crutch.centre.x + way * crutch.radius, head, NEAR, "%s: under its head" % at
		)
		assert_true(_stands_on_a_deck(titanic, crutch), "%s: its crutch on a deck" % at)
		for platform: ShipPlatform in titanic.platforms:
			if platform.area.intersects(jib.area) and platform.height < jib.bottom:
				assert_gt(
					jib.bottom - platform.height,
					_rules.body_height,
					"%s: a body on %s walks under it" % [at, platform.name]
				)
		for ramp: ShipRamp in titanic.ramps:
			var highest := maxf(ramp.start_height, ramp.end_height)
			if ramp.area.intersects(jib.area) and highest < jib.bottom:
				assert_gt(
					jib.bottom - highest, _rules.body_height, "%s: a body on a ladder too" % at
				)
	assert_eq(cranes, 8, "her eight cranes")


## Whether one of [param layout]'s platforms holds [param post]'s axis at its foot.
func _stands_on_a_deck(layout: ShipLayout, post: ShipBlocker) -> bool:
	for platform: ShipPlatform in layout.platforms:
		if (
			absf(platform.height - post.bottom) < NEAR
			and platform.contains(post.centre.x, post.centre.y)
		):
			return true
	return false
