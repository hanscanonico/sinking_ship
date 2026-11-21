extends GutTest
## A funnel once down rests on what it fell onto (FunnelArt.resting): tipped over the rim
## of its foot, never sunk into its deck, stopped on a deckhouse in its way — on every
## ship, whichever way it falls, nothing of it lies inside a room. The freighter's fell
## into her officers' cabins and its foot through her galley's ceiling.

const SHIPS := "res://data/ships/"
const FREIGHTER := "res://data/ships/freighter.tres"
## How many ways round each funnel is felled.
const WAYS := 8
## How far inside a room's walls, floor and ceiling a point of the funnel counts as in it.
const INSIDE := 0.15

## How high a room reaches where nothing roofs it: a body's height over its floor.
var _open_room := SimFixtures.rules().body_height


func test_a_fallen_funnel_lies_in_no_room() -> void:
	var funnels := 0
	for file: String in DirAccess.get_files_at(SHIPS):
		if not file.ends_with(".tres"):
			continue
		var layout: ShipLayout = load(SHIPS + file)
		if layout.structure == null:
			continue
		var surfaces: Surfaces = null
		for fitting: ShipFitting in layout.structure.fittings:
			if fitting.kind != ShipFitting.Kind.FUNNEL:
				continue
			funnels += 1
			if surfaces == null:
				surfaces = Surfaces.new(layout)
			for way in WAYS:
				var along := Vector2.from_angle(TAU * way / WAYS)
				var fall := FunnelFall.new(fitting, along, 0, 1, 2)
				var foot := FunnelArt.breaks_at(layout, fitting)
				var rest := FunnelArt.resting(layout, fall, foot)
				var lying := FunnelArt.turned(fall, 2.0, rest, foot)
				var what := (
					"%s's %s felled toward %s, %.1f° over" % [file, fitting.name, along, rest]
				)
				assert_eq(_room_holding(layout, surfaces, fitting, foot, lying), &"", what)
	assert_gt(funnels, 0, "some ship has a funnel the sinking can fell")


func test_a_funnel_with_nothing_in_its_way_lies_flat_on_its_deck() -> void:
	var layout: ShipLayout = load(FREIGHTER)
	var fitting := _funnel(layout)
	# Over her side, toward the open sea: nothing on her boat deck stands in its way.
	var fall := FunnelFall.new(fitting, Vector2(0.0, 1.0), 0, 1, 2)
	assert_almost_eq(FunnelArt.breaks_at(layout, fitting), fitting.base.y, 0.001)
	var foot := fitting.base.y
	assert_almost_eq(FunnelArt.resting(layout, fall, foot), FunnelArt.DOWN_DEG, 0.001)
	var lying := FunnelArt.turned(fall, 2.0, FunnelArt.DOWN_DEG, foot)
	var low := INF
	for point: Vector3 in _cylinder(fitting, foot):
		low = minf(low, (lying * point).y)
	assert_almost_eq(low, fitting.base.y, 0.001, "its side lies on its deck, not in it")


func test_the_freighters_funnel_rests_on_her_cabins() -> void:
	var layout: ShipLayout = load(FREIGHTER)
	var fitting := _funnel(layout)
	var fall := FunnelFall.new(fitting, Vector2(1.0, 0.0), 0, 1, 2)
	var rest := FunnelArt.resting(layout, fall, fitting.base.y)
	assert_lt(rest, 80.0, "held up by her cabins' after wall")
	assert_gt(rest, 30.0, "fallen onto them, not leaning")


func _funnel(layout: ShipLayout) -> ShipFitting:
	for fitting: ShipFitting in layout.structure.fittings:
		if fitting.kind == ShipFitting.Kind.FUNNEL:
			return fitting
	return null


## The name of the room some point of [param fitting]'s funnel over [param foot] lies
## inside, as [param lying] places it; empty for none.
func _room_holding(
	layout: ShipLayout, surfaces: Surfaces, fitting: ShipFitting, foot: float, lying: Transform3D
) -> StringName:
	var points := PackedVector3Array()
	var bounds := Rect2()
	for point: Vector3 in _cylinder(fitting, foot):
		var at := lying * point
		points.append(at)
		var flat := Rect2(at.x, at.z, 0.0, 0.0)
		bounds = flat if points.size() == 1 else bounds.merge(flat)
	for room: ShipRoom in layout.rooms:
		var area := room.area.grow(-INSIDE)
		if not area.intersects(bounds, true):
			continue
		for at: Vector3 in points:
			if not area.has_point(Vector2(at.x, at.z)) or at.y <= room.floor_height + INSIDE:
				continue
			var feet := Vector3(at.x, room.floor_height, at.z)
			var ceiling := minf(surfaces.ceiling(feet, INSIDE), room.floor_height + _open_room)
			if at.y < ceiling - INSIDE:
				return room.name
	return &""


## Points over [param fitting]'s funnel standing upright from [param foot] to its top:
## its skin and its axis.
func _cylinder(fitting: ShipFitting, foot: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var top := fitting.base.y + fitting.height
	var rings := ceili((top - foot) / 0.25)
	for ring in rings + 1:
		var y := lerpf(foot, top, float(ring) / rings)
		points.append(Vector3(fitting.base.x, y, fitting.base.z))
		for step in 16:
			var round := Vector2.from_angle(TAU * step / 16.0) * fitting.radius
			points.append(Vector3(fitting.base.x + round.x, y, fitting.base.z + round.y))
	return points
