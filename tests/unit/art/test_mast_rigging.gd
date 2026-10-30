extends GutTest
## Her masts' rigging (DeckWorks.rigging): halyards from the crosstree to the cleats,
## stays between her tall spars, the liner's wireless aerial and the cargo derricks over
## the hatches — and none of it where a body can be. Every point of every line stands
## within FurnishingCheck.TOLERANCE of a spar it is fixed to, or a body's height and
## jump over every top a body can stand on under it, on every ship of the fleet.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")
## How far apart along a line its points are tried.
const STEP := 0.05

var _rules: BrawlRules


func before_all() -> void:
	_rules = RunMatch.default_config(1701).rules


func _rigging(ship: String) -> Array[DeckWorks.RigLine]:
	return DeckWorks.rigging(Fleet.layout(StringName(ship)), _rules)


func _of_kind(lines: Array[DeckWorks.RigLine], kind: StringName) -> Array[DeckWorks.RigLine]:
	return lines.filter(func(line: DeckWorks.RigLine) -> bool: return line.kind == kind)


## The cylinder of [param layout] standing at ship-plane point [param at].
func _cylinder(layout: ShipLayout, at: Vector2) -> ShipBlocker:
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.CYLINDER and blocker.centre.is_equal_approx(at):
			return blocker
	return null


## [param layout]'s blockers whose box, grown by a body's radius, reaches the ship
## plane between [param from] and [param to].
func _blockers_near(layout: ShipLayout, from: Vector3, to: Vector3) -> Array[ShipBlocker]:
	var low := Vector2(minf(from.x, to.x), minf(from.z, to.z))
	var high := Vector2(maxf(from.x, to.x), maxf(from.z, to.z))
	var under := Rect2(low, high - low).grow(_rules.body_radius)
	var near: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		var area := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			var round := Vector2.ONE * blocker.radius
			area = Rect2(blocker.centre - round, round * 2.0)
		if area.grow(_rules.body_radius).intersects(under, true):
			near.append(blocker)
	return near


## The highest top a body can stand on whose round reaches over ship-plane point
## [param at] on [param layout] — a platform's, a ramp's or one of [param blockers]
## but [param spars] — or -INF.
func _top_under(
	layout: ShipLayout, blockers: Array[ShipBlocker], at: Vector2, spars: Array[ShipBlocker]
) -> float:
	var reach := _rules.body_radius
	var top := -INF
	for platform: ShipPlatform in layout.platforms:
		if platform.area.grow(reach).has_point(at):
			top = maxf(top, platform.height)
	for ramp: ShipRamp in layout.ramps:
		if ramp.area.grow(reach).has_point(at):
			top = maxf(top, maxf(ramp.start_height, ramp.end_height))
	for blocker: ShipBlocker in blockers:
		if spars.has(blocker):
			continue
		var near := (
			at.distance_to(blocker.centre) <= blocker.radius + reach
			if blocker.shape == ShipBlocker.Shape.CYLINDER
			else blocker.area.grow(reach).has_point(at)
		)
		if near:
			top = maxf(top, blocker.top)
	return top


func test_no_rig_line_stands_where_a_body_can_be() -> void:
	var headroom := _rules.body_height + _rules.jump_height
	for ship: String in Fleet.names():
		var layout := Fleet.layout(StringName(ship))
		for line in DeckWorks.rigging(layout, _rules):
			var half := line.thickness * 0.5
			var steps := maxi(1, ceili(line.from.distance_to(line.to) / STEP))
			var found := ""
			var blockers := _blockers_near(layout, line.from, line.to)
			for step in steps + 1:
				var point := line.from.lerp(line.to, float(step) / steps)
				var at := Vector2(point.x, point.z)
				var held := false
				for spar in line.spars:
					var off := at.distance_to(spar.centre) + half - spar.radius
					held = held or off <= FurnishingCheck.TOLERANCE
				if held:
					continue
				var top := _top_under(layout, blockers, at, line.spars)
				if point.y - half < top + headroom:
					found = (
						"%s at %s, %.2f m over a top at %.2f" % [ship, point, point.y - top, top]
					)
					break
			assert_eq(found, "", "the %s from %s to %s clears" % [line.kind, line.from, line.to])


