extends GutTest
## The flooding's invariants (FloodWatch, #619) at every step of whole ships' bakes: the
## steamer's, the trawler's and the tug's sure hits, each baked to her end in her open
## sea, keep her water conserved cell by cell, running down its head, within her cells'
## boxes, rising only where something higher feeds it, and her pockets to Boyle's law.
## And the watch itself sees a breach planted in a step.

const SHIPS: Array[StringName] = [&"steamer", &"trawler", &"tug"]
## The steps a planted breach is baked for, each showing it at least once.
const PLANTED_STEPS := 20


## A stepper that makes a litre of water in each cell it gives any to.
class Making:
	extends WatchedStepper

	func _init(structure: ShipStructure, damage: HitDamage, sea: SeaPhysics) -> void:
		super(structure, damage, sea)
		# Its sweep in GDScript, where the breach is planted, the extension loaded or not.
		_native = null

	func _give_to(side: int, amount: float, state: FloodState, heads: PackedFloat64Array) -> void:
		super._give_to(side, amount, state, heads)
		if side != OUTSIDE:
			state.water[side] += 1e-3


## A stepper whose every flow runs the other way: up its head, the water still conserved.
class Uphill:
	extends WatchedStepper

	func _init(structure: ShipStructure, damage: HitDamage, sea: SeaPhysics) -> void:
		super(structure, damage, sea)
		# Its sweep in GDScript, where the breach is planted, the extension loaded or not.
		_native = null

	func _transfer(
		index: int,
		heads: PackedFloat64Array,
		sea: float,
		since: float,
		seconds: float,
		following := PackedFloat64Array()
	) -> float:
		return -super._transfer(index, heads, sea, since, seconds, following)


func _damage(ship: StringName) -> HitDamage:
	var structure := Fleet.layout(ship).structure
	var scenario := Fleet.scenario(ship)
	var damage := HitMapper.map_explicit(structure.sure_hit, structure, scenario.hit)
	damage.sea_depth = scenario.sea_depth
	return damage


## [param ship]'s sure hit baked by [param stepper]: to her end, or [param steps] steps.
func _watched(ship: StringName, stepper: WatchedStepper, steps := 1 << 62) -> FloodWatch:
	var structure := Fleet.layout(ship).structure
	var damage := _damage(ship)
	var sea := SeaPhysics.load_default()
	var bake := SinkBake.new(
		stepper, sea, Fleet.scenario(ship).bake_cap, HullBreak.of(structure, damage, sea)
	)
	bake.run(steps)
	stepper.watch.close()
	return stepper.watch


func _stepper(ship: StringName) -> WatchedStepper:
	var structure := Fleet.layout(ship).structure
	return WatchedStepper.new(structure, _damage(ship), SeaPhysics.load_default())


func test_every_step_of_the_fleets_sure_hits_keeps_the_invariants() -> void:
	var laws: Array[FloodWatch.Law] = [
		FloodWatch.Law.CONSERVED,
		FloodWatch.Law.DOWNHILL,
		FloodWatch.Law.CAPACITY,
		FloodWatch.Law.FED,
		FloodWatch.Law.BOYLE,
	]
	for ship: StringName in SHIPS:
		var watch := _watched(ship, _stepper(ship))
		assert_gt(watch.steps, 0, "%s's bake was watched" % ship)
		for law: FloodWatch.Law in laws:
			assert_eq(
				watch.counts[law],
				0,
				(
					"%s's sure hit keeps %s: %s"
					% [ship, FloodWatch.NAMES[law], "; ".join(watch.breaches(law))]
				)
			)


func test_a_watched_bake_is_the_bake_unwatched() -> void:
	var structure := Fleet.layout(&"tug").structure
	var damage := _damage(&"tug")
	var sea := SeaPhysics.load_default()
	var cap := Fleet.scenario(&"tug").bake_cap
	var unwatched := SinkStepper.new(structure, damage, sea)
	var plain := SinkBake.new(unwatched, sea, cap, HullBreak.of(structure, damage, sea))
	plain.run(1 << 62)
	var watched := SinkBake.new(_stepper(&"tug"), sea, cap, HullBreak.of(structure, damage, sea))
	watched.run(1 << 62)
	assert_eq(watched.timeline().digest(), plain.timeline().digest(), "the watch moves nothing")


func test_the_watch_sees_water_made() -> void:
	var damage := _damage(&"tug")
	var stepper := Making.new(Fleet.layout(&"tug").structure, damage, SeaPhysics.load_default())
	var watch := _watched(&"tug", stepper, PLANTED_STEPS)
	assert_gte(watch.counts[FloodWatch.Law.CONSERVED], PLANTED_STEPS, "water made is seen")


func test_the_watch_sees_water_run_up_its_head() -> void:
	var damage := _damage(&"tug")
	var stepper := Uphill.new(Fleet.layout(&"tug").structure, damage, SeaPhysics.load_default())
	var watch := _watched(&"tug", stepper, PLANTED_STEPS)
	assert_eq(watch.counts[FloodWatch.Law.CONSERVED], 0, "turned round, the water is kept")
	assert_gt(
		watch.counts[FloodWatch.Law.DOWNHILL] + watch.counts[FloodWatch.Law.DOWNHILL_CUT],
		0,
		"water run up its head is seen"
	)
