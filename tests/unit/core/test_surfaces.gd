extends GutTest
## Surfaces as the steamer's spatial authority: heights, steps, falls, landings and
## the wet test, all asked of Surfaces and stepped through MatchSim.


func _steamer() -> ShipLayout:
	return SimFixtures.steamer()


func _platform(platform_name: StringName) -> int:
	return SimFixtures.platform_named(_steamer(), platform_name)


## The steamer's ramp whose start end joins [param start] and end end joins
## [param end], as a surface number.
func _ramp_between(surfaces: Surfaces, start: int, end: int) -> int:
	for ramp in _steamer().ramps.size():
		var surface := surfaces.ramp_surface(ramp)
		var joined := surfaces.joins(surface)
		if joined[0] == start and joined[1] == end:
			return surface
	return Surfaces.NONE


## A steamer match held level and unsunk, seat 1 parked out of the way on the poop.
func _steamer_sim() -> MatchSim:
	var sim := SimFixtures.sim(2, null, _steamer())
	SimFixtures.place(sim, 1, Vector3(-18.0, 1.2, 0.0))
	return sim


func _kinds(events: Array[SimEvent], kind: SimEvent.Kind) -> Array[SimEvent]:
	return events.filter(func(event: SimEvent) -> bool: return event.kind == kind)


## Seat 0 starts standing at [param from] and walks [param direction] until it
## lands somewhere; returns the events of the walk.
func _walk_off(sim: MatchSim, from: Vector3, direction: Vector2) -> Array[SimEvent]:
	SimFixtures.place(sim, 0, from)
	var events: Array[SimEvent] = []
	for _tick in 3 * Ticks.RATE:
		var stepped := SimFixtures.step(sim, {0: SimFixtures.frame(0, direction)})
		events.append_array(stepped)
		if not _kinds(stepped, SimEvent.Kind.LANDED).is_empty() or sim.state.seats[0].is_out():
			break
	return events


func test_ramp_height_interpolates() -> void:
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	assert_gt(layout.ramps.size(), 0)
	for ramp_index in layout.ramps.size():
		var ramp := layout.ramps[ramp_index]
		var surface := surfaces.ramp_surface(ramp_index)
		var start := ramp.end_point(0)
		var end := ramp.end_point(1)
		for weight: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var point := start.lerp(end, weight)
			var expected := lerpf(ramp.start_height, ramp.end_height, weight)
			assert_almost_eq(
				surfaces.height_at(surface, point),
				expected,
				0.0001,
				"ramp %d at %s" % [ramp_index, weight]
			)
		# Halfway up, standing on it, the ramp is what is underfoot.
		var middle := start.lerp(end, 0.5)
		middle.y = surfaces.height_at(surface, middle)
		assert_eq(surfaces.under(middle, SimFixtures.rules().step_height), surface)


func test_step_height_picks_upper_or_lower() -> void:
	var surfaces := Surfaces.new(_steamer())
	var step := SimFixtures.rules().step_height
	var main_deck := _platform(&"main deck")
	var boat_deck := _platform(&"boat deck")
	# A ramp from the main deck up to the boat deck stands on the main deck.
	var ramp := _ramp_between(surfaces, boat_deck, main_deck)
	assert_ne(ramp, Surfaces.NONE)
	var layout_ramp := _steamer().ramps[ramp - surfaces.platform_count()]
	var foot := layout_ramp.end_point(1)
	var head := layout_ramp.end_point(0)
	var rise := head.y - foot.y
	var low := foot.lerp(head, step * 0.5 / rise)
	var high := foot.lerp(head, step * 2.0 / rise)
	low.y = 0.0
	high.y = 0.0
	assert_eq(surfaces.under(low, step), ramp, "the ramp within a step above: up onto it")
	assert_eq(surfaces.under(high, step), main_deck, "the ramp out of a step's reach: stay low")
	high.y = surfaces.height_at(ramp, high)
	assert_eq(surfaces.under(high, step), ramp, "standing on the ramp: the ramp")
	# Where the boat deck stands over the main deck, the feet decide which.
	var over := Vector3(-5.0, 0.0, -2.5)
	assert_eq(surfaces.under(over, step), main_deck)
	over.y = surfaces.height_at(boat_deck, over)
	assert_eq(surfaces.under(over, step), boat_deck)
	over.y -= step * 2.0
	assert_eq(surfaces.under(over, step), Surfaces.NONE, "between the two: falling")
	over.y -= step * 0.5
	assert_eq(surfaces.landing(over), main_deck, "and it lands on the main deck")