func test_the_steamer_s_mast_has_a_halyard_each_side() -> void:
	var layout := Fleet.layout(&"steamer")
	var mast := _cylinder(layout, Vector2(16.0, 0.0))
	var halyards := _of_kind(_rigging("steamer"), &"halyard")
	for side: float in [-1.0, 1.0]:
		var on_side := halyards.filter(
			func(line: DeckWorks.RigLine) -> bool: return line.from.z * side > 0.0
		)
		assert_gt(on_side.size(), 0, "a halyard on side %+.0f" % side)
		var lowest := INF
		for line: DeckWorks.RigLine in on_side:
			assert_true(line.spars.has(mast), "fixed to her mast")
			lowest = minf(lowest, minf(line.from.y, line.to.y))
		assert_almost_eq(lowest, mast.bottom + DeckWorks.CLEAT, 0.001, "down to the cleat")


func test_the_steamer_s_mast_is_stayed_to_her_funnel() -> void:
	var layout := Fleet.layout(&"steamer")
	var mast := _cylinder(layout, Vector2(16.0, 0.0))
	var funnel := _cylinder(layout, Vector2(-6.0, 0.0))
	var stays := _of_kind(_rigging("steamer"), &"stay")
	assert_eq(stays.size(), 1, "one stay")
	if stays.is_empty():
		return
	var stay: DeckWorks.RigLine = stays[0]
	assert_true(stay.spars.has(mast) and stay.spars.has(funnel), "mast to funnel")
	assert_eq(stay.funnel, funnel, "it goes with the funnel if she falls")


func test_the_liner_s_masts_are_stayed_and_carry_her_aerial() -> void:
	# Her mainmast where each liner's plan puts it: the Titanic's her A deck's plate (#360).
	for ship: String in ["small_titanic", "titanic"]:
		var layout := Fleet.layout(StringName(ship))
		var fore := _cylinder(layout, Vector2(96.0, 0.0))
		var aft := -92.5 if ship == "small_titanic" else -88.625
		var main := _cylinder(layout, Vector2(aft, 0.0))
		var lines := _rigging(ship)
		var between := func(line: DeckWorks.RigLine) -> bool:
			return line.spars.has(fore) and line.spars.has(main)
		var stays := _of_kind(lines, &"stay").filter(between)
		assert_eq(stays.size(), 1, "%s: a stay mast to mast" % ship)
		var aerial := _of_kind(lines, &"aerial").filter(between)
		assert_between(aerial.size(), 2, 4, "%s: two to four aerial wires" % ship)
		assert_eq(_of_kind(lines, &"spreader").size(), 2, "%s: a spreader at each masthead" % ship)


func test_the_steamer_s_mast_works_her_hatch_with_a_derrick() -> void:
	var layout := Fleet.layout(&"steamer")
	var mast := _cylinder(layout, Vector2(16.0, 0.0))
	var lines := _rigging("steamer")
	var booms := _of_kind(lines, &"boom")
	assert_eq(booms.size(), 1, "one boom")
	if booms.is_empty():
		return
	var boom: DeckWorks.RigLine = booms[0]
	assert_true(boom.spars.has(mast), "on her mast")
	var head := Vector2(boom.to.x, boom.to.z)
	var hatch_under := false
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.BOX and blocker.area.has_point(head):
			hatch_under = hatch_under or blocker.area.get_center().is_equal_approx(head)
	assert_true(hatch_under, "its head over a hatch's middle")
	var rise := rad_to_deg(
		atan2(boom.to.y - boom.from.y, Vector2(boom.from.x, boom.from.z).distance_to(head))
	)
	assert_between(rise, 25.0 - 0.01, 35.0, "topped up")
	for kind: StringName in [&"lift", &"runner", &"hook", &"gooseneck"]:
		assert_eq(_of_kind(lines, kind).size(), 1, "its %s" % kind)
