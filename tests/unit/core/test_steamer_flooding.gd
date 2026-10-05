extends GutTest
## §5b.4 layer 3, the steamer: a pinned seed's match hit and explicit hits, each baked
## alone and again with its holes' area × 0.9 and × 1.1 to the same outcome, so the
## seeds sit far from every threshold and a Mac and Linux agree (R21). Outcomes are
## labels and bands, never exact times.

const LIGHT := "res://tests/fixtures/sinking/hits/light.tres"
const FAST := "res://tests/fixtures/sinking/hits/fast.tres"
const MARGINS: Array[float] = [0.9, 1.0, 1.1]
## Water this far over a floor, in metres, is water.
const WET := 0.01

var _structure: ShipStructure
var _sea: SeaPhysics
var _scenario: SinkScenario


func before_all() -> void:
	_structure = SimFixtures.steamer().structure
	_sea = SeaPhysics.load_default()
	_scenario = load(SimFixtures.STEAMER_SINKING)


## [param damage] baked with every hole of its gash [param scale] times as big.
func _bake(damage: HitDamage, scale: float) -> SinkTimeline:
	var scaled := HitDamage.new()
	scaled.jammed = damage.jammed
	scaled.left_open = damage.left_open
	for opening: ShipOpening in damage.openings:
		var hole: ShipOpening = opening.duplicate()
		hole.area = opening.area * scale
		scaled.openings.append(hole)
	var stepper := SinkStepper.new(_structure, scaled, _sea)
	return SinkTimeline.bake(stepper, _sea, _scenario.bake_cap)


## Explicit [param hit] on the steamer, mapped as a tool's HIT= maps it.
func _damage(hit: IcebergHit) -> HitDamage:
	return HitMapper.map_explicit(hit, _structure, _scenario.hit)


func _head(timeline: SinkTimeline, frame: int, cell_name: StringName) -> float:
	return timeline.heads[frame * timeline.cells + _structure.cell_named(cell_name)]


func _floor(cell_name: StringName) -> float:
	return _structure.cells[_structure.cell_named(cell_name)].low.y


## The second of [param timeline]'s first [param kind] event naming [param named], or -1.
func _first(timeline: SinkTimeline, kind: SinkTimeline.Kind, named: StringName) -> float:
	for event: SinkTimeline.Event in timeline.events:
		if event.kind == kind and event.name == named:
			return event.seconds
	return -1.0


func _opening(opening_name: StringName) -> ShipOpening:
	for opening: ShipOpening in _structure.openings:
		if opening.name == opening_name:
			return opening
	return null


func test_two_compartments_and_open_ports_ends_gone() -> void:
	var seed_value := PinnedSeeds.seed_named(&"two_compartments_and_open_ports")
	var choice: MustSink.Choice = SimFixtures.match_hits(seed_value)[seed_value - 1]
	var walls := PackedFloat64Array()
	for wall: ShipWall in _structure.walls:
		if wall.axis == ShipWall.Axis.ACROSS:
			walls.append(wall.at)
	var compartments := {}
	for opening: ShipOpening in choice.damage.openings:
		var x := opening.centre.x
		var between := 0
		for at: float in walls:
			between += 1 if x > at else 0
		compartments[between] = true
	assert_gte(compartments.size(), 2, "the hit opens two compartments or more")
	assert_false(choice.damage.left_open.is_empty(), "with portholes left open")
	for scale: float in MARGINS:
		var timeline := _bake(choice.damage, scale)
		assert_eq(timeline.end, SinkTimeline.End.GONE, "gone, × %s" % scale)


func test_light_hit_ends_afloat() -> void:
	# Validation only: no match draws it (the must-sink rule throws it out).
	var damage := _damage(load(LIGHT))
	for scale: float in MARGINS:
		var timeline := _bake(damage, scale)
		assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "afloat, × %s" % scale)
		var sea := timeline.seas[timeline.count() - 1]
		assert_lt(sea, -2.6, "her lower deck still over the sea, × %s" % scale)