func test_walking_off_the_boat_deck_lands_on_the_main_deck() -> void:
	var sim := _steamer_sim()
	var main_deck := _platform(&"main deck")
	var boat_deck := _platform(&"boat deck")
	# Off its open after edge, abaft the funnel.
	var edge := _steamer().platforms[boat_deck].area.position.x
	var events := _walk_off(sim, Vector3(edge + 0.6, 2.5, -2.0), Vector2.LEFT)
	var fell := _kinds(events, SimEvent.Kind.FELL)
	var landed := _kinds(events, SimEvent.Kind.LANDED)
	assert_eq(fell.size(), 1, "it fell once")
	assert_eq(landed.size(), 1, "and landed once")
	if fell.is_empty() or landed.is_empty():
		return
	assert_eq(fell[0].seat, 0)
	assert_gt(landed[0].tick, fell[0].tick)
	assert_eq(landed[0].surface, main_deck)
	var walker := sim.state.seats[0]
	assert_eq(walker.body, PlayerState.Body.GROUNDED)
	assert_eq(walker.surface, main_deck)
	assert_eq(walker.pos.y, 0.0, "on the main deck's planks")
	assert_lt(walker.pos.x, edge, "abaft the deckhouse, not inside it")
	assert_gt(walker.stagger_ticks, 0, "staggered by the drop")
	assert_false(walker.is_out())


func test_landing_stagger_scales_with_the_drop() -> void:
	var per_m := SimFixtures.rules().fall_stagger_per_m
	var layout := _steamer()
	var bridge := layout.platforms[_platform(&"bridge")]
	var boat_deck := layout.platforms[_platform(&"boat deck")]
	var poop_deck := layout.platforms[_platform(&"poop deck")]
	# Off the poop deck's open forward edge onto the main deck, off the bridge's
	# forward edge beside its ramp onto the boat deck, off the boat deck's after edge
	# onto the main deck.
	var falls := [
		[
			Vector3(poop_deck.area.end.x - 0.6, poop_deck.height, 1.2),
			Vector2.RIGHT,
			poop_deck.height
		],
		[
			Vector3(bridge.area.end.x - 0.6, bridge.height, bridge.area.end.y - 0.35),
			Vector2.RIGHT,
			bridge.height - boat_deck.height
		],
		[
			Vector3(boat_deck.area.position.x + 0.6, boat_deck.height, 2.0),
			Vector2.LEFT,
			boat_deck.height
		],
	]
	var staggers: Array[int] = []
	for fall: Array in falls:
		var sim := _steamer_sim()
		var landed := _kinds(_walk_off(sim, fall[0], fall[1]), SimEvent.Kind.LANDED)
		assert_eq(landed.size(), 1, "a fall of %s m lands" % fall[2])
		if landed.is_empty():
			return
		var expected := Ticks.from_seconds(float(fall[2]) * per_m)
		assert_eq(landed[0].stagger_ticks, expected, "a drop of %s m" % fall[2])
		assert_eq(sim.state.seats[0].stagger_ticks, expected)
		staggers.append(expected)
	assert_lt(staggers[0], staggers[1], "a deeper drop staggers longer")
	assert_lt(staggers[1], staggers[2])
	assert_eq(staggers[2], Ticks.from_seconds(0.2), "off the boat deck costs 0.2 s (§6)")


func test_a_fall_past_every_surface_reaches_the_sea() -> void:
	var layout := _steamer()
	var sim := _steamer_sim()
	var surfaces := sim.surfaces
	var highest := -INF
	var lowest := INF
	for platform: ShipPlatform in layout.platforms:
		highest = maxf(highest, platform.height)
		lowest = minf(lowest, platform.height)
	# Abeam of the bridge, just outboard of the main deck's railing, above every deck.
	var outboard := -INF
	for platform: ShipPlatform in layout.platforms:
		outboard = maxf(outboard, platform.area.end.y)
	var start := Vector3(-2.5, highest + 1.0, outboard + 0.5)
	assert_eq(surfaces.landing(start), Surfaces.NONE, "nothing under it at any height")
	SimFixtures.place(sim, 0, start)
	var faller := sim.state.seats[0]
	faller.body = PlayerState.Body.AIRBORNE
	faller.surface = Surfaces.NONE
	faller.fall_from = start.y
	var events: Array[SimEvent] = []
	var passed_every_deck := false
	for _tick in 8 * Ticks.RATE:
		events.append_array(SimFixtures.step(sim))
		passed_every_deck = passed_every_deck or faller.pos.y < lowest
		if faller.is_out():
			break
	assert_true(passed_every_deck, "it fell past the lowest deck")
	assert_eq(_kinds(events, SimEvent.Kind.ENTERED_WATER).size(), 1, "into the sea")
	assert_true(faller.is_out(), "where the cold took it")
	assert_eq(faller.out_cause, PlayerState.Cause.COLD)
	assert_true(_kinds(events, SimEvent.Kind.LANDED).is_empty(), "it never landed")


