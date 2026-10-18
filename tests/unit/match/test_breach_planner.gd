extends GutTest
## The breach as seen from inside her (GashPlanner, through FxPlanner): the sea jets in
## through a gash wherever it opens a place people can be (ShipLayout.opened_place), from
## its part over the floor, while the sea outside stands well over the room's water, and
## boils up over it under that; the rent it tore shows from the strike on; and water
## wells up through a floor from the void under it. Presentation only (D5, D12).

const RunMatch := preload("res://tools/run_match.gd")

const JET := FxCue.Kind.JET
const BOIL := FxCue.Kind.BOIL
const RENT := FxCue.Kind.RENT
const WELL := FxCue.Kind.WELL
## A whole sinking is scanned this many ticks a step.
const SCAN_STRIDE := 10
## A floor is watched this many seconds from the strike: long enough for the room over
## it to fill deep.
const BREACH_SCAN := 240.0


func test_the_sea_jets_in_through_a_gash_into_a_room_people_walk_in() -> void:
	var sim := _holed_by(&"trawler", _deep_bite())
	var structure := sim.config.ship.structure
	var gash := _gash_into(sim, &"engine_room")
	var room := structure.cells[structure.cell_named(&"engine_room")]
	var planner := _planner(sim)
	var struck := sim.schedule.hit_tick()
	var before := _sink(planner, sim, struck - Ticks.RATE, struck)
	assert_eq(_of(before, JET).size(), 0, "nothing gets in before she is struck")
	var cues := _strike(planner, sim)
	var jets := _of(cues, JET)
	assert_gt(jets.size(), 0, "the sea jets in as she is holed")
	assert_eq(_of(cues, BOIL).size(), 0, "into a dry room: no boil yet")
	for jet: FxCue in jets:
		for end: Vector3 in [jet.position, jet.end]:
			var half := gash.size.x * 0.5 + 0.01
			assert_between(end.x, gash.centre.x - half, gash.centre.x + half, "along the gash")
			assert_lt(end.z, gash.centre.z, "inboard of the room's side")
			assert_gt(end.z, room.low.z, "and inside the room")
			assert_between(end.y, room.low.y, room.high.y, "at the gash's height in it")
		assert_lt(jet.toward.z, -0.8, "thrown in across the room, from her starboard side")
		assert_gt(jet.strength, 0.5, "hard: the sea stands far over the dry room's floor")
		assert_gte(jet.rise, 1.5 - 0.001, "thrown a metre and a half into the room at least")
		var over := jet.position.y - room.low.y + 0.001
		assert_between(jet.drop, 0.0, over, "falling to her floor, no lower")
	var void_gash := _gash_into(sim, &"engine_wing_s")
	for jet: FxCue in jets:
		assert_true(jet.position.z < void_gash.centre.z, "none into the wing void, nobody's room")


