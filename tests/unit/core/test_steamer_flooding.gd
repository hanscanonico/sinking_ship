extends GutTest
## §5b.4 layer 3, the steamer: pinned seeds' match hits — bow_down_slow, stern_down,
## heavy_list and two_compartments_and_open_ports — and explicit hits, each baked alone
## and again with its holes' area × 0.9 and × 1.1 to the same outcome, so the seeds sit
## far from every threshold and a Mac and Linux agree (R21). Outcomes are labels and
## bands, never exact times.

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


## How high ship point [param point] stands along the world's up from her origin at
## [param timeline]'s kept step [param frame]: as the sea's and the heads' heights are.
func _up_height(timeline: SinkTimeline, frame: int, point: Vector3) -> float:
	var r := timeline.rotations
	return r[frame * 9 + 3] * point.x + r[frame * 9 + 4] * point.y + r[frame * 9 + 5] * point.z


## How deep cell [param cell_name]'s water stands over its lowest corner at kept step
## [param frame].
func _depth(timeline: SinkTimeline, frame: int, cell_name: StringName) -> float:
	var cell := _structure.cells[_structure.cell_named(cell_name)]
	var lowest := INF
	for corner in 8:
		var point := Vector3(
			cell.high.x if corner & 1 else cell.low.x,
			cell.high.y if corner & 2 else cell.low.y,
			cell.high.z if corner & 4 else cell.low.z
		)
		lowest = minf(lowest, _up_height(timeline, frame, point))
	return _head(timeline, frame, cell_name) - lowest


## The height along the world's up of the lowest corner of [param opening] at kept step
## [param frame].
func _bottom(timeline: SinkTimeline, frame: int, opening: ShipOpening) -> float:
	var lowest := INF
	for corner in 8:
		var point := opening.centre
		for axis in 3:
			point[axis] += opening.size[axis] * (0.5 if corner & (1 << axis) else -0.5)
		lowest = minf(lowest, _up_height(timeline, frame, point))
	return lowest


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


## [param seed_value]'s match hit — after the must-sink rule — baked with its holes
## [param scale] times as big.
func _pinned(seed_name: StringName, scale: float) -> SinkTimeline:
	var seed_value := PinnedSeeds.seed_named(seed_name)
	var choice: MustSink.Choice = SimFixtures.match_hits(seed_value)[seed_value - 1]
	return _bake(choice.damage, scale)


## [param timeline]'s list and trim at kept step [param frame], in degrees: starboard
## down and bow down, as the HUD reads them.
func _heel(timeline: SinkTimeline, frame: int) -> float:
	var r := timeline.rotations
	return rad_to_deg(atan2(r[frame * 9 + 7], r[frame * 9 + 8]))


func _trim(timeline: SinkTimeline, frame: int) -> float:
	var r := timeline.rotations
	return rad_to_deg(atan2(-r[frame * 9 + 3], r[frame * 9]))


## The most [param timeline] trims her either way before she is gone — by the head
## positive — and the most it lists her before her deck goes under.
func _leans(timeline: SinkTimeline) -> Vector3:
	var gone := timeline.frame_at(timeline.gone_at)
	var plunge := timeline.frame_at(_first(timeline, SinkTimeline.Kind.PLUNGING, &""))
	var most := Vector3.ZERO
	for frame in gone + 1:
		most.x = maxf(most.x, _trim(timeline, frame))
		most.y = minf(most.y, _trim(timeline, frame))
		if frame <= plunge:
			most.z = maxf(most.z, absf(_heel(timeline, frame)))
	return most


func test_bow_down_slow_trims_her_by_the_head_before_the_end() -> void:
	# A long gash forward: the bow settles and the water spills aft over the low walls,
	# a long middle, then a fast end — by the head, over 10° before she goes, never
	# listing 7°.
	for scale: float in MARGINS:
		var timeline := _pinned(&"bow_down_slow", scale)
		assert_eq(timeline.end, SinkTimeline.End.GONE, "× %s: gone" % scale)
		assert_gt(timeline.gone_at, 600.0, "× %s: slowly, over 10 min" % scale)
		var leans := _leans(timeline)
		assert_gt(leans.x, 10.0, "× %s: over 10° by the head" % scale)
		assert_gt(leans.x, -leans.y, "× %s: by the head, not the stern" % scale)
		assert_lt(leans.z, 7.0, "× %s: listing under 7°" % scale)