func test_stern_down_scenario_floods_the_poop_deck_first() -> void:
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var poop_deck := _platform(&"poop deck")
	var forecastle := _platform(&"forecastle")
	var bow_down: SinkScenario = load(SimFixtures.STEAMER_SINKING)
	# The shipped scenario with its trim and heel signs flipped: by the stern, the
	# other way over.
	var rows := []
	for keyframe: SinkKeyframe in bow_down.keyframes:
		rows.append([keyframe.at, keyframe.sink, -keyframe.trim_deg, -keyframe.heel_deg])
	var stern_down := SimFixtures.scenario(rows, bow_down.starts_at)
	# Per scenario: the first platform under, and when each end deck goes under. The
	# lower deck floods first either way (rev 3); which end deck follows is the sign.
	var firsts := []
	var ends := []
	for scenario: SinkScenario in [stern_down, bow_down]:
		var schedule := SinkSchedule.new(scenario, layout.freeboard, SeedStreams.derive(1, "sink"))
		var first := Surfaces.NONE
		var under := {poop_deck: -1, forecastle: -1}
		for tick in 240 * Ticks.RATE:
			var pose := schedule.pose_at(tick)
			for platform in layout.platforms.size():
				if first == Surfaces.NONE and surfaces.flooded(platform, pose):
					first = platform
			for platform: int in under:
				if under[platform] == -1 and surfaces.flooded(platform, pose):
					under[platform] = tick
		firsts.append(first)
		ends.append(under)
	for index in 2:
		assert_ne(firsts[index], Surfaces.NONE)
		if firsts[index] != Surfaces.NONE:
			assert_lt(layout.platforms[firsts[index]].height, 0.0, "the lower deck goes first")
	assert_lt(ends[0][poop_deck], ends[0][forecastle], "stern down: the poop deck before the bow")
	assert_lt(ends[1][forecastle], ends[1][poop_deck], "bow down: the forecastle before the stern")
	var stern_first := layout.platforms[firsts[0]].area.get_center().x
	var bow_first := layout.platforms[firsts[1]].area.get_center().x
	assert_lt(stern_first, bow_first, "and the lower deck floods from the end that goes down")


## A deck 20 × 12 m with walls 0.2 m thick standing on it: one along x = 0 with a
## doorway 1.1 m wide across z = 0, one along z = 3 from it to x = -6 making a
## corner, and one along z = -3 with a slot 0.6 m wide — narrower than a body.
func _walled_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.freeboard = 3.0
	var deck := ShipPlatform.new()
	deck.area = Rect2(-10.0, -6.0, 20.0, 12.0)
	layout.platforms = [deck]
	var blockers: Array[ShipBlocker] = []
	for area: Rect2 in [
		Rect2(-0.1, -6.0, 0.2, 5.45),
		Rect2(-0.1, 0.55, 0.2, 5.45),
		Rect2(-6.0, 2.9, 6.1, 0.2),
		Rect2(-6.0, -3.1, 2.7, 0.2),
		Rect2(-2.7, -3.1, 2.6, 0.2),
	]:
		var wall := ShipBlocker.new()
		wall.area = area
		wall.top = 2.5
		blockers.append(wall)
	layout.blockers = blockers
	layout.spawns = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	return layout


func _walled_sim(seats: int) -> MatchSim:
	return SimFixtures.sim(seats, null, _walled_layout())


## How far [param player]'s circle reaches into the deepest wall of [param layout].
func _into_walls(layout: ShipLayout, player: PlayerState) -> float:
	var deepest := 0.0
	var point := Vector2(player.pos.x, player.pos.z)
	for wall: ShipBlocker in layout.blockers:
		var gap := point.distance_to(point.clamp(wall.area.position, wall.area.end))
		deepest = maxf(deepest, SimFixtures.rules().body_radius - gap)
	return deepest