func test_the_jet_dies_into_a_boil_over_the_gash_as_the_room_fills_and_stops_level() -> void:
	# The room fills over the gash's slit in some 20 s; she goes down by 3 min.
	var sim := _holed_by(&"trawler", _deep_bite())
	var structure := sim.config.ship.structure
	var room := structure.cell_named(&"engine_room")
	var gash := _gash_into(sim, &"engine_room")
	var struck := sim.schedule.hit_tick()
	var gone := sim.schedule.gone_tick()
	var to := gone + Ticks.from_seconds(10.0)
	var cues := _sink(_planner(sim), sim, struck, to, SCAN_STRIDE)
	var inrush := _of(cues, JET) + _of(cues, BOIL)
	assert_gt(_of(cues, JET).size(), 2, "it jets in")
	assert_gt(_of(cues, BOIL).size(), 2, "and boils once the room's water takes its head")
	var bottom := gash.centre - Vector3(0.0, gash.size.y * 0.5, 0.0)
	var top := gash.centre + Vector3(0.0, gash.size.y * 0.5, 0.0)
	var heads := PackedFloat64Array()
	var boiled := false
	var sea := SeaPhysics.load_default()
	var atmosphere := sea.air_pressure / (sea.sea_density * sea.gravity)
	for cue: FxCue in inrush:
		var pose := sim.schedule.pose_at(cue.tick)
		var level := pose.levels[room]
		assert_lt(cue.tick, gone, "none once she has gone")
		assert_lt(cue.position.z, gash.centre.z, "inboard of the gash")
		# Under the squeeze of any air trapped over the room's water.
		var pushing := level
		if pose.pockets[room] > 0.0:
			pushing += maxf(pose.pockets[room] - atmosphere, 0.0)
		var head := -maxf(pushing, pose.world_height(bottom))
		heads.append(head)
		# The head it came in with, into the dry room: the sea over the gash's foot.
		var dry := -pose.world_height(bottom)
		if cue.kind == JET:
			assert_gt(head, GashPlanner.JET_SHARE * dry - 0.001, "a jet while the head stays high")
			assert_false(boiled, "and never again once it boils")
		else:
			boiled = true
			assert_lte(head, GashPlanner.JET_SHARE * dry + 0.001, "a boil once it falls under")
			assert_gt(level, pose.world_height(bottom), "over the gash")
			assert_almost_eq(pose.world_height(cue.position), level, 0.01, "on the room's water")
			assert_almost_eq(pose.world_height(cue.end), level, 0.01)
	# How hard it comes in goes as the head of sea over the room's water does: weaker as
	# the room fills, harder as she settles and takes the gash deeper.
	var stronger := 0
	for one in inrush.size():
		for other in inrush.size():
			if heads[one] < heads[other] - 0.05 and inrush[one].strength > inrush[other].strength:
				stronger += 1
	assert_eq(stronger, 0, "never harder for less head")
	var weakest := 1.0
	for cue: FxCue in inrush:
		weakest = minf(weakest, cue.strength)
	assert_lt(weakest, 0.3, "dying away as her room fills level with the sea")
	# The same snapshots and poses show the same breach to a fresh planner.
	var again := _sink(_planner(sim), sim, struck, to, SCAN_STRIDE)
	assert_eq(_described(_of(again, JET) + _of(again, BOIL)), _described(inrush))


func test_the_sea_comes_in_by_its_head_over_the_room_s_water_and_stops_level() -> void:
	# The deep bite into the trawler's engine room, the room's water held where the test
	# puts it: dry under the gash, the sea jets in; just over the gash's top, it still jets
	# in, off the room's water, while the sea stands over that by more than JET_SHARE of the
	# head into the dry room; under that share, it boils up; level with the sea, or within
	# the least head of it, nothing comes in.
	var sim := _holed_by(&"trawler", _deep_bite())
	var layout := sim.config.ship
	var structure := layout.structure
	var gash := _gash_into(sim, &"engine_room")
	var top := gash.centre.y + gash.size.y * 0.5
	var bottom := gash.centre.y - gash.size.y * 0.5
	var sea := -layout.freeboard
	var share := sea - GashPlanner.JET_SHARE * (sea - bottom)
	var struck := sim.schedule.hit_tick()
	var room := structure.cells[structure.cell_named(&"engine_room")]
	var held := {
		room.low.y: [JET],
		top + 0.05: [JET],
		share + 0.1: [BOIL],
		sea - GashPlanner.LEAST_HEAD * 0.5: [],
		sea: [],
	}
	for water: float in held:
		var pose := HeldPose.flooded(layout, sea, {&"engine_room": [water]})
		var cues: Array[FxCue] = []
		GashPlanner.new(sim.schedule, layout).breach(struck, struck + 1, pose, cues)
		var kinds: Array = []
		for cue: FxCue in cues:
			if cue.kind != RENT:
				kinds.append(cue.kind)
				if water > top:
					assert_almost_eq(cue.position.y, water, 0.01, "off the room's water")
		assert_eq(kinds, held[water], "the room's water held at %.2f m" % water)


