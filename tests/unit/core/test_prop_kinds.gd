extends GutTest
## The kinds of her props (#273, data/props/*.tres): every one loads and plays, and the
## numbers a kind must hold to — a size of a radius and a height, a walk for one that is
## held, a cold that still ends for one that keeps its holder afloat — are checked.


func test_every_kind_of_hers_plays() -> void:
	var names := PropKind.names()
	assert_true("cargo" in names and "lifebuoy" in names, "cargo and the lifebuoy at least")
	for kind_name: String in names:
		var kind := PropKind.named(StringName(kind_name))
		assert_not_null(kind, kind_name)
		if kind != null:
			assert_eq(kind.problems(), PackedStringArray(), kind_name)


## A ring that kept its holder afloat with no cold at all would let a match never end.
func test_a_kind_that_keeps_its_holder_afloat_must_still_let_the_cold_in() -> void:
	var ring: PropKind = PropKind.named(&"lifebuoy").duplicate()
	for rate: float in [0.0, -0.1, 1.5]:
		ring.sea_cold_rate = rate
		assert_false(ring.problems().is_empty(), "sea_cold_rate %s" % rate)
	ring.sea_cold_rate = 1.0
	assert_true(ring.problems().is_empty(), "the open water's own rate is allowed")


func test_a_kind_is_checked_for_its_size_and_walk() -> void:
	var ring: PropKind = PropKind.named(&"lifebuoy").duplicate()
	ring.height = 0.0
	assert_false(ring.problems().is_empty(), "a radius with no height")
	ring = PropKind.named(&"lifebuoy").duplicate()
	ring.carry_walk = 0.0
	assert_false(ring.problems().is_empty(), "held, it must still walk")


## A layout's prop of a kind with a size must be that size, and only a prop that can be
## held hangs on a railing (ShipProp.problems).
func test_a_prop_must_be_its_kinds_size_and_only_a_held_kind_hangs() -> void:
	var ring := SimFixtures.lifebuoy(Vector3.ZERO, 0)
	assert_true(ring.problems().is_empty())
	ring.radius = 0.5
	assert_false(ring.problems().is_empty(), "not its kind's size")
	var crate := SimFixtures.crate(Vector3.ZERO)
	crate.railing = 0
	assert_false(crate.problems().is_empty(), "cargo never hangs")
	var unknown := SimFixtures.crate(Vector3.ZERO)
	unknown.kind = &"anchor"
	assert_false(unknown.problems().is_empty(), "no such kind")
