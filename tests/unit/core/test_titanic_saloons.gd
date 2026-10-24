extends GutTest
## Her laid saloons (tools/gen_titanic.py): every dining table a prop with a chair at
## each quarter facing it, and as she sails nothing of her furniture stands in anything —
## another piece, a wall, a blocker, a railing — nor on a seat's start, so every piece
## starts at rest where it is laid.

const TITANIC := "res://data/ships/titanic.tres"

var _layout: ShipLayout


func before_all() -> void:
	_layout = load(TITANIC)


func _of(kind: StringName) -> PackedInt32Array:
	var found := PackedInt32Array()
	for index in _layout.props.size():
		if _layout.props[index].kind == kind:
			found.append(index)
	return found


func test_every_laid_table_has_a_chair_at_each_quarter_facing_it() -> void:
	var tables := _of(&"dining_table")
	var chairs := _of(&"dining_chair")
	assert_gt(tables.size(), 90, "her dining saloons and restaurant are laid")
	assert_eq(chairs.size(), tables.size() * 4)
	var reach := PropKind.named(&"dining_table").radius + PropKind.named(&"dining_chair").radius
	var seated := {}
	for table: int in tables:
		var at := _layout.props[table].pos
		var around := 0
		for chair: int in chairs:
			var pos := _layout.props[chair].pos
			var off := Vector2(at.x - pos.x, at.z - pos.z)
			if absf(pos.y - at.y) > 0.001 or off.length() > reach + 0.1:
				continue
			around += 1
			seated[chair] = true
			var facing := deg_to_rad(_layout.props[chair].facing_deg)
			assert_gt(Vector2.from_angle(facing).dot(off.normalized()), 0.999, "it faces its table")
		assert_eq(around, 4, "four chairs at table %d" % table)
	assert_eq(seated.size(), chairs.size(), "every chair is at a table")


func test_no_piece_of_furniture_stands_in_anything_or_on_a_start() -> void:
	var rules := SimFixtures.rules()
	var surfaces := Surfaces.new(_layout)
	var calm := ShipPose.new(0.0, 0.0, 0.0, Transform3D.IDENTITY)
	surfaces.honour(calm, PackedInt32Array(), PropState.from_layout(_layout))
	for index in _layout.props.size():
		var prop := _layout.props[index]
		if prop.railing != -1:
			continue
		var floor := surfaces.under(prop.pos, rules.step_height, index)
		assert_ne(floor, Surfaces.NONE, "prop %d stands on her deck" % index)
		var held := surfaces.obstacle_contacts(
			prop.pos, prop.radius, prop.height, rules.step_height, index
		)
		assert_eq(held.size(), 0, "prop %d at %s stands in nothing" % [index, prop.pos])
		assert_eq(surfaces.rail_contacts(prop.pos, prop.radius, floor).size(), 0)
		for spawn: Vector3 in _layout.spawns:
			var apart := Vector2(spawn.x - prop.pos.x, spawn.z - prop.pos.z).length()
			if absf(spawn.y - prop.pos.y) < rules.step_height:
				assert_gt(
					apart, prop.radius + rules.body_radius, "prop %d clear of a start" % index
				)