func test_stern_down_trims_her_by_the_stern_before_the_end() -> void:
	# Holed aft: her after compartments fill and she goes down by the stern, over 10°
	# before she goes.
	for scale: float in MARGINS:
		var timeline := _pinned(&"stern_down", scale)
		assert_eq(timeline.end, SinkTimeline.End.GONE, "× %s: gone" % scale)
		var leans := _leans(timeline)
		assert_lt(leans.y, -10.0, "× %s: over 10° by the stern" % scale)
		assert_gt(-leans.y, leans.x, "× %s: by the stern, not the head" % scale)


func test_heavy_list_holds_15_degrees_for_5_minutes_afloat() -> void:
	# A shallow gash floods the half of her bilges on its side, bounded by her centre
	# girder: the weight all on one side, she lies over 15° or more for 5 minutes and
	# longer while afloat, her high side's boats useless and her low side's not.
	for scale: float in MARGINS:
		var timeline := _pinned(&"heavy_list", scale)
		var end := timeline.gone_at if timeline.gone_at >= 0.0 else timeline.length()
		var longest := 0.0
		var since := -1.0
		var side := 0.0
		for frame in timeline.frame_at(end) + 1:
			var heel := _heel(timeline, frame)
			if absf(heel) >= 15.0 and (since < 0.0 or signf(heel) == side):
				if since < 0.0:
					since = timeline.times[frame]
					side = signf(heel)
				longest = maxf(longest, timeline.times[frame] - since)
			else:
				since = -1.0
		assert_gte(longest, 300.0, "× %s: 15° or more for 5 min" % scale)
		var high := &"port" if side > 0.0 else &"starboard"
		var low := &"starboard" if side > 0.0 else &"port"
		var useless := _first(timeline, SinkTimeline.Kind.BOATS_USELESS, high)
		assert_between(useless, 0.0, end, "× %s: her %s boats useless" % [scale, high])
		var lowered := _first(timeline, SinkTimeline.Kind.BOATS_USELESS, low)
		assert_true(
			lowered < 0.0 or lowered > useless + 300.0,
			"× %s: her %s boats not, while she lies over" % [scale, low]
		)


func test_light_hit_ends_afloat() -> void:
	# Validation only: no match draws it (the must-sink rule throws it out).
	var damage := _damage(load(LIGHT))
	for scale: float in MARGINS:
		var timeline := _bake(damage, scale)
		assert_eq(timeline.end, SinkTimeline.End.AFLOAT, "afloat, × %s" % scale)
		var last := timeline.count() - 1
		var heel := rad_to_deg(asin(timeline.rotations[last * 9 + 7]))
		assert_lt(absf(heel), 7.0, "listing under 7°, × %s" % scale)
		assert_lt(timeline.seas[last], SinkTimeline.MAIN_DECK, "her deck clear, × %s" % scale)


