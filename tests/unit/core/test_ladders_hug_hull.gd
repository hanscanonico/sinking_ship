extends GutTest
## A boarding ladder hangs down her side on her shell (D6, SH5): from its deck to under
## the sea, following her flare and her bilge — the Titanic's
## flare out of her well decks' edges and come in under the sea — never through her
## plating; and a body climbing it hangs outside her shell at every height.

## How far under her waterline the drawn ladder reaches (ShipArt.LADDER_BELOW), and the
## steps its line is read at on the way.
const BELOW := 0.4
const STEP := 0.1
## Her shell and a ladder on it, or a climber against it, are one this close.
const NEAR := 0.0001


## Every height from [param ladder]'s top down past [param layout]'s waterline, STEP
## apart.
func _heights(layout: ShipLayout, ladder: ShipLadder) -> PackedFloat64Array:
	var heights := PackedFloat64Array()
	var height := layout.platforms[ladder.platform].height
	while height > -layout.freeboard - BELOW:
		heights.append(height)
		height -= STEP
	return heights


func test_every_ladder_down_her_side_lies_on_her_shell() -> void:
	for ship: StringName in [&"titanic", &"ferry", &"trawler", &"steamer"]:
		var layout := Fleet.layout(ship)
		assert_false(layout.ladders.is_empty(), "%s has ladders" % ship)
		for index in layout.ladders.size():
			var ladder := layout.ladders[index]
			var way := 1 if layout.ladder_outward(ladder).y > 0.0 else -1
			for height in _heights(layout, ladder):
				var hangs := layout.ladder_at(ladder, height)
				for end in 2:
					var shell := layout.structure.half_breadth(hangs[end].x, height, way)
					if shell <= 0.0:
						continue
					assert_almost_eq(
						hangs[end].y * way,
						shell,
						NEAR,
						"%s ladder %d, end %d, on her shell at %.1f m" % [ship, index, end, height]
					)


func test_the_titanic_ladders_flare_out_and_come_in_under_the_sea() -> void:
	# Her well decks' edges stand inside her shell at their height and outside it at
	# the waterline: her ladders reach out over her flare at the top and in to her side
	# at the foot.
	var layout := Fleet.layout(&"titanic")
	assert_eq(layout.ladders.size(), 4)
	for ladder: ShipLadder in layout.ladders:
		var deck := layout.platforms[ladder.platform]
		var edge := absf(ladder.from.y)
		var top := layout.ladder_at(ladder, deck.height)
		var foot := layout.ladder_at(ladder, -layout.freeboard)
		for end in 2:
			assert_gt(absf(top[end].y), edge + 0.5, "out over her flare at the deck")
			assert_lt(absf(foot[end].y), edge - 1.5, "in to her side at the sea")
			assert_eq(top[end].x, [ladder.from, ladder.to][end].x, "along her at its own x")


func test_a_wall_sided_ladder_hangs_from_its_deck_edge() -> void:
	# The steamer's side stands plumb at her main deck's edge down to her bilge: her
	# ladders hang as they always did, straight down from it.
	var layout := Fleet.layout(&"steamer")
	for ladder: ShipLadder in layout.ladders:
		var height := 0.0
		while height > -2.5:
			var hangs := layout.ladder_at(ladder, height)
			assert_almost_eq(hangs[0].distance_to(ladder.from), 0.0, NEAR, "at %.1f m" % height)
			assert_almost_eq(hangs[1].distance_to(ladder.to), 0.0, NEAR, "at %.1f m" % height)
			height -= STEP


func test_a_ladder_with_no_structure_hangs_from_its_edge() -> void:
	var layout: ShipLayout = Fleet.layout(&"titanic").duplicate()
	layout.structure = null
	var ladder := layout.ladders[0]
	var hangs := layout.ladder_at(ladder, -layout.freeboard)
	assert_eq(hangs[0], ladder.from)
	assert_eq(hangs[1], ladder.to)


func test_a_climber_up_the_titanic_hangs_outside_her_shell() -> void:
	# A swimmer at the after well's port ladder, pressing in to her side: it climbs,
	# and every tick it hangs on the ladder its body stands outside her plating.
	var layout := Fleet.layout(&"titanic")
	var rules := SimFixtures.rules()
	var ladder: ShipLadder
	for each: ShipLadder in layout.ladders:
		if layout.platforms[each.platform].name == &"after well deck" and each.from.y < 0.0:
			ladder = each
	assert_not_null(ladder, "the ladder")
	if ladder == null:
		return
	var sim := SimFixtures.sim(2, SimFixtures.calm(), layout)
	SimFixtures.place(sim, 1, Vector3(82.0, 0.0, 0.0))
	var middle := (ladder.from + ladder.to) * 0.5
	# Just off it where a swimmer takes hold, a reach up her flare over the water.
	var foot := layout.ladder_at(ladder, -layout.freeboard + rules.climb_reach)
	var out := foot[0].y - rules.body_radius - 0.2
	SimFixtures.swim(sim, 0, Vector3(middle.x, 0.0, out))
	var climber := sim.state.seats[0]
	var starboard := {0: SimFixtures.frame(0, Vector2(0.0, 1.0))}
	var hung := 0
	var climbed := false
	for _tick in Ticks.from_seconds(rules.cold_meter + 10.0):
		var was_climbing := climber.is_climbing()
		for event: SimEvent in SimFixtures.step(sim, starboard):
			climbed = climbed or event.kind == SimEvent.Kind.CLIMBED_OUT
		if climbed:
			break
		if not (was_climbing and climber.is_climbing()):
			continue
		var feet := climber.pos
		if feet.y < climber.climb_to.y - 1.0:
			hung += 1
			var shell := layout.structure.half_breadth(feet.x, feet.y, -1)
			assert_gt(
				-feet.z,
				shell + rules.body_radius - 0.01,
				"outside her shell at %.2f m: %.2f against %.2f" % [feet.y, -feet.z, shell]
			)
	assert_true(climbed, "it climbed out")
	assert_gt(hung, 30, "it hung on her side on the way up")
	assert_eq(SimFixtures.name_of(layout, climber.surface), &"after well deck", "up the ladder")


func test_a_climber_inside_her_shell_is_left_where_it_is() -> void:
	# In a pocket inside her, climbing onto a dry face: off_hull() never moves it out
	# through her side; outside her, it keeps a body's radius off her plating.
	var structure := Fleet.layout(&"titanic").structure
	var before := Vector3(-100.0, -6.0, -2.0)
	var after := Vector3(-100.0, -5.9, -2.0)
	assert_eq(structure.off_hull(before, after, 0.4), after)
	var outside := Vector3(-100.0, -11.0, -7.0)
	var rising := Vector3(-100.0, -2.0, -7.0)
	var shell := structure.half_breadth(-100.0, -2.0, -1)
	assert_almost_eq(structure.off_hull(outside, rising, 0.4).z, -(shell + 0.4), NEAR, "out")
