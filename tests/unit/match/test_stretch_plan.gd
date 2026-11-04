extends GutTest
## A match whose sinking breaks her is dressed whole first, her stretches built behind it
## (StretchPlan): none for a sinking that never parts her; every one after the start when
## her parting is far enough off for them all, aft to fore; one that could not be ready
## by then before the start, as every one is when none could; and each costs what its
## rooms do.

## What every stretch costs to build here, in seconds.
const COST := 10.0


## As many stretches as [param count], COST each.
func _costs(count: int) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	for stretch in count:
		found.append(COST)
	return found


## The seconds from the start by which [param built] seconds of stretches are built
## behind the match.
func _ready_by(built: float) -> float:
	return built * StretchPlan.BEHIND + StretchPlan.MARGIN


func test_a_sinking_that_never_parts_her_builds_no_stretch() -> void:
	var plan := StretchPlan.of(PackedFloat64Array(), INF)
	assert_false(plan.whole, "her art is all of her, as it always was")
	assert_eq(plan.before, PackedInt32Array(), "none before the start")
	assert_eq(plan.later, PackedInt32Array(), "none after it")


func test_a_parting_far_off_builds_every_stretch_after_the_start() -> void:
	var plan := StretchPlan.of(_costs(4), _ready_by(4 * COST))
	assert_true(plan.whole, "her whole art drawn until they are in")
	assert_eq(plan.before, PackedInt32Array(), "none holds the start")
	assert_eq(plan.later, PackedInt32Array([0, 1, 2, 3]), "every one, aft to fore")


func test_a_stretch_that_could_not_be_ready_is_built_before_the_start() -> void:
	var plan := StretchPlan.of(_costs(4), _ready_by(2.5 * COST))
	assert_true(plan.whole, "her whole art drawn until the later ones are in")
	assert_eq(plan.later, PackedInt32Array([0, 1]), "as many as are ready in time")
	assert_eq(plan.before, PackedInt32Array([2, 3]), "the rest before the start")


func test_a_parting_too_soon_for_any_builds_them_all_before_the_start() -> void:
	var plan := StretchPlan.of(_costs(4), _ready_by(0.5 * COST))
	assert_false(plan.whole, "her first stretch drawn from the start, as before")
	assert_eq(plan.before, PackedInt32Array([0, 1, 2, 3]), "every one before the start")
	assert_eq(plan.later, PackedInt32Array(), "none after it")


func test_a_stretch_costs_what_its_rooms_do() -> void:
	var few := StretchPlan.estimate(10)
	var many := StretchPlan.estimate(1000)
	assert_gt(few, 0.0, "even a stretch of few rooms takes time")
	assert_almost_eq(
		many - few, 990 * StretchPlan.SECONDS_PER_ROOM, 1e-6, "each room its share more"
	)
