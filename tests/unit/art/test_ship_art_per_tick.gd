extends GutTest
## What the dressed ship draws of her sinking is redrawn only as it changes (#87) — the
## broken railings, a deck's fall, the lamps' power — once a tick at most rather than
## every frame; drawn again unchanged it stays as it was, and every change is drawn.

const RunMatch := preload("res://tools/run_match.gd")
const BRIDGE := &"bridge"
## How high over the sea the test's poses lift her.
const LIFT := 50.0

var _layout: ShipLayout
var _rules: BrawlRules
var _cells: CellMap


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_cells = config.schedule().pose_at(0).cells


func _art() -> ShipArt:
	var art: ShipArt = autofree(ShipArt.new())
	var falls: Array[StringName] = [BRIDGE]
	var fails := PackedInt32Array(range(_layout.railings.size()))
	art.build(_layout, _rules.railing_height, _rules.body_radius, falls, fails)
	return art


func _deck(art: ShipArt) -> Node3D:
	for index in _layout.platforms.size():
		if _layout.platforms[index].name == BRIDGE:
			return art.get_node("Deck%d" % index)
	return null


## A pose of her upright, LIFT over the sea, dry, every cell lit by [param power].
func _pose(power: int) -> ShipPose:
	var pose := ShipPose.new(-LIFT, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3.UP * LIFT))
	pose.cells = _cells
	for cell: FloodCell in _layout.structure.cells:
		pose.levels.append(cell.low.y + LIFT)
		pose.lit.append(power)
	return pose


func test_a_railing_is_drawn_as_the_broken_ones_change() -> void:
	var art := _art()
	art.show_sinking([], {}, PackedInt32Array(), false)
	var rail := art.find_child("Railing0", true, false) as Node3D
	assert_true(rail.visible, "whole")
	art.show_sinking([], {}, PackedInt32Array([0]), false)
	assert_false(rail.visible, "broken")
	var remains := art.find_child("Railing0Remains", true, false) as Node3D
	assert_true(remains.visible, "its remains shown")
	art.show_sinking([], {}, PackedInt32Array([0]), false)
	assert_false(rail.visible, "the same broken ones again: still broken")
	assert_true(remains.visible)
	art.show_sinking([], {}, PackedInt32Array(), false)
	assert_true(rail.visible, "none broken: whole again")
	assert_false(remains.visible)


func test_a_deck_falling_is_moved_as_its_fall_changes() -> void:
	var art := _art()
	art.show_sinking([], {BRIDGE: 0.5}, PackedInt32Array(), false)
	var half := _deck(art).transform
	art.show_sinking([], {BRIDGE: 0.5}, PackedInt32Array(), false)
	assert_eq(_deck(art).transform, half, "as far fallen again: where it was")
	art.show_sinking([], {BRIDGE: 1.0}, PackedInt32Array(), false)
	var straight := _art()
	straight.show_sinking([], {BRIDGE: 1.0}, PackedInt32Array(), false)
	assert_ne(_deck(art).transform, half, "further fallen: moved")
	assert_eq(_deck(art).transform, _deck(straight).transform, "as one drawn straight there")


func test_a_rebuilt_ship_draws_its_deck_fallen_as_the_last_one_was() -> void:
	var art := _art()
	art.show_sinking([], {BRIDGE: 1.0}, PackedInt32Array([0]), false)
	var fallen := _deck(art).transform
	var falls: Array[StringName] = [BRIDGE]
	var fails := PackedInt32Array(range(_layout.railings.size()))
	art.build(_layout, _rules.railing_height, _rules.body_radius, falls, fails)
	art.show_sinking([], {BRIDGE: 1.0}, PackedInt32Array([0]), false)
	assert_eq(_deck(art).transform, fallen, "its new deck moved too")
	assert_false(
		(art.find_child("Railing0", true, false) as Node3D).visible, "its new railing broken too"
	)


func test_the_lamps_take_each_new_pose_s_power() -> void:
	var art := _art()
	var lamps := art.find_children("*", "ShipLamp", true, false)
	assert_gt(lamps.size(), 0, "she has lamps")
	for power: int in [0, 2, 0]:
		art.show_power(_pose(power))
		for lamp: ShipLamp in lamps:
			assert_eq(lamp.power, power, "%s on power %d" % [lamp.name, power])
