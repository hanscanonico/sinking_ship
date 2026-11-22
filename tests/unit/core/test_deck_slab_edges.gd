extends GutTest
## A deck over another is a slab, and a slab holds a body back at its edge only: a body or
## a prop wholly in under its area — its head a hair through it, or sunk through it — is
## under the deck, not in it, and is never thrown out to the slab's nearest side, metres off
## through her walls. At its edge it holds a body as it did, and a deck over none, the top
## of a solid hull, still puts out whatever is inside it. Worked alike in GDScript and by
## the extension.

const Fixtures := preload("res://tests/unit/sim_fixtures.gd")

## The slab over the floor: too high to step onto, lower than a body is tall.
const HIGH := 1.0
## The slab's area, well inside the floor's.
const SLAB := Rect2(-4.0, -4.0, 8.0, 8.0)
## The flat deck's roof (_roofed): from x -2 to 2 across her beam.
const ROOF := Rect2(-2.0, -4.0, 4.0, 8.0)

var _rules := Fixtures.rules()


func after_each() -> void:
	ContactsNative.off = false


## A floor at 0 — when [param floored] — and SLAB as a deck HIGH over it: test data.
func _layout(floored := true) -> ShipLayout:
	var layout := ShipLayout.new()
	var decks: Array[ShipPlatform] = []
	if floored:
		var floor_deck := ShipPlatform.new()
		floor_deck.name = &"floor"
		floor_deck.area = Rect2(-10.0, -10.0, 20.0, 20.0)
		floor_deck.height = 0.0
		decks.append(floor_deck)
	var slab := ShipPlatform.new()
	slab.name = &"slab"
	slab.area = SLAB
	slab.height = HIGH
	decks.append(slab)
	layout.platforms = decks
	return layout


## What holds back a body with its feet at [param at] on [param layout]'s Surfaces, in
## GDScript and, where it is loaded, by the extension; both must agree.
func _held(layout: ShipLayout, at: Vector3) -> Array[Surfaces.Contact]:
	ContactsNative.off = true
	var reference := Surfaces.new(layout)
	ContactsNative.off = false
	var theirs := reference.obstacle_contacts(
		at, _rules.body_radius, _rules.body_height, _rules.step_height
	)
	var native := Surfaces.new(layout)
	if native.native != null:
		var mine := native.obstacle_contacts(
			at, _rules.body_radius, _rules.body_height, _rules.step_height
		)
		assert_eq(_told(mine), _told(theirs), "the extension holds it alike at %s" % at)
	return theirs


static func _told(contacts: Array[Surfaces.Contact]) -> Array[String]:
	var told: Array[String] = []
	for contact: Surfaces.Contact in contacts:
		told.append("n%s d%.4f" % [contact.normal, contact.depth])
	return told


## The flat deck carrying [param props], with a roof [param roof] metres over the deck
## over ROOF: test data.
func _roofed(roof: float, props: Array[ShipProp] = []) -> ShipLayout:
	var layout := Fixtures.crated(props)
	layout.platforms = layout.platforms.duplicate()
	var over := ShipPlatform.new()
	over.name = &"roof"
	over.area = ROOF
	over.height = roof
	layout.platforms.append(over)
	return layout


func test_a_body_under_a_slab_well_inside_its_area_is_held_by_none_of_its_edges() -> void:
	# On the floor under the middle of the slab, its head through it: four metres from any
	# edge of it.
	var held := _held(_layout(), Vector3.ZERO)
	assert_eq(held.size(), 0, "under the deck, at no edge of it: %s" % [_told(held)])


func test_a_slab_never_moves_a_body_under_it_farther_than_a_body_overlaps_its_edge() -> void:
	var layout := _layout()
	var widest := _rules.body_radius * 2.0
	# Wherever it stands under the slab or beside it, and however deep its feet are under
	# the slab's top: never out to an edge farther off than its own width.
	for feet: float in [0.0, 0.3, HIGH - _rules.step_height - 0.01]:
		for step_x in 21:
			for step_z in 21:
				var at := Vector3(-5.0 + step_x * 0.5, feet, -5.0 + step_z * 0.5)
				for contact: Surfaces.Contact in _held(layout, at):
					assert_lte(contact.depth, widest, "at %s: %s" % [at, contact.normal])