func test_open_porthole_floods_its_cabin_once_under() -> void:
	# The forward compartments holed and the door aft of the engine room jammed open:
	# she goes down slowly, the after cabins taking water through the door. With a
	# cabin's porthole left open too, nothing changes until the sea outside reaches the
	# porthole; from then the cabin floods through it as well.
	var port := _opening(&"port_aft_cabins_s3")
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
			if under == -1 and open.seas[frame] > _bottom(open, frame, port):
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
	# The hold and the forepeak holed: she settles by the head until the engine room's
	# floor is under the sea outside. Behind its shut door it takes no water until the
	# hold's water, trimmed aft, tops the low wall between them and spills over it; the
	# door jammed open, it floods long before.
	var shut: Array[StringName] = []
	var jammed: Array[StringName] = [&"wtd_hold"]
	var engine := _structure.cells[_structure.cell_named(&"engine_room")]
	var floor_middle := Vector3((engine.low.x + engine.high.x) * 0.5, engine.low.y, 0.0)
	for scale: float in MARGINS:
		var held := _bake(
			_damage(SimFixtures.explicit_hit(1, 6.0, 19.0, 1.0, 0.05, 1.5, shut)), scale
		)
		var plunge := held.frame_at(_first(held, SinkTimeline.Kind.PLUNGING, &""))
		assert_gt(
			held.seas[plunge],
			_up_height(held, plunge, floor_middle),
			"× %s: its floor under the sea" % scale
		)
		var over := _over_the_wall(held)
		var wet := _first(held, SinkTimeline.Kind.FLOODING, &"engine_room")
		assert_true(wet < 0.0 or wet >= over, "× %s: dry until water tops the wall" % scale)
		var through := _bake(
			_damage(SimFixtures.explicit_hit(1, 6.0, 19.0, 1.0, 0.05, 1.5, jammed)), scale
		)
		var flooded := _first(through, SinkTimeline.Kind.FLOODING, &"engine_room")
		var spilled := _over_the_wall(through)
		assert_gt(flooded, 0.0, "× %s: jammed open, the engine room floods" % scale)
		assert_true(spilled < 0.0 or flooded < spilled, "× %s: through the door" % scale)


## The second water first tops the hold's after wall into the engine room in
## [param timeline], from the hold or a side void; INF for never.
func _over_the_wall(timeline: SinkTimeline) -> float:
	var first := INF
	for event: SinkTimeline.Event in timeline.events:
		if (
			event.kind == SinkTimeline.Kind.SPILLING
			and event.name.begins_with("over_bulkhead_hold")
		):
			first = minf(first, event.seconds)
	return first


func test_water_spills_over_the_low_hold_wall() -> void:
	var top := 0.0
	for wall: ShipWall in _structure.walls:
		if wall.name == &"bulkhead_hold":
			top = wall.top
	assert_lt(top, 0.0, "the hold's after wall stops short of the deck")
	var gap := _opening(&"over_bulkhead_hold_to_hold")
	for scale: float in MARGINS:
		var timeline := _bake(_damage(load(FAST)), scale)
		var spilled := _first(timeline, SinkTimeline.Kind.SPILLING, &"over_bulkhead_hold_to_hold")
		assert_gt(spilled, 0.0, "× %s: water passes over it" % scale)
		# The step that spilled left one side's water over the top, higher than the
		# other's: a weir, not a doorway.
		var frame := timeline.frame_at(spilled)
		var hold := _head(timeline, frame, &"hold")
		var engine := _head(timeline, frame, &"engine_room")
		assert_gt(
			maxf(hold, engine),
			_bottom(timeline, frame, gap),
			"× %s: water over its top as it spills" % scale
		)
		assert_ne(hold, engine, "× %s: higher on one side" % scale)


func test_water_runs_down_a_stairwell() -> void:
	for scale: float in MARGINS:
		var timeline := _bake(_damage(load(FAST)), scale)
		var ran := _first(timeline, SinkTimeline.Kind.SPILLING, &"stair_engine_room_deckhouse_hall")
		var down := _first(timeline, SinkTimeline.Kind.SPILLING, &"stair_aft_cabins_sky")
		assert_gt(down, 0.0, "× %s: the sea runs down the after companionway" % scale)
		var frame := timeline.frame_at(down)
		var stair := _bottom(timeline, frame, _opening(&"stair_aft_cabins_sky"))
		assert_gt(timeline.seas[frame], stair, "× %s: once the sea is over the deck" % scale)
		assert_lt(
			_head(timeline, frame - 1, &"aft_cabins"),
			_bottom(timeline, frame - 1, _opening(&"stair_aft_cabins_sky")),
			"× %s: into the cabins under it" % scale
		)
		assert_gt(ran, 0.0, "× %s: and through the inner stair" % scale)
