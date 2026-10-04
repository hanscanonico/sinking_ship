extends GutTest
## A server's room codes come from SecureDraws (SH12, R9): every number below a count
## comes up and none past it, and a u32 spans all 32 bits.

const DRAWS := 2000


func test_below_reaches_every_number_and_none_past() -> void:
	var draws := SecureDraws.new()
	var count := RoomCodec.CODE_LETTERS.length()
	var seen := {}
	for _draw in DRAWS:
		seen[draws.below(count)] = true
	var drawn: Array = seen.keys()
	drawn.sort()
	assert_eq(drawn, range(count), "every letter, and nothing else")


func test_u32_spans_32_bits() -> void:
	var draws := SecureDraws.new()
	var lowest := SecureDraws.SPAN
	var highest := -1
	for _draw in DRAWS:
		var drawn := draws.u32()
		lowest = mini(lowest, drawn)
		highest = maxi(highest, drawn)
	assert_gte(lowest, 0)
	assert_lt(highest, SecureDraws.SPAN)
	assert_gte(highest, 1 << 31, "the top bit is drawn too")
