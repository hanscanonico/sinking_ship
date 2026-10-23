extends GutTest
## The lights on her open decks at dusk (DeckLights): a lamp over each door out onto an
## open deck, a red sidelight to port and a green one to starboard on her wheelhouse, a
## stern light on her ensign staff; none in a body's way on any ship; each out once the
## cell behind it has no power or its water has reached it.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")
## How high over the sea the test's poses lift her.
const LIFT := 50.0
## The steamer's doors out onto her open decks, ship plane (x, z): the doorways under
## the deckhouse's lintels — aft of her saloon, along its sides, the wheelhouse's to
## port and starboard — and the forecastle's door in its break.
const STEAMER_DOORS: Array[Vector2] = [
	Vector2(2.9, 0.0),
	Vector2(-0.85, -3.3),
	Vector2(1.55, -3.3),
	Vector2(-0.85, 3.3),
	Vector2(1.55, 3.3),
	Vector2(-2.5, -1.4),
	Vector2(-2.5, 1.4),
	Vector2(12.0, -2.425),
]
## The steamer's wheelhouse, ship plane.
const WHEELHOUSE := Rect2(-3.9, -1.4, 2.8, 2.8)

var _rules: BrawlRules


func before_all() -> void:
	_rules = RunMatch.default_config(1701).rules


## [param ship_name]'s lights, where her fittings' doors and glass put them.
func _lights(ship_name: StringName) -> DeckLights:
	var layout := Fleet.layout(ship_name)
	var space := ShipSpace.new(layout)
	var fittings := _fittings(space)
	return DeckLights.new(
		space, _rules.railing_height, _rules.body_radius, fittings.break_doors, fittings.panes
	)


func _fittings(space: ShipSpace) -> ShipFittings:
	var hull := SectionHull.of(space, _rules.railing_height)
	var fittings := ShipFittings.new(space, hull, _rules.body_radius, PackedVector3Array())
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines())
	var holder: Node3D = autofree(Node3D.new())
	fittings.build(mesh, holder, _plain_paints())
	return fittings


func _plain_paints() -> Dictionary:
	var paints := {}
	for finish: int in ShipMesh.Finish.values():
		paints[finish] = StandardMaterial3D.new()
	return paints


func test_the_steamer_has_a_lamp_over_each_door_onto_her_open_decks() -> void:
	var lights := _lights(&"steamer")
	var lamps: Array[Vector2] = []
	for index in lights.kinds.size():
		if lights.kinds[index] in [DeckLights.Kind.DOOR, DeckLights.Kind.BULKHEAD]:
			var at := lights.places[index].origin
			lamps.append(Vector2(at.x, at.z))
	assert_eq(lamps.size(), STEAMER_DOORS.size(), "one lamp a door")
	for door: Vector2 in STEAMER_DOORS:
		var nearest := INF
		for lamp: Vector2 in lamps:
			nearest = minf(nearest, lamp.distance_to(door))
		assert_lt(nearest, 0.6, "a lamp at the door at %s" % door)


func test_her_wheelhouse_shows_red_to_port_and_green_to_starboard() -> void:
	var lights := _lights(&"steamer")
	var port := 0
	var starboard := 0
	for index in lights.kinds.size():
		var at := lights.places[index].origin
		var on_it := at.x > WHEELHOUSE.position.x and at.x < WHEELHOUSE.end.x
		match lights.kinds[index]:
			DeckLights.Kind.PORT:
				assert_true(on_it and at.z < WHEELHOUSE.position.y, "on its port side")
				port += 1
			DeckLights.Kind.STARBOARD:
				assert_true(on_it and at.z > WHEELHOUSE.end.y, "on its starboard side")
				starboard += 1
	assert_eq([port, starboard], [1, 1])
	assert_eq(DeckLights.colour_of(DeckLights.Kind.PORT), ArtPalette.PORT_LIGHT)
	assert_eq(DeckLights.colour_of(DeckLights.Kind.STARBOARD), ArtPalette.STARBOARD_LIGHT)


func test_she_shows_a_stern_light_on_her_ensign_staff() -> void:
	var lights := _lights(&"steamer")
	var sterns := lights.kinds.filter(func(kind: int) -> bool: return kind == DeckLights.Kind.STERN)
	assert_eq(sterns.size(), 1)
	var at := lights.places[lights.kinds.find(DeckLights.Kind.STERN)].origin
	assert_between(at.x, -20.3, -20.0, "on the ensign staff over the poop's after rail")
	assert_gt(at.y, 1.2 + RoomDressing.HEADROOM, "over the heads on the poop")


func test_the_flat_lights_stand_within_a_wall_fitting_s_depth() -> void:
	assert_lte(DeckLights.BULKHEAD_DEPTH, FurnishingCheck.TOLERANCE)
	assert_lte(DeckLights.LANTERN_DEPTH, FurnishingCheck.TOLERANCE)