func test_a_stretch_under_a_room_s_floor_throws_no_jet() -> void:
	# The deep bite into the trawler's engine room, her floor raised over the gash in a
	# copy of her: under the floor plates nobody is there to see the sea come in.
	var sim := _holed_by(&"trawler", _deep_bite())
	var gash := _gash_into(sim, &"engine_room")
	var raised: ShipLayout = sim.config.ship.duplicate(true)
	var floor := _room_named(raised, &"engine room")
	floor.floor_height = gash.centre.y + gash.size.y
	var struck := sim.schedule.hit_tick()
	var pose := HeldPose.flooded(raised, -raised.freeboard, {})
	var cues: Array[FxCue] = []
	GashPlanner.new(sim.schedule, raised).breach(struck, struck + 1, pose, cues)
	assert_eq(_of(cues, JET).size(), 0, "no jet under the floor")
	assert_eq(_of(cues, BOIL).size(), 0)
	for rent: FxCue in _of(cues, RENT):
		assert_gt(rent.toward.z, 0.0, "a rent on her hull only, none in the room")
	# Its floor across the gash: the sea jets in from the part of it over the floor.
	floor.floor_height = gash.centre.y
	cues.clear()
	GashPlanner.new(sim.schedule, raised).breach(struck, struck + 1, pose, cues)
	var jets := _of(cues, JET)
	assert_eq(jets.size(), 1, "the part over the floor jets in")
	assert_gte(jets[0].position.y, floor.floor_height - 0.001, "from over the floor")


func test_the_jet_is_planned_in_front_of_a_wing_passage_s_shell() -> void:
	# The deep bite through the trawler's starboard wing void, made a passage in a copy of
	# her: a room people walk in along her shell, with no lining before it.
	var sim := _holed_by(&"trawler", _deep_bite())
	var passage: ShipLayout = sim.config.ship.duplicate(true)
	var structure := passage.structure
	var wing := structure.cells[structure.cell_named(&"engine_wing_s")]
	var room := ShipRoom.new()
	room.name = &"wing passage"
	room.area = Rect2(wing.low.x, wing.low.z, wing.high.x - wing.low.x, wing.high.z - wing.low.z)
	room.floor_height = wing.low.y
	passage.rooms.append(room)
	wing.rooms.append(room.name)
	var gash := _gash_into(sim, &"engine_wing_s")
	var struck := sim.schedule.hit_tick()
	var pose := HeldPose.flooded(passage, -passage.freeboard, {})
	var cues: Array[FxCue] = []
	GashPlanner.new(sim.schedule, passage).breach(struck, struck + 1, pose, cues)
	var into := _of(cues, JET).filter(
		func(jet: FxCue) -> bool:
			return jet.position.z > wing.low.z and jet.position.z < wing.high.z
	)
	assert_eq(into.size(), 1, "the sea jets into the passage")
	# Off her shell as a pour hangs, or half way across a passage narrower than that.
	var off := minf(InnerWater.OFF_SHELL, (gash.centre.z - wing.low.z) * 0.5)
	var shell := gash.centre.z - off
	assert_almost_eq(into[0].position.z, shell, 0.01, "just in front of her shell")
	assert_almost_eq(into[0].end.z, shell, 0.01)
	assert_lt(into[0].toward.z, -0.8, "thrown across the passage")


func test_a_gash_that_opens_only_a_void_throws_nothing_inside() -> void:
	var sim := _holed_by(&"trawler", _bilge_bite())
	for opening: ShipOpening in sim.schedule.damage().openings:
		assert_does_not_have([&"engine_room", &"fish_hold"], opening.joins[0], "voids only")
	var struck := sim.schedule.hit_tick()
	var cues := _sink(_planner(sim), sim, struck, struck + Ticks.from_seconds(60.0), SCAN_STRIDE)
	for kind: FxCue.Kind in [JET, BOIL, RENT]:
		assert_eq(_of(cues, kind).size(), 0, "nobody's room is breached")


