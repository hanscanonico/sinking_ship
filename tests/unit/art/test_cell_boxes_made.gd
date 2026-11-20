extends GutTest
## Her water's boxes and stacks made with her shell read once a make (CellBoxes.Shells,
## #640): the same, bit for bit, as reading it afresh at every ask, and as they were made
## before — those of main at 32724938, hashed.

## Per ship, the SHA-256 of var_to_bytes([boxes, stacks]) (CellBoxes._make) as main made
## them before her shell's reads were kept.
const MADE := {
	&"steamer": "157ac16fb17f0d8103e0e2e3825b29e746fa53be0d6e8a3717f81d454afe829e",
	&"small_titanic": "5cb3208278f5f5f50c76703abd8f336835556b6d5bfefd352650d54199db0f0d",
	&"titanic": "3b59862abc3c99e9d1beb9d01f0aadd6d74690079b3849c8ea9b57a6f52ece55",
}
const STEAMER := "res://data/ships/steamer.tres"
const SMALL_TITANIC := "res://data/ships/small_titanic.tres"
const TITANIC := "res://data/ships/titanic.tres"


func _layout(ship_name: StringName) -> ShipLayout:
	match ship_name:
		&"steamer":
			return load(STEAMER)
		&"small_titanic":
			return load(SMALL_TITANIC)
	return load(TITANIC)


func test_kept_reads_make_what_fresh_reads_make() -> void:
	for ship_name: StringName in [&"steamer", &"small_titanic"]:
		var layout := _layout(ship_name)
		var kept := CellBoxes._make(layout.structure, layout.rooms)
		var fresh := CellBoxes._make(layout.structure, layout.rooms, CellBoxes.Shells.new(0))
		assert_eq(var_to_bytes(kept), var_to_bytes(fresh), "%s's boxes and stacks" % ship_name)


func test_made_as_before() -> void:
	for ship_name: StringName in MADE:
		var layout := _layout(ship_name)
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(var_to_bytes(CellBoxes._make(layout.structure, layout.rooms)))
		assert_eq(
			hashing.finish().hex_encode(), MADE[ship_name], "%s's boxes and stacks" % ship_name
		)
