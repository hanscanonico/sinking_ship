extends GutTest
## A funnel that fell onto a deckhouse lies propped on it (FunnelRest), and holds a body
## back only where it is low enough to meet one (FallenFunnels): at its foot, never inside
## the house under it. The steamer's lay as a wall along the deck through her wheelhouse,
## 0.4 m off its side walls, and whoever it knocked down in there was held between the
## two for the rest of the match (#790). The steamer's funnel and wheelhouse, on the flat
## deck.

const FOOT := Vector3(-6.0, 0.0, 0.0)
const RADIUS := 0.9
const HEIGHT := 5.0
## The way it falls: toward her bow, onto the house.
const ALONG := Vector2(1.0, 0.0)
## The house, its walls' outer faces, how thick they are and how high they stand.
const HOUSE := Rect2(-4.0, -1.5, 3.0, 3.0)
const WALL := 0.2
const WALL_TOP := 2.2
## In the house: its middle, clear of every wall; and against its side wall, where the
## strip's edge left 0.4 m for a body 0.8 m wide.
const MIDDLE := Vector3(-2.5, 0.0, 0.0)
const BY_THE_WALL := Vector3(-1.7, 0.0, 0.9)
## Beside its foot, forward of where it stood and aft of the house.
const AT_ITS_FOOT := Vector3(-4.9, 0.0, 0.5)


func test_a_funnel_propped_on_a_deckhouse_holds_nobody_inside_it() -> void:
	var rules := SimFixtures.rules()
	var surfaces := _felled(_layout(true))
	assert_eq(_contacts(surfaces, MIDDLE, rules).size(), 0, "nothing in the room's middle")
	for contact: Surfaces.Contact in _contacts(surfaces, BY_THE_WALL, rules):
		assert_lt(contact.depth, rules.body_give, "by its wall, held by the wall alone")
	var port := MIDDLE + Vector3(0.0, 0.0, -1.0)
	var starboard := MIDDLE + Vector3(0.0, 0.0, 1.0)
	assert_false(
		surfaces.blocked(port, starboard, rules.body_height, rules.step_height),
		"nothing across the room"
	)


func test_a_funnel_propped_on_a_deckhouse_still_holds_a_body_at_its_foot() -> void:
	var rules := SimFixtures.rules()
	var surfaces := _felled(_layout(true))
	assert_gt(_contacts(surfaces, AT_ITS_FOOT, rules).size(), 0, "where it leans low")


func test_a_funnel_with_nothing_in_its_way_holds_a_body_all_along_it() -> void:
	var rules := SimFixtures.rules()
	var surfaces := _felled(_layout(false))
	assert_gt(_contacts(surfaces, AT_ITS_FOOT, rules).size(), 0, "at its foot")
	assert_gt(_contacts(surfaces, MIDDLE, rules).size(), 0, "where the house would stand")
	var tip := FOOT + Vector3(HEIGHT - 0.1, 0.0, 0.0)
	assert_gt(_contacts(surfaces, tip, rules).size(), 0, "at its top")
	var port := MIDDLE + Vector3(0.0, 0.0, -1.5)
	var starboard := MIDDLE + Vector3(0.0, 0.0, 1.5)
	assert_true(
		surfaces.blocked(port, starboard, rules.body_height, rules.step_height),
		"it lies across the way"
	)


## The flat deck with the funnel standing on it and, where [param housed], the house in
## its way.
func _layout(housed: bool) -> ShipLayout:
	var layout: ShipLayout = SimFixtures.open_deck()
	var funnel := ShipFitting.new()
	funnel.kind = ShipFitting.Kind.FUNNEL
	funnel.name = &"funnel"
	funnel.base = FOOT
	funnel.height = HEIGHT
	funnel.radius = RADIUS
	var fittings: Array[ShipFitting] = [funnel]
	layout.structure = ShipStructure.new()
	layout.structure.fittings = fittings
	var blockers: Array[ShipBlocker] = []
	if housed:
		var inside := HOUSE.size - Vector2(WALL, WALL)
		for area: Rect2 in [
			Rect2(HOUSE.position, Vector2(WALL, HOUSE.size.y)),
			Rect2(HOUSE.position + Vector2(inside.x, 0.0), Vector2(WALL, HOUSE.size.y)),
			Rect2(HOUSE.position, Vector2(HOUSE.size.x, WALL)),
			Rect2(HOUSE.position + Vector2(0.0, inside.y), Vector2(HOUSE.size.x, WALL)),
		]:
			var wall := ShipBlocker.new()
			wall.area = area
			wall.bottom = 0.0
			wall.top = WALL_TOP
			blockers.append(wall)
	layout.blockers = blockers
	return layout


## [param layout] as Surfaces has it with its funnel down, fallen toward the house.
func _felled(layout: ShipLayout) -> Surfaces:
	var surfaces := Surfaces.new(layout)
	var pose := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	pose.felled.append(FunnelFall.new(layout.structure.fittings[0], ALONG, 0, 1, 2))
	surfaces.honour(pose)
	return surfaces


## What holds back a body of [param rules] with its feet at [param feet].
func _contacts(surfaces: Surfaces, feet: Vector3, rules: BrawlRules) -> Array[Surfaces.Contact]:
	return surfaces.obstacle_contacts(feet, rules.body_radius, rules.body_height, rules.step_height)