func test_open_porthole_floods_its_cabin_once_under() -> void:
	# The forward compartments holed and the door aft of the engine room jammed open:
	# she goes down slowly, the after cabins taking water through the door. With a
	# cabin's porthole left open too, nothing changes until the sea outside reaches the
	# porthole; from then the cabin floods through it as well.
	var port := _opening(&"port_aft_cabins_s3")
	var bottom := port.centre.y - port.size.y * 0.5
	var shut: Array[StringName] = []
	var opened: Array[StringName] = [&"port_aft_cabins_s3"]
	var jammed: Array[StringName] = [&"wtd_engine"]
	for scale: float in MARGINS:
		var closed := _bake(
			_damage(SimFixtures.explicit_hit(1, -2.0, 19.0, 1.0, 0.05, 1.5, jammed, shut)), scale
		)
		var open := _bake(
			_damage(SimFixtures.explicit_hit(1, -2.0, 19.0, 1.0, 0.05, 1.5, jammed, opened)), scale
		)
		var under := -1
		var poured := -1
		for frame in mini(closed.count(), open.count()):
			var before := _head(closed, frame, &"aft_cabins")
			var after := _head(open, frame, &"aft_cabins")
			if under == -1 and open.seas[frame] > bottom:
				under = frame
			if under == -1:
				assert_eq(
					after, before, "× %s: alike while the porthole is dry, s %d" % [scale, frame]
				)
				if after != before:
					break
			elif poured == -1 and after > before + WET:
				poured = frame
		assert_gt(under, 0, "× %s: the sea reaches the porthole" % scale)
		assert_gt(
			poured, under - 1, "× %s: and the cabin floods through it once it is under" % scale
		)


func test_shut_watertight_door_holds() -> void:
	# The hold and the forepeak holed: the engine room's floor ends under the sea
	# outside, and it stays dry behind its shut door; jammed open, it floods.
	var shut: Array[StringName] = []
	var jammed: Array[StringName] = [&"wtd_hold"]
	var engine_floor := _floor(&"engine_room")
	for scale: float in MARGINS:
		var held := _bake(
			_damage(SimFixtures.explicit_hit(1, 6.0, 19.0, 1.0, 0.05, 1.5, shut)), scale
		)
		var last := held.count() - 1
		assert_gt(held.seas[last], engine_floor, "× %s: its floor under the sea" % scale)
		var wettest := -INF
		for frame in held.count():
			wettest = maxf(wettest, _head(held, frame, &"engine_room"))
		assert_almost_eq(wettest, engine_floor, 1e-9, "× %s: the engine room stays dry" % scale)
		var through := _bake(
			_damage(SimFixtures.explicit_hit(1, 6.0, 19.0, 1.0, 0.05, 1.5, jammed)), scale
		)
		var flooded := _head(through, through.count() - 1, &"engine_room") - engine_floor
		assert_gt(flooded, 0.3, "× %s: jammed open, the engine room floods" % scale)


func test_water_spills_over_the_low_hold_wall() -> void:
	var top := 0.0
	for wall: ShipWall in _structure.walls:
		if wall.name == &"bulkhead_hold":
			top = wall.top
	assert_lt(top, 0.0, "the hold's after wall stops short of the deck")
	for scale: float in MARGINS:
		var timeline := _bake(_damage(load(FAST)), scale)
		var spilled := _first(timeline, SinkTimeline.Kind.SPILLING, &"over_bulkhead_hold_to_hold")
		assert_gt(spilled, 0.0, "× %s: water passes over it" % scale)
		# The step that spilled left one side's water over the top, higher than the
		# other's: a weir, not a doorway.
		var frame := roundi(spilled / timeline.step)
		var hold := _head(timeline, frame, &"hold")
		var engine := _head(timeline, frame, &"engine_room")
		assert_gt(maxf(hold, engine), top, "× %s: water over its top as it spills" % scale)
		assert_ne(hold, engine, "× %s: higher on one side" % scale)


func test_water_runs_down_a_stairwell() -> void:
	for scale: float in MARGINS:
		var timeline := _bake(_damage(load(FAST)), scale)
		var ran := _first(timeline, SinkTimeline.Kind.SPILLING, &"stair_engine_room_deckhouse_hall")
		var down := _first(timeline, SinkTimeline.Kind.SPILLING, &"stair_aft_cabins_sky")
		assert_gt(down, 0.0, "× %s: the sea runs down the after companionway" % scale)
		var frame := roundi(down / timeline.step)
		assert_gt(timeline.seas[frame], 0.0, "× %s: once the sea is over the deck" % scale)
		assert_lt(
			_head(timeline, frame - 1, &"aft_cabins"), 0.0, "× %s: into the cabins under it" % scale
		)
		assert_gt(ran, 0.0, "× %s: and through the inner stair" % scale)
