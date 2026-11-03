extends GutTest
## How art-lint deals a ship's checks among its parts (tools/art_lint_costs.gd, --part):
## by what each cost on a CI runner, as tools/art_lint_costs.tsv has it, the dearest
## first to the cheapest part so far, so the parts finish together and every check is
## made exactly once, in the same part on every run.

const ArtLintCosts := preload("res://tools/art_lint_costs.gd")


func _units(count: int) -> PackedStringArray:
	var units := PackedStringArray()
	for index in count:
		units.append("blocker\t%d" % index)
	units.append_array(["hull\t0", "panes\t0", "stretch\t-2", "stretch\t5"])
	return units


func _loads(dealt: Dictionary, costs: Dictionary, parts: int) -> PackedFloat64Array:
	var loads := PackedFloat64Array()
	loads.resize(parts)
	for unit: String in dealt:
		loads[dealt[unit]] += costs.get(unit, 0.0)
	return loads


func test_every_check_lands_in_exactly_one_part() -> void:
	var units := _units(40)
	for parts: int in [1, 2, 3, 7]:
		var dealt := ArtLintCosts.deal(units, {"blocker\t3": 900.0}, parts)
		assert_eq(dealt.size(), units.size(), "%d parts: every check dealt" % parts)
		for unit in units:
			assert_true(dealt.has(unit), "%d parts: %s dealt" % [parts, unit])
			var part: int = dealt.get(unit, -1)
			assert_true(part >= 0 and part < parts, "%d parts: %s to part %d" % [parts, unit, part])


func test_the_same_checks_deal_the_same_whatever_their_order() -> void:
	var units := _units(30)
	var costs := {"blocker\t4": 50.0, "stretch\t5": 50.0, "hull\t0": 7.0}
	var dealt := ArtLintCosts.deal(units, costs, 3)
	var reversed := units.duplicate()
	reversed.reverse()
	assert_eq(ArtLintCosts.deal(units, costs, 3), dealt, "dealt again")
	assert_eq(ArtLintCosts.deal(reversed, costs, 3), dealt, "listed the other way round")


func test_the_parts_share_the_cost_not_the_count() -> void:
	# One dear check and six cheap ones: by count the dear one's part takes three more.
	var costs := {"stretch\t0": 60.0}
	var units := PackedStringArray(["stretch\t0"])
	for index in 6:
		units.append("blocker\t%d" % index)
		costs["blocker\t%d" % index] = 10.0
	var loads := _loads(ArtLintCosts.deal(units, costs, 2), costs, 2)
	assert_eq(loads[0], 60.0, "the dear check alone")
	assert_eq(loads[1], 60.0, "the cheap ones together")


func test_a_check_the_table_has_not_timed_weighs_its_kind_s_middle() -> void:
	var costs := {"blocker\t0": 1.0, "blocker\t1": 30.0, "blocker\t2": 40.0, "hull\t0": 100.0}
	assert_eq(ArtLintCosts.weights(PackedStringArray(["blocker\t9"]), costs)[0], 30.0)
	assert_eq(ArtLintCosts.weights(PackedStringArray(["hull\t0"]), costs)[0], 100.0)
	assert_eq(
		ArtLintCosts.weights(PackedStringArray(["ladder\t0"]), costs)[0],
		35.0,
		"a kind it has never timed weighs every check's middle"
	)


func test_the_table_reads_one_ship_s_rows() -> void:
	var path := "user://art_lint_costs_test.tsv"
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(
		"# a comment\ntitanic\tblocker\t3\t12.5\ntug\tblocker\t3\t99\n\ntitanic\thull\t0\t7\n"
	)
	out.close()
	assert_eq(ArtLintCosts.table(path, "titanic"), {"blocker\t3": 12.5, "hull\t0": 7.0})
	assert_eq(ArtLintCosts.table("user://no_such_table.tsv", "titanic"), {}, "no file, no costs")
	DirAccess.remove_absolute(path)