func test_a_gash_over_the_sea_throws_nothing_but_shows_its_rent_inside_and_out() -> void:
	# The steamer struck 1.5 m over her waterline, into her engine room.
	var sim := _holed_by(&"steamer", SimFixtures.explicit_hit(1, -2.0, 3.0, -1.5, 0.1, 0.5))
	var gash := _gash_into(sim, &"engine_room")
	var struck := sim.schedule.hit_tick()
	var planner := _planner(sim)
	var cues := _strike(planner, sim)
	cues.append_array(_sink(planner, sim, struck + 1, struck + Ticks.from_seconds(10.0)))
	assert_eq(_of(cues, JET).size(), 0, "no sea to jet in")
	assert_eq(_of(cues, BOIL).size(), 0)
	var rents := _of(cues, RENT)
	assert_eq(rents.size(), 2, "torn inside and out, once")
	var inside := rents[0] if rents[0].toward.z < 0.0 else rents[1]
	var outside := rents[1] if inside == rents[0] else rents[0]
	assert_lt(inside.toward.z, -0.9, "facing into the room")
	assert_lt(inside.position.z, gash.centre.z, "on its lining")
	assert_gt(outside.toward.z, 0.9, "facing the sea")
	assert_gte(outside.position.z, gash.centre.z, "on her hull")
	for rent: FxCue in rents:
		assert_eq(rent.tick, struck, "from the strike")
		assert_almost_eq(rent.position.x, gash.centre.x - gash.size.x * 0.5, 0.01, "all along it")
		assert_almost_eq(rent.end.x, gash.centre.x + gash.size.x * 0.5, 0.01)
		assert_almost_eq(rent.position.y, gash.centre.y, 0.01, "at its height")
		assert_gte(rent.radius, gash.size.y * 0.5 - 0.001, "as tall as it is")


func test_the_rent_inside_is_told_once_from_the_strike_on() -> void:
	var sim := _holed_by(&"trawler", _deep_bite())
	var gash := _gash_into(sim, &"engine_room")
	var struck := sim.schedule.hit_tick()
	var planner := _planner(sim)
	assert_eq(_of(_sink(planner, sim, struck - Ticks.RATE, struck), RENT).size(), 0)
	var rents := _of(_sink(planner, sim, struck, struck + Ticks.from_seconds(10.0)), RENT)
	assert_eq(rents.size(), 1, "inside the room only: all of the gash is under the sea")
	assert_lt(rents[0].toward.z, -0.9, "facing into the room")
	assert_lt(gash.size.y, 0.4, "a thin slit of a gash")
	assert_gte(rents[0].radius * 2.0, 0.4 - 0.001, "torn at least 0.4 m tall, to be found")
	# A room runs to the middle of its walls: its wing wall's face stands half a wall in.
	var face := _room_named(sim.config.ship, &"engine room").area.end.y - 0.1
	assert_between(rents[0].position.z, face - 0.05, face, "on the wall that lines the room")
	assert_almost_eq(rents[0].position.x, gash.centre.x - gash.size.x * 0.5, 0.01)
	assert_almost_eq(rents[0].end.x, gash.centre.x + gash.size.x * 0.5, 0.01)
	# A planner first asked after the strike — a match joined late — tells it all the same.
	var late := _of(_sink(_planner(sim), sim, struck + Ticks.RATE, struck + Ticks.RATE * 2), RENT)
	assert_eq(late.size(), 1)
	assert_eq(late[0].position, rents[0].position, "the same rent")
	assert_eq(late[0].end, rents[0].end)