func test_stacked_floors_pick_the_one_underfoot() -> void:
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var step := SimFixtures.rules().step_height
	# Abaft the funnel, to port: a lower-deck cabin, the main deck over it (a deckhouse
	# cabin's floor) and the boat deck over that, one above another.
	var x := -5.0
	var z := -2.5
	var floors := {-2.6: &"lower deck", 0.0: &"main deck", 2.5: &"boat deck"}
	for height: float in floors:
		var surface := surfaces.under(Vector3(x, height, z), step)
		assert_eq(SimFixtures.name_of(layout, surface), floors[height], "feet at %s" % height)
	assert_eq(surfaces.under(Vector3(x, -1.3, z), step), Surfaces.NONE, "between: falling")
	assert_eq(SimFixtures.name_of(layout, surfaces.landing(Vector3(x, -1.3, z))), &"lower deck")
	assert_eq(SimFixtures.name_of(layout, surfaces.landing(Vector3(x, 1.0, z))), &"main deck")

	# Three bodies standing one over another stay each on its own floor.
	var sim := SimFixtures.sim(3, null, layout)
	var heights: Array[float] = [-2.6, 0.0, 2.5]
	for seat in 3:
		SimFixtures.place(sim, seat, Vector3(x, heights[seat], z))
	var events := SimFixtures.step(sim, {}, Ticks.RATE)
	assert_true(events.is_empty(), "nothing happened")
	for seat in 3:
		var body := sim.state.seats[seat]
		assert_eq(body.body, PlayerState.Body.GROUNDED)
		assert_eq(body.pos, Vector3(x, heights[seat], z), "seat %d where it stood" % seat)
		assert_eq(SimFixtures.name_of(layout, body.surface), floors[heights[seat]])


func test_walls_stop_bodies_and_shoves() -> void:
	var rules := SimFixtures.rules()
	var layout := _walled_layout()
	var face := -0.1 - rules.body_radius
	# Slammed square into the wall by a quick shove: it stops at the wall's face — a
	# wall is never vaulted.
	var slam := _walled_sim(2)
	SimFixtures.place(slam, 1, Vector3(-2.0, 0.0, 1.8))
	SimFixtures.place(slam, 0, Vector3(-2.0 - rules.body_radius * 2.0 - 0.3, 0.0, 1.8), 0.0)
	var events: Array[SimEvent] = []
	for tick in 2 * Ticks.RATE:
		var buttons := InputFrame.SHOVE if tick == 0 else 0
		events.append_array(
			SimFixtures.step(slam, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)})
		)
	var target := slam.state.seats[1]
	assert_true(_kinds(events, SimEvent.Kind.VAULTED).is_empty(), "no vault")
	assert_eq(target.body, PlayerState.Body.GROUNDED)
	assert_almost_eq(target.pos.x, face, 0.0001, "stopped at the wall's face")
	assert_almost_eq(target.pos.z, 1.8, 0.0001, "on the line it came in on")

	# A shove through the wall never lands; the same shove through the doorway does.
	var lanes := {"through the wall": 1.8, "through the doorway": 0.0}
	var hit := {}
	for lane: String in lanes:
		var sim := _walled_sim(2)
		SimFixtures.place(sim, 0, Vector3(-0.6, 0.0, lanes[lane]), 0.0)
		SimFixtures.place(sim, 1, Vector3(0.6, 0.0, lanes[lane]), 180.0)
		SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.SHOVE)})
		SimFixtures.step(sim, {0: SimFixtures.frame(0)}, 9)
		hit[lane] = sim.state.seats[1].is_staggered()
	assert_false(hit["through the wall"], "the wall takes the shove")
	assert_true(hit["through the doorway"], "the doorway does not")

	# Walked into a corner with a second body pressing behind: it comes to rest in
	# the corner, against both walls and in neither, and so does its follower.
	var corner := _walled_sim(2)
	SimFixtures.place(corner, 0, Vector3(-2.0, 0.0, 1.5))
	SimFixtures.place(corner, 1, Vector3(-2.8, 0.0, 0.9))
	var into_corner := Vector2(1.0, 1.0)
	var deepest := 0.0
	for _tick in 3 * Ticks.RATE:
		SimFixtures.step(
			corner, {0: SimFixtures.frame(0, into_corner), 1: SimFixtures.frame(1, into_corner)}
		)
		for player: PlayerState in corner.state.seats:
			deepest = maxf(deepest, _into_walls(layout, player))
	var cornered := corner.state.seats[0]
	assert_almost_eq(cornered.pos.x, face, 0.001, "against the wall along x")
	assert_almost_eq(cornered.pos.z, 2.9 - rules.body_radius, 0.001, "against the wall along z")
	assert_lt(deepest, 0.001, "no body was ever left inside a wall")

	# Shoved at a slot narrower than itself, it never goes through.
	var slot := _walled_sim(2)
	SimFixtures.place(slot, 1, Vector3(-3.0, 0.0, -1.6))
	SimFixtures.place(slot, 0, Vector3(-3.0, 0.0, -1.6 + rules.body_radius * 2.0 + 0.3), -90.0)
	var nearest := INF
	for tick in 2 * Ticks.RATE:
		var buttons := InputFrame.SHOVE if tick == 0 else 0
		SimFixtures.step(slot, {0: SimFixtures.frame(0, Vector2.UP * 0.6, buttons)})
		nearest = minf(nearest, slot.state.seats[1].pos.z)
	assert_lt(nearest, -2.5, "the shove sent it into the slot")
	assert_gt(nearest, -2.9, "it never got past the slot's near side")