func test_a_body_at_a_slab_s_edge_is_still_pushed_out_of_it() -> void:
	var layout := _layout()
	var radius := _rules.body_radius
	# Its middle outside the edge, its circle over it.
	var outside := _held(layout, Vector3(4.2, 0.0, 0.0))
	assert_eq(outside.size(), 1, "held once: %s" % [_told(outside)])
	if outside.size() == 1:
		assert_true(outside[0].normal.is_equal_approx(Vector2.RIGHT))
		assert_almost_eq(outside[0].depth, radius - 0.2, 1e-5)
	# Its middle a tick's move in over the edge: out through that edge, all of it.
	var over := _held(layout, Vector3(3.9, 0.0, 0.0))
	assert_eq(over.size(), 1, "held once: %s" % [_told(over)])
	if over.size() == 1:
		assert_true(over[0].normal.is_equal_approx(Vector2.RIGHT))
		assert_almost_eq(over[0].depth, radius + 0.1, 1e-5)
	# The last of its circle still over the edge.
	var last := _held(layout, Vector3(0.0, 0.0, -4.0 + radius - 0.01))
	assert_eq(last.size(), 1, "held once: %s" % [_told(last)])
	if last.size() == 1:
		assert_true(last[0].normal.is_equal_approx(Vector2.UP))
		assert_almost_eq(last[0].depth, radius * 2.0 - 0.01, 1e-5)


func test_a_deck_over_none_still_puts_out_a_body_inside_her_solid_hull() -> void:
	# No floor under it: the top of a hull solid all the way down, and a body is in it.
	var held := _held(_layout(false), Vector3(3.0, 0.0, 0.0))
	assert_eq(held.size(), 1, "held once: %s" % [_told(held)])
	if held.size() == 1:
		assert_true(held[0].normal.is_equal_approx(Vector2.RIGHT))
		assert_almost_eq(held[0].depth, 1.0 + _rules.body_radius, 1e-5)


func test_a_body_sunk_through_a_deck_comes_down_under_it_where_it_was() -> void:
	var roof := 2.0
	var sim := Fixtures.sim(1, null, _roofed(roof))
	# Its feet half a metre under the roof's top, its head over it, two metres from the
	# roof's nearest side: a state a swimmer reading no water over a deck sinks into.
	var start := Vector3(0.0, roof - 0.5, 0.0)
	Fixtures.fly(sim, 0, start, Vector3.ZERO)
	var player := sim.state.seats[0]
	for _tick in Ticks.from_seconds(1.5):
		Fixtures.step(sim)
		var off := Vector2(player.pos.x - start.x, player.pos.z - start.z)
		assert_lt(off.length(), 0.001, "never thrown sideways: at %s" % player.pos)
	assert_eq(player.body, PlayerState.Body.GROUNDED, "down on the deck under the roof")
	assert_almost_eq(player.pos.y, 0.0, 0.0001)


func test_a_body_jumping_up_under_a_deck_comes_down_where_it_jumped() -> void:
	# A roof a jump reaches: its head stops against it (Movement._ceilings), its feet then
	# the nearest float32 to roof less its height — which, with its height back on, may be
	# a hair over the roof's underside.
	for roof: float in [2.0, 2.1, 2.2, 2.3, 2.4, 2.5]:
		var sim := Fixtures.sim(1, null, _roofed(roof))
		Fixtures.place(sim, 0, Vector3.ZERO)
		var player := sim.state.seats[0]
		Fixtures.step(sim, {0: Fixtures.frame(0, Vector2.ZERO, InputFrame.JUMP)})
		for _tick in Ticks.from_seconds(1.5):
			Fixtures.step(sim, {0: Fixtures.frame(0)})
			var off := Vector2(player.pos.x, player.pos.z)
			if off.length() >= 0.001:
				fail_test("under a roof at %s: thrown sideways to %s" % [roof, player.pos])
				break
		assert_eq(player.body, PlayerState.Body.GROUNDED, "down again under a roof at %s" % roof)


func test_a_chair_afloat_pressed_under_a_deck_stays_under_it() -> void:
	# The water over the deck rises past the roof: a chair afloat under it is pressed under
	# it (Hazards._float), its top at the roof's underside — to the nearest float32, a hair
	# through it, as under a liner's C deck.
	for roof: float in [1.2, 1.3, 1.4, 1.5, 1.6]:
		var props: Array[ShipProp] = [Fixtures.chair(Vector3(0.0, 0.0, 0.5))]
		var edge := Fixtures.deck().freeboard
		var sinking := Fixtures.scenario(
			[[0.0, edge, 0.0, 0.0], [3.0, edge + roof - 0.1, 0.0, 0.0]]
		)
		var sim := Fixtures.sim(1, sinking, _roofed(roof, props))
		Fixtures.place(sim, 0, Vector3(1.5, roof, 3.5))
		var chair := sim.state.props[0]
		for _tick in Ticks.from_seconds(5.0):
			Fixtures.step(sim)
			var off := Vector2(chair.pos.x, chair.pos.z - 0.5)
			if off.length() >= 0.01:
				fail_test("under a roof at %s: thrown sideways to %s" % [roof, chair.pos])
				break
		assert_eq(chair.body, PropState.Body.FLOATING, "afloat under a roof at %s" % roof)
		var height := PropKind.named(&"dining_chair").height
		assert_almost_eq(chair.pos.y, roof - height, 0.0001, "pressed under it")
