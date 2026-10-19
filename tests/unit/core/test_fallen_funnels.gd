extends GutTest
## A funnel once down (SH31, FallenFunnels): the upright blocker it stood as holds
## nothing over its foot any more, on every ship that has one — the trawler's stack
## too, whose foot, 2.3 m up, is 2.2999999523 in single precision (#142).

const TRAWLER := "res://data/ships/trawler.tres"
const TITANIC := "res://data/ships/titanic.tres"
## The way each funnel is laid down here: toward her bow.
const ALONG := Vector2(1.0, 0.0)


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