## Two shovers landing on one staggered body send it at up to twice the restagger
## knockback, two-thirds of a metre a tick at 30 Hz: more than a wall's half-thickness
## and a body's radius together. Whatever its speed and however close it stood, it
## stops at the wall's face on its own side.
func test_a_stacked_shove_never_carries_a_body_through_a_wall() -> void:
	var rules := SimFixtures.rules()
	var face := -0.1 - rules.body_radius
	var fastest := rules.knockback * rules.restagger_mult * 2.0
	for gap: float in [0.0, 0.05, 0.1, 0.2, 0.3, 0.45]:
		for speed: float in [rules.knockback, fastest * 0.75, fastest]:
			var sim := _walled_sim(1)
			SimFixtures.place(sim, 0, Vector3(face - gap, 0.0, 1.8))
			var body := sim.state.seats[0]
			body.vel = Vector3(speed, 0.0, 0.0)
			body.stagger_ticks = Ticks.from_seconds(rules.stagger)
			SimFixtures.step(sim, {}, Ticks.RATE)
			var label := "%.2f m off the wall at %.1f m/s" % [gap, speed]
			assert_almost_eq(body.pos.x, face, 0.0001, label + ": stopped at the face")
			assert_eq(body.body, PlayerState.Body.GROUNDED, label)


## A body slammed up a steep stair faster than it can climb — more than a step's
## rise in one tick — is held on the stair where the rise runs out, never pushed out
## of the stair's side or head: at the aft companionway's head, that is through the
## hull.
func test_a_body_slammed_up_a_stair_is_held_on_it() -> void:
	var rules := SimFixtures.rules()
	var fastest := rules.knockback * rules.restagger_mult * 2.0
	for speed: float in [fastest * 0.6, fastest * 0.8, fastest]:
		var sim := _steamer_sim()
		SimFixtures.place(sim, 0, Vector3(-11.9, -0.77, 0.15))
		var body := sim.state.seats[0]
		assert_true(sim.surfaces.is_ramp(body.surface), "starts on the aft companionway")
		body.vel = Vector3(-speed, 0.0, 0.0)
		body.stagger_ticks = Ticks.from_seconds(rules.stagger)
		var lowest := body.pos.y
		var aftmost := body.pos.x
		for _tick in Ticks.RATE:
			SimFixtures.step(sim)
			lowest = minf(lowest, body.pos.y)
			aftmost = minf(aftmost, body.pos.x)
		var label := "at %.1f m/s" % speed
		assert_eq(body.body, PlayerState.Body.GROUNDED, label + ": still standing")
		assert_gte(lowest, -0.77, label + ": never fell off the stair")
		assert_gt(aftmost, -12.9, label + ": never into the hull's after wall")
		assert_true(
			sim.surfaces.is_ramp(body.surface) or body.pos.y == 0.0,
			label + ": on the stair or the deck at its head"
		)


func test_doorway_passes_one_body_at_a_time() -> void:
	var rules := SimFixtures.rules()
	var layout := _walled_layout()
	# Two bodies walk abreast at the doorway, one a little ahead: they go through one
	# after the other, and neither is ever pushed into a jamb.
	var sim := _walled_sim(2)
	SimFixtures.place(sim, 0, Vector3(-2.6, 0.0, 0.25))
	SimFixtures.place(sim, 1, Vector3(-3.2, 0.0, -0.25))
	var deepest := 0.0
	var both_in_it := 0
	for _tick in 4 * Ticks.RATE:
		var frames := {}
		var in_doorway := 0
		for player: PlayerState in sim.state.seats:
			var through := player.pos.x > 1.5
			frames[player.seat] = SimFixtures.frame(
				player.seat, Vector2.ZERO if through else Vector2.RIGHT
			)
			if absf(player.pos.x) < rules.body_radius:
				in_doorway += 1
		if in_doorway > 1:
			both_in_it += 1
		SimFixtures.step(sim, frames)
		for player: PlayerState in sim.state.seats:
			deepest = maxf(deepest, _into_walls(layout, player))
	assert_eq(both_in_it, 0, "one body in the doorway at a time")
	assert_lt(deepest, 0.001, "neither was pushed into a jamb")
	for player: PlayerState in sim.state.seats:
		assert_gt(player.pos.x, 1.0, "seat %d went through" % player.seat)
		assert_lte(absf(player.pos.z), 6.0)


