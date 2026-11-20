extends GutTest
## A piece's water natively (NativePose, SinkSchedule._piece_pose) against the GDScript
## it stands in for, bit for bit: the weak hull's sinkings on her pinned seeds, whole,
## breaking in two and in three, every piece's levels, pockets and lights the same at
## every tick asked, from before the hit to past her going. Where the extension is not
## loaded there is nothing to hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing
## library there fails.

## The ticks between those asked.
const EVERY := 7


func test_her_pieces_water_is_alike_breaking_in_two() -> void:
	_alike_over(&"breaks_in_two", 2)


func test_her_pieces_water_is_alike_breaking_in_three() -> void:
	_alike_over(&"breaks_in_three", 3)


## The weak hull's match on pinned seed [param seed_name], posed natively and by the
## GDScript at every [constant EVERY]th tick to past her going: the same each time, and
## she is in [param pieces] pieces by its end.
func _alike_over(seed_name: StringName, pieces: int) -> void:
	if not _loaded():
		return
	var config := MatchConfig.from_rules(
		load("res://data/match/default.tres"), PinnedSeeds.seed_named(seed_name), 2, &"steamer_weak"
	)
	config.countdown_ticks = 0
	var native := SinkSchedule.for_match(config)
	var script := SinkSchedule.for_match(config)
	# The GDScript's walk: its extension let go — it was made as the schedule cut her into
	# pieces — and the timeline marked held as it is, so it is never made again.
	script._native = null
	script._native_of = script.timeline().count()
	var last := native.end_tick() + Ticks.RATE
	var most := 0
	var differences: Array[String] = []
	for tick in range(0, last, EVERY):
		var own := native.pose_at(tick)
		var theirs := script.pose_at(tick)
		most = maxi(most, own.standing.size())
		if own.pieces.size() != theirs.pieces.size():
			differences.append("tick %d: %d pieces" % [tick, own.pieces.size()])
			continue
		for piece in maxi(own.pieces.size(), 1):
			var mine := own.of_piece(piece)
			var other := theirs.of_piece(piece)
			if (
				mine.levels != other.levels
				or mine.pockets != other.pockets
				or mine.lit != other.lit
			):
				differences.append("tick %d, piece %d" % [tick, piece])
		if differences.size() > 10:
			break
	assert_eq(most, pieces, "she breaks into %d pieces" % pieces)
	assert_eq(differences, [] as Array[String], "every piece's water alike")
	assert_true(native._native != null, "the extension walked her cells")
	assert_null(script._native, "the GDScript walked them")


func _loaded() -> bool:
	if NativeVersion.has(&"NativePose"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the game's extension is not loaded (make native)")
	else:
		pass_test("the game's extension is not loaded: nothing to hold it to")
	return false
