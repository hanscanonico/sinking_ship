extends GutTest
## Her windows from inside (ShipFittings): on every ship each window's inner pane stands
## on the room's face of the wall it is set in, never buried in the wall where no one
## inside sees it — wherever the opening's centre stands in that wall's thickness.

const RunMatch := preload("res://tools/run_match.gd")
## How far off a wall's face its pane may stand: its glass's and frame's proud.
const NEAR_FACE := 0.05

var _rules: BrawlRules


func before_all() -> void:
	_rules = RunMatch.default_config(1701).rules


func _fittings(space: ShipSpace) -> ShipFittings:
	var hull := SectionHull.of(space, _rules.railing_height)
	var fittings := ShipFittings.new(space, hull, _rules.body_radius, PackedVector3Array())
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, space.room_lines())
	var holder: Node3D = autofree(Node3D.new())
	var paints := {}
	for finish: int in ShipMesh.Finish.values():
		paints[finish] = StandardMaterial3D.new()
	fittings.build(mesh, holder, paints)
	return fittings


## The wall of [param space] that [param point] stands in, or null.
func _wall_holding(space: ShipSpace, point: Vector3) -> ShipBlocker:
	for blocker: ShipBlocker in space.layout.blockers:
		if (
			space.is_wall(blocker)
			and point.y >= blocker.bottom
			and point.y <= blocker.top
			and blocker.area.has_point(Vector2(point.x, point.z))
		):
			return blocker
	return null


func test_every_window_shows_inside_on_its_wall_s_room_face() -> void:
	for ship_name: StringName in Fleet.names():
		var space := ShipSpace.new(Fleet.layout(ship_name))
		var fittings := _fittings(space)
		var buried := PackedStringArray()
		var adrift := PackedStringArray()
		var windows := 0
		for pane: Array in fittings.panes:
			if pane[3]:
				continue
			windows += 1
			var inside: Vector3 = pane[1]
			var into: Vector3 = pane[2]
			if _wall_holding(space, inside) != null:
				buried.append(str(inside))
			elif (
				_wall_holding(space, inside - into * NEAR_FACE) == null
				and _wall_holding(space, inside - into * ShipSpace.WALL_MAX) != null
			):
				# A window in a wall stands on its face, not out in the room; one in her
				# shell — no wall holds it — stands its depth inboard of her plating.
				adrift.append(str(inside))
		if windows == 0:
			continue
		assert_eq(buried, PackedStringArray(), "%s: inner panes inside their walls" % ship_name)
		assert_eq(adrift, PackedStringArray(), "%s: inner panes off their walls" % ship_name)