func test_falling_into_a_companionway_lands_on_the_stair() -> void:
	var rules := SimFixtures.rules()
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	# The aft companionway: a stair rising aft out of the cabin corridor, under an
	# opening in the main deck railed on three sides. A body pinned against the rail
	# across the opening's forward end takes a quick shove aft, goes over the rail,
	# and comes down on the stair below — not on the lower deck, not past it.
	var stair := Surfaces.NONE
	for ramp in layout.ramps.size():
		if layout.ramps[ramp].area.has_point(Vector2(-11.5, 0.0)):
			stair = surfaces.ramp_surface(ramp)
	assert_ne(stair, Surfaces.NONE)
	var rail_x := -10.25
	var sim := SimFixtures.sim(3, null, layout)
	SimFixtures.place(sim, 2, Vector3(-18.0, 1.2, 0.0))
	SimFixtures.place(sim, 1, Vector3(rail_x + rules.body_radius, 0.0, 0.0), 0.0)
	SimFixtures.place(sim, 0, Vector3(rail_x + rules.body_radius * 3.0 + 0.3, 0.0, 0.0), 180.0)
	var events: Array[SimEvent] = []
	for tick in 2 * Ticks.RATE:
		var buttons := InputFrame.SHOVE if tick == 0 else 0
		events.append_array(SimFixtures.step(sim, {0: SimFixtures.frame(0, Vector2.ZERO, buttons)}))
		if not _kinds(events, SimEvent.Kind.LANDED).is_empty():
			break
	assert_eq(_kinds(events, SimEvent.Kind.VAULTED).size(), 1, "over the rail")
	var landed := _kinds(events, SimEvent.Kind.LANDED)
	assert_eq(landed.size(), 1, "and down")
	if landed.is_empty():
		return
	assert_eq(landed[0].seat, 1)
	assert_eq(landed[0].surface, stair, "on the stair")
	var faller := sim.state.seats[1]
	assert_eq(faller.body, PlayerState.Body.GROUNDED)
	assert_almost_eq(faller.pos.y, surfaces.height_at(stair, faller.pos), 0.0001)
	assert_lt(faller.pos.y, 0.0, "below the main deck")
	assert_false(faller.is_out())


func test_room_floods_exactly_when_its_floor_is_under_the_sea() -> void:
	# No compartments (D7): a body standing in a room starts swimming on the tick the
	# sea stands wade_depth over its feet — whatever walls and doorways stand round it.
	# Without the scenario's events: a lurch would slide the bodies off the points watched.
	var layout := _steamer()
	var sinking: SinkScenario = load(SimFixtures.STEAMER_SINKING).duplicate()
	sinking.events = []
	var sim := SimFixtures.sim(3, sinking, layout)
	var rooms := {0: Vector3(-2.0, -2.6, -3.5), 1: Vector3(-11.0, -2.6, 3.0)}
	for seat: int in rooms:
		SimFixtures.place(sim, seat, rooms[seat])
		assert_ne(layout.room_at(rooms[seat], 0.01), -1, "seat %d stands in a room" % seat)
	SimFixtures.place(sim, 2, Vector3(-18.0, 1.2, 0.0))
	var wade := sim.config.rules.wade_depth
	var expected := {}
	for tick in 150 * Ticks.RATE:
		var pose := sim.schedule.pose_at(tick)
		for seat: int in rooms:
			var feet: Vector3 = rooms[seat]
			if not expected.has(seat) and pose.sea_height(feet.x, feet.z) - feet.y >= wade:
				expected[seat] = tick
	assert_eq(expected.size(), 2, "both floors go under")
	var swam := {}
	while not sim.is_over() and sim.state.tick < 150 * Ticks.RATE:
		for event: SimEvent in _kinds(SimFixtures.step(sim), SimEvent.Kind.ENTERED_WATER):
			swam[event.seat] = event.tick
	for seat: int in rooms:
		assert_eq(
			swam.get(seat, -1),
			expected.get(seat, -1),
			"seat %d swam as its floor went under" % seat
		)
		assert_true(sim.state.seats[seat].is_out(), "seat %d out" % seat)
	assert_ne(expected[0], expected[1], "each room by its own floor's height, not the hull's")


func test_a_ladder_climbs_out_of_reach_and_only_where_it_hangs() -> void:
	# At the start the main deck stands 3.4 m out of the sea, past any edge's reach:
	# up the starboard boarding ladder, and nowhere else along that side.
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var sim := SimFixtures.sim(1, load(SimFixtures.STEAMER_SINKING), layout)
	var pose := sim.pose()
	var ladder: ShipLadder = layout.ladders[1]
	var middle := (ladder.from + ladder.to) * 0.5
	var outboard := ladder.from.y + rules.body_radius + 0.2
	var feet := Vector3(middle.x, pose.sea_height(middle.x, outboard) - rules.swim_depth, outboard)
	var climb := surfaces.climb_out(feet, Vector2(0.0, -1.0), pose, rules)
	assert_not_null(climb, "up the ladder")
	assert_eq(SimFixtures.name_of(layout, climb.surface), &"main deck")
	assert_eq(climb.stand.y, 0.0)
	assert_null(surfaces.climb_out(feet, Vector2(0.0, 1.0), pose, rules), "facing away")
	var aft := feet + Vector3(-4.0, 0.0, 0.0)
	assert_null(surfaces.climb_out(aft, Vector2(0.0, -1.0), pose, rules), "away from it")
	var found := surfaces.nearest_climb(aft, pose, rules, 10.0)
	assert_not_null(found, "the ladder is the nearest way out")
	assert_almost_eq(found.stand.x, ladder.from.x, 0.0001, "its nearer, after end")