func test_water_wells_up_through_the_floor_from_the_void_under_it_until_the_room_is_deep() -> void:
	# The bite floods the trawler's bilge under her engine room, which fills through its
	# floor plates.
	var sim := _holed_by(&"trawler", _bilge_bite())
	var structure := sim.config.ship.structure
	var room := structure.cell_named(&"engine_room")
	var bilge := structure.cell_named(&"engine_bilge")
	var box := structure.cells[room]
	var struck := sim.schedule.hit_tick()
	var to := struck + Ticks.from_seconds(BREACH_SCAN)
	var wells := _of(_sink(_planner(sim), sim, struck, to, SCAN_STRIDE), WELL)
	assert_gt(wells.size(), 3, "it wells up through the floor")
	var places := {}
	for well: FxCue in wells:
		var pose := sim.schedule.pose_at(well.tick)
		var floor := pose.world_height(Vector3(well.position.x, box.low.y, well.position.z))
		assert_gt(pose.levels[bilge], floor, "while the bilge's water stands over the floor")
		var depth := pose.levels[room] - floor
		assert_lt(depth, FxPlanner.WELL_DEEP, "and the room's is shallow")
		assert_between(well.position.x, box.low.x, box.high.x, "over the room's floor")
		assert_between(well.position.z, box.low.z, box.high.z)
		var shows := maxf(pose.levels[room], floor)
		assert_almost_eq(pose.world_height(well.position), shows, 0.01, "on its floor or water")
		assert_between(well.strength, 0.0, 1.0)
		places[Vector2(well.position.x, well.position.z).snappedf(0.5)] = true
	assert_gt(places.size(), 1, "spread over the floor")
	assert_lt(wells[-1].strength, wells[0].strength, "fading as the room deepens")
	var last := sim.schedule.pose_at(wells[-1].tick + SCAN_STRIDE * 2)
	var middle := (box.low + box.high) * 0.5
	var floor_now := last.world_height(Vector3(middle.x, box.low.y, middle.z))
	assert_gt(last.levels[room] - floor_now, FxPlanner.WELL_DEEP * 0.5, "it stops once deep")
	assert_lt(wells[-1].tick, to - Ticks.from_seconds(10.0), "and stays stopped")


## The default match on [param ship_name] struck by explicit [param hit] 20 s in.
func _holed_by(ship_name: StringName, hit: IcebergHit) -> MatchSim:
	var config := RunMatch.default_config(1701, 0, ship_name)
	var given: SinkScenario = config.scenario.duplicate()
	hit.moment = 20.0
	given.explicit_hit = hit
	config.scenario = given
	return MatchSim.create(config)


## A deep bite into the trawler's starboard side by her engine room, 0.8 m under her
## waterline: through her wing void into the room, the whole gash under the sea.
func _deep_bite() -> IcebergHit:
	return SimFixtures.explicit_hit(1, -12.0, -6.0, 0.8, 0.05, 1.5)


## A bite into the trawler's starboard side by her engine room, low: into her wing void
## and her bilge under the room, never the room.
func _bilge_bite() -> IcebergHit:
	return SimFixtures.explicit_hit(1, -12.0, -6.0, 2.4, 0.05, 1.0)


## [param layout]'s room called [param room_name].
func _room_named(layout: ShipLayout, room_name: StringName) -> ShipRoom:
	for room: ShipRoom in layout.rooms:
		if room.name == room_name:
			return room
	assert_true(false, "the layout has %s" % room_name)
	return null


func _planner(sim: MatchSim) -> FxPlanner:
	return FxPlanner.new(sim.config, sim.surfaces, sim.schedule)


func _sink(planner: FxPlanner, sim: MatchSim, from: int, to: int, stride: int = 1) -> Array[FxCue]:
	return FxProbe.sink(planner, sim, from, to, stride)


func _strike(planner: FxPlanner, sim: MatchSim) -> Array[FxCue]:
	return FxProbe.strike(planner, sim)


func _of(cues: Array[FxCue], kind: FxCue.Kind) -> Array[FxCue]:
	return FxProbe.of(cues, kind)


func _described(cues: Array) -> PackedStringArray:
	return FxProbe.described(cues)


func _gash_into(sim: MatchSim, cell_name: StringName) -> ShipOpening:
	for opening: ShipOpening in sim.schedule.damage().openings:
		if opening.joins[0] == cell_name:
			return opening
	assert_true(false, "the gash opens %s" % cell_name)
	return null
