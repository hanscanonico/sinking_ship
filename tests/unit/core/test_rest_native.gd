extends GutTest
## Hazards._stirring's rest test natively (NativeRest) against the GDScript it stands in
## for: a saloon's tables and chairs at rest as the sea comes up through her and lifts
## them, stepped tick by tick in one match natively and in its twin in GDScript — every
## crate's turn, piece and state alike each tick, the extension deciding most of those at
## rest, and crates at rest waking as the water reaches them. Where the extension is not
## loaded there is nothing to hold it to; CI sets SINKING_NATIVE_REQUIRED.

const SMALL_TITANIC := "res://data/ships/small_titanic.tres"
const TICKS := 150


func after_each() -> void:
	ContactsNative.off = false


func test_crates_at_rest_rest_and_wake_alike_as_the_sea_comes_up() -> void:
	if not _loaded():
		return
	var layout: ShipLayout = load(SMALL_TITANIC)
	var lowest := INF
	for prop: ShipProp in layout.props:
		if prop.kind == &"dining_table":
			lowest = minf(lowest, prop.pos.y)
	var sea := layout.freeboard + lowest
	var scenario := SimFixtures.scenario(
		[[0.0, sea - 0.5, 0.0, 0.0], [2.0, sea + 0.4, 1.0, 2.0], [5.0, sea + 1.5, 2.0, 4.0]]
	)
	var native := SimFixtures.sim(2, scenario, layout)
	ContactsNative.off = true
	var reference := SimFixtures.sim(2, scenario, layout)
	ContactsNative.off = false
	assert_not_null(native._hazards._rest_native, "the rest test runs natively")
	assert_null(reference._hazards._rest_native, "its twin in GDScript")
	var most_resting := 0
	var woken := 0
	var turned := PackedByteArray()
	for tick in TICKS:
		SimFixtures.step(native)
		ContactsNative.off = true
		SimFixtures.step(reference)
		ContactsNative.off = false
		var turn := native._hazards._turn.duplicate()
		if turn != reference._hazards._turn:
			fail_test("tick %d: the crates' turns differ natively" % tick)
			return
		if native._hazards._aboard != reference._hazards._aboard:
			fail_test("tick %d: the crates' pieces differ natively" % tick)
			return
		if var_to_bytes(native.snapshot()) != var_to_bytes(reference.snapshot()):
			fail_test("tick %d differs natively" % tick)
			return
		most_resting = maxi(most_resting, turn.count(Hazards.Turn.RESTS))
		for prop in turned.size():
			if turned[prop] == Hazards.Turn.RESTS and turn[prop] == Hazards.Turn.STEPS:
				woken += 1
		turned = turn
	assert_gt(most_resting, 40, "most of her furniture at rest")
	assert_gt(woken, 0, "crates at rest woken as the sea reaches them")


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeRest"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