func test_the_ship_is_sunk_only_when_every_surface_is() -> void:
	var surfaces := Surfaces.new(_steamer())
	var schedule := SinkSchedule.new(
		load(SimFixtures.STEAMER_SINKING), _steamer().freeboard, RandomNumberGenerator.new()
	)
	var depth := SimFixtures.rules().wade_depth
	assert_false(surfaces.sunk(schedule.pose_at(0), depth))
	assert_false(surfaces.sunk(schedule.pose_at(150 * Ticks.RATE), depth))
	assert_true(surfaces.sunk(schedule.pose_at(240 * Ticks.RATE), depth), "after the plunge")


func test_sunk_passes_over_a_collapsed_platform() -> void:
	# The flat deck 1 m under the sea, and a roof standing 3 m over its middle: the
	# ship is not sunk while the roof stands, and is once it has collapsed.
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	var roof := ShipPlatform.new()
	roof.name = &"roof"
	roof.area = Rect2(-1.0, -1.0, 2.0, 2.0)
	roof.height = 3.0
	var platforms := layout.platforms.duplicate()
	platforms.append(roof)
	layout.platforms = platforms
	var surfaces := Surfaces.new(layout)
	var sinking := SimFixtures.scenario([[0.0, layout.freeboard + 1.0, 0.0, 0.0]])
	var pose := SimFixtures.sim(1, sinking, layout).pose()
	var depth := SimFixtures.rules().wade_depth
	assert_false(surfaces.sunk(pose, depth), "the roof stands out of the sea")
	pose.collapsed = [&"roof"] as Array[StringName]
	surfaces.honour(pose)
	assert_true(surfaces.sunk(pose, depth), "gone, it is nothing standing")


func test_a_collapsed_deck_takes_its_ladder() -> void:
	# Below the starboard boarding ladder, with the main deck collapsed under the pose:
	# no way up it, and it is nobody's nearest way out.
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var pose := SimFixtures.sim(1, load(SimFixtures.STEAMER_SINKING), layout).pose()
	var ladder: ShipLadder = layout.ladders[1]
	var middle := (ladder.from + ladder.to) * 0.5
	var outboard := ladder.from.y + rules.body_radius + 0.2
	var feet := Vector3(middle.x, pose.sea_height(middle.x, outboard) - rules.swim_depth, outboard)
	assert_not_null(surfaces.climb_out(feet, Vector2(0.0, -1.0), pose, rules), "up it, standing")
	pose.collapsed = [&"main deck"] as Array[StringName]
	surfaces.honour(pose)
	assert_null(surfaces.climb_out(feet, Vector2(0.0, -1.0), pose, rules), "not up it, gone")
	assert_null(surfaces.nearest_climb(feet, pose, rules, 10.0), "nor anywhere near")


## honour keeps the broken spans it is handed, not the caller's list: the same list
## edited in place between two calls, under the same pose, masks afresh.
func test_honour_sees_a_broken_list_edited_in_place() -> void:
	var rules := SimFixtures.rules()
	var surfaces := Surfaces.new(SimFixtures.deck())
	var pose := SimFixtures.sim(1).pose()
	# A little into the flat deck's starboard span aft of the gap, span 2.
	var into := SimFixtures.deck().platforms[0].area.end.y - rules.body_radius + 0.1
	var starboard := Vector3(-8.0, 0.0, into)
	var broken := PackedInt32Array()
	surfaces.honour(pose, broken)
	assert_eq(surfaces.rail_contacts(starboard, rules.body_radius, 0).size(), 1, "it stands")
	broken.append(2)
	surfaces.honour(pose, broken)
	assert_true(surfaces.rail_contacts(starboard, rules.body_radius, 0).is_empty(), "broken")
	broken.clear()
	surfaces.honour(pose, broken)
	assert_eq(surfaces.rail_contacts(starboard, rules.body_radius, 0).size(), 1, "whole again")


