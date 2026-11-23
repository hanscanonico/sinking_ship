extends GutTest
## A funnel once down (SH31, FallenFunnels): the upright blocker it stood as holds
## nothing over its foot any more, on every ship that has one — the trawler's stack
## too, whose foot, 2.3 m up, is 2.2999999523 in single precision (#142) —, and nothing
## over where it broke off, when that is a roof it stood through.

const TRAWLER := "res://data/ships/trawler.tres"
const TITANIC := "res://data/ships/titanic.tres"
## The way each funnel is laid down here: toward her bow.
const ALONG := Vector2(1.0, 0.0)
## A roof a funnel stands through, over a body's head in the room under it: its slab.
const ROOF := Rect2(-9.0, -3.0, 8.0, 6.0)
const ROOF_BOTTOM := 2.4
const ROOF_TOP := 2.6


func test_a_fallen_funnel_leaves_nothing_where_it_stood() -> void:
	var rules := SimFixtures.rules()
	var clear_of := rules.body_radius + 0.01
	for layout: ShipLayout in [SimFixtures.steamer(), load(TRAWLER), load(TITANIC)]:
		var ship := layout.resource_path.get_file().get_basename()
		var surfaces := Surfaces.new(layout)
		var funnels := 0
		for fitting: ShipFitting in layout.structure.fittings:
			if fitting.kind != ShipFitting.Kind.FUNNEL:
				continue
			funnels += 1
			var what := "%s's %s" % [ship, fitting.name]
			var foot := Vector2(fitting.base.x, fitting.base.z)
			assert_not_null(_upright(layout, foot), what + ": stands as a blocker")
			# Pressed against its after side, a hair clear of the strip it lies along
			# once down: held off by it standing, by nothing once it has fallen.
			var behind := foot - ALONG * clear_of
			var feet := Vector3(behind.x, fitting.base.y, behind.y)
			var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
			surfaces.honour(pose)
			var standing := _contacts(surfaces, feet, rules)
			assert_false(standing.is_empty(), what + ": held off while it stands")
			var down := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
			down.felled.append(FunnelFall.new(fitting, ALONG, 0, 1, 2))
			surfaces.honour(down)
			assert_eq(_contacts(surfaces, feet, rules).size(), 0, what + ": free once down")
		assert_gt(funnels, 0, "%s has a funnel" % ship)


func test_a_funnel_standing_through_a_roof_leaves_its_casing_standing_under_it() -> void:
	# It breaks off where it rises out of the roof (FunnelRest.breaks_at), small Titanic's
	# first as it does: its casing stands on in the room under that roof, round and whole,
	# and the funnel lies on the roof, holding nobody in the room.
	var rules := SimFixtures.rules()
	var layout := _roofed()
	var fitting := layout.structure.fittings[0]
	var foot := Vector2(fitting.base.x, fitting.base.z)
	assert_almost_eq(FunnelRest.breaks_at(layout, fitting), ROOF_TOP, 0.001, "breaks at the roof")
	var surfaces := Surfaces.new(layout)
	var down := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	down.felled.append(FunnelFall.new(fitting, ALONG, 0, 1, 2))
	surfaces.honour(down)
	var pressed := fitting.radius + rules.body_radius - 0.1
	for side: Vector2 in [ALONG, -ALONG, ALONG.orthogonal()]:
		var under := _feet(foot + side * pressed, fitting.base.y)
		assert_gt(_contacts(surfaces, under, rules).size(), 0, "in the room, held off its casing")
	var along_it := foot + ALONG * (pressed + 0.6)
	var room := _contacts(surfaces, _feet(along_it, fitting.base.y), rules)
	assert_eq(room.size(), 0, "in the room, nothing along the way it fell")
	var roof := _contacts(surfaces, _feet(along_it, ROOF_TOP), rules)
	assert_gt(roof.size(), 0, "on the roof, held off it where it lies")
	var behind := _feet(foot - ALONG * (rules.body_radius + 0.1), ROOF_TOP)
	assert_eq(_contacts(surfaces, behind, rules).size(), 0, "on the roof, nothing over its casing")


## The flat deck with a funnel standing on it through the roof of a house over its foot.
func _roofed() -> ShipLayout:
	var layout: ShipLayout = SimFixtures.open_deck()
	var funnel := ShipFitting.new()
	funnel.kind = ShipFitting.Kind.FUNNEL
	funnel.name = &"funnel"
	funnel.base = Vector3(-6.0, 0.0, 0.0)
	funnel.height = 5.0
	funnel.radius = 0.9
	var fittings: Array[ShipFitting] = [funnel]
	layout.structure = ShipStructure.new()
	layout.structure.fittings = fittings
	var upright := ShipBlocker.new()
	upright.shape = ShipBlocker.Shape.CYLINDER
	upright.centre = Vector2(funnel.base.x, funnel.base.z)
	upright.radius = funnel.radius
	upright.bottom = funnel.base.y
	upright.top = funnel.base.y + funnel.height
	var roof := ShipBlocker.new()
	roof.area = ROOF
	roof.bottom = ROOF_BOTTOM
	roof.top = ROOF_TOP
	var blockers: Array[ShipBlocker] = [upright, roof]
	layout.blockers = blockers
	return layout


## Feet at [param at] (x/z), [param height] high.
func _feet(at: Vector2, height: float) -> Vector3:
	return Vector3(at.x, height, at.y)


## The cylinder blocker of [param layout] whose round holds [param foot] (x/z), or null.
func _upright(layout: ShipLayout, foot: Vector2) -> ShipBlocker:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			if blocker.centre.distance_to(foot) <= blocker.radius:
				return blocker
	return null


## What holds back a body of [param rules] with its feet at [param feet].
func _contacts(surfaces: Surfaces, feet: Vector3, rules: BrawlRules) -> Array[Surfaces.Contact]:
	return surfaces.obstacle_contacts(feet, rules.body_radius, rules.body_height, rules.step_height)