func test_no_light_on_any_ship_stands_in_a_body_s_way() -> void:
	for ship_name: StringName in Fleet.names():
		var layout := Fleet.layout(ship_name)
		var space := ShipSpace.new(layout)
		var fittings := _fittings(space)
		var lights := DeckLights.new(
			space, _rules.railing_height, _rules.body_radius, fittings.break_doors, fittings.panes
		)
		var holder: Node3D = autofree(Node3D.new())
		lights.build(holder, _plain_paints(), INF, Vector2(-INF, INF))
		var faces := PackedVector3Array()
		for node: Node in holder.get_node("DeckLights").get_children():
			var place := (node as Node3D).transform
			for corner: Vector3 in (node as MeshInstance3D).mesh.get_faces():
				faces.append(place * corner)
		assert_gt(faces.size(), 0, ship_name)
		var found := FurnishingCheck.intrusions(layout, _rules, faces)
		assert_eq(found, PackedStringArray(), ship_name)
		for index in lights.kinds.size():
			if lights.kinds[index] != DeckLights.Kind.DOOR:
				continue
			# A lamp over a doorway hangs in front of its frame, never into its opening.
			var place := lights.places[index]
			var lowest := place.origin.y + DeckLights.LAMP_BOX.position.y
			var deck := space.deck_under(Vector2(place.origin.x, place.origin.z), place.origin.y)
			assert_gte(lowest, deck + RoomDressing.HEADROOM - 0.001, "%s over headroom" % ship_name)


## A pose of the steamer upright, LIFT over the sea, dry, every cell lit by
## [param power].
func _pose(config: MatchConfig, power: int) -> ShipPose:
	var pose := ShipPose.new(-LIFT, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3.UP * LIFT))
	pose.cells = config.schedule().pose_at(0).cells
	for cell: FloodCell in config.ship.structure.cells:
		pose.levels.append(cell.low.y + LIFT)
		pose.lit.append(power)
	return pose


func test_a_light_goes_out_with_the_power_of_the_cell_behind_it() -> void:
	var config := RunMatch.default_config(1701, 0, &"steamer")
	var lights := _lights(&"steamer")
	var lit := 0
	lights.show_power(_pose(config, ShipPower.Power.MAIN))
	for index in lights.kinds.size():
		assert_eq(lights.glow_of(index), 1.0, "lit on her generator")
	var emergency := _pose(config, ShipPower.Power.EMERGENCY)
	lights.show_power(emergency)
	for index in lights.kinds.size():
		if emergency.cell_at(lights.behinds[index]) != CellMap.NONE:
			var dim := lights.glow_of(index)
			assert_almost_eq(dim, ShipLamp.EMERGENCY_GLOW, 0.001, "dim on her emergency power")
			lit += 1
	assert_gt(lit, 0, "some read a cell")
	var dark := _pose(config, ShipPower.Power.DARK)
	lights.show_power(dark)
	for index in lights.kinds.size():
		if dark.cell_at(lights.behinds[index]) != CellMap.NONE:
			assert_eq(lights.glow_of(index), 0.0, "out once its power is gone")


func test_a_light_goes_out_once_its_water_reaches_it() -> void:
	var config := RunMatch.default_config(1701, 0, &"steamer")
	var lights := _lights(&"steamer")
	var flooded := _pose(config, ShipPower.Power.MAIN)
	for cell in flooded.levels.size():
		flooded.levels[cell] = LIFT + 100.0
	lights.show_power(flooded)
	for index in lights.kinds.size():
		if flooded.cell_at(lights.behinds[index]) != CellMap.NONE:
			assert_eq(lights.glow_of(index), 0.0, "drowned")
	var cellless := ShipPose.new(-LIFT, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3.UP * LIFT))
	var fresh := _lights(&"steamer")
	fresh.show_power(cellless)
	for index in fresh.kinds.size():
		assert_eq(fresh.glow_of(index), 1.0, "a pose without cells leaves it lit")


func test_the_dressed_ship_puts_her_lights_out_with_her_power() -> void:
	var config := RunMatch.default_config(1701, 0, &"steamer")
	var art: ShipArt = autofree(ShipArt.new())
	art.build(config.ship, config.rules.railing_height, config.rules.body_radius)
	var port: MeshInstance3D = null
	for node: Node in art.get_node("DeckLights").get_children():
		if String(node.name).begins_with("Port"):
			port = node
	assert_not_null(port, "her port sidelight drawn")
	var glass := port.material_override as StandardMaterial3D
	assert_gt(glass.emission_energy_multiplier, 0.0, "lit")
	art.show_power(_pose(config, ShipPower.Power.DARK))
	assert_eq(glass.emission_energy_multiplier, 0.0, "out once her power is gone")