func test_nobody_climbs_onto_a_round_blocker_top() -> void:
	# The sea 0.4 m under the steamer's funnel top, everything else long under: a
	# swimmer pressing into the funnel finds no way up it.
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var rules := SimFixtures.rules()
	var funnel: ShipBlocker = layout.blockers[0]
	assert_eq(funnel.shape, ShipBlocker.Shape.CYLINDER)
	var sea := funnel.top - 0.4
	var sinking := SimFixtures.scenario([[0.0, layout.freeboard + sea, 0.0, 0.0]])
	var pose := SimFixtures.sim(1, sinking, layout).pose()
	var beside := funnel.centre + Vector2(0.0, funnel.radius + rules.body_radius + 0.05)
	var feet := Vector3(beside.x, sea - rules.swim_depth, beside.y)
	assert_null(surfaces.climb_out(feet, Vector2(0.0, -1.0), pose, rules), "not up a funnel")
	assert_null(surfaces.nearest_climb(feet, pose, rules, 10.0), "nor is it a way out")


func test_line_of_sight_is_blocked_by_walls_not_by_doorways() -> void:
	var eye := 1.6
	var walled := Surfaces.new(_walled_layout())
	var level := SimFixtures.sim(1).pose()
	# Across the wall along x = 0: through its doorway, square or slanting, and not
	# through the wall beside it — from either end.
	var through: Array[Vector3] = [Vector3(-3.0, eye, 0.0), Vector3(3.0, eye, 0.0)]
	var slanting: Array[Vector3] = [Vector3(-3.0, eye, -0.3), Vector3(3.0, eye, 0.3)]
	var walled_off: Array[Vector3] = [Vector3(-3.0, eye, -2.0), Vector3(3.0, eye, -2.0)]
	for pair: Array in [through, slanting]:
		assert_true(walled.line_of_sight(pair[0], pair[1], level), "%s: the doorway" % [pair])
		assert_true(walled.line_of_sight(pair[1], pair[0], level), "%s: back" % [pair])
	assert_false(walled.line_of_sight(walled_off[0], walled_off[1], level), "the wall")
	assert_false(walled.line_of_sight(walled_off[1], walled_off[0], level), "the wall, back")
	var low_wall := Vector3(-1.0, 3.0, -2.0)
	assert_true(walled.line_of_sight(low_wall, walled_off[1] + Vector3.UP * 1.5, level), "over")
	# A crate between two bodies hides neither, even with their eyes under its lid.
	var rules := SimFixtures.rules()
	var crates: Array[ShipProp] = [SimFixtures.crate(Vector3.ZERO)]
	var crated := SimFixtures.crated(crates)
	var cargo := Surfaces.new(crated)
	cargo.honour(level, PackedInt32Array(), PropState.from_layout(crated))
	var beside := Vector3(crates[0].radius, 0.0, 0.0)
	assert_false(
		(
			cargo
			. obstacle_contacts(beside, rules.body_radius, rules.body_height, rules.step_height)
			. is_empty()
		),
		"the crate stands there"
	)
	var under_lid := crates[0].height * 0.5
	assert_true(
		cargo.line_of_sight(Vector3(-3.0, under_lid, 0.0), Vector3(3.0, under_lid, 0.0), level),
		"the crate"
	)

	# On the steamer: the main deck hides the lower deck under it, the opening over the
	# forward companionway does not, nor does a deck once it has collapsed.
	var layout := _steamer()
	var surfaces := Surfaces.new(layout)
	var calm := SimFixtures.sim(1, null, layout).pose()
	var on_deck := Vector3(8.0, eye, 1.45)
	assert_false(surfaces.line_of_sight(on_deck, Vector3(6.0, -2.6 + eye, 1.45), calm), "a deck")
	assert_true(
		surfaces.line_of_sight(on_deck, Vector3(12.6, -2.6 + eye, 1.45), calm), "down the stair"
	)
	var in_wheelhouse := Vector3(-2.5, 2.5 + eye, 0.0)
	var on_bridge := Vector3(-2.5, 4.7 + eye, 0.0)
	assert_false(surfaces.line_of_sight(in_wheelhouse, on_bridge, calm), "the bridge over it")
	var gone := SimFixtures.sim(1, null, layout).pose()
	gone.collapsed = [&"bridge"] as Array[StringName]
	assert_true(surfaces.line_of_sight(in_wheelhouse, on_bridge, gone), "the bridge collapsed")
	# From the poop deck's rail, a swimmer under the side is behind the hull; one well
	# off it is in plain view.
	var at_the_rail := Vector3(-17.0, 1.2 + eye, 4.0)
	var under_the_side := Vector3(-17.0, -layout.freeboard + 0.15, 5.0)
	assert_false(surfaces.line_of_sight(at_the_rail, under_the_side, calm), "the hull")
	var off_the_side := Vector3(-17.0, -layout.freeboard + 0.15, 12.0)
	assert_true(surfaces.line_of_sight(at_the_rail, off_the_side, calm), "the open sea")
