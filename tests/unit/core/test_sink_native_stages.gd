extends GutTest
## The bake's stages around its solves natively (#411, NativeSink's sink_step_native.cpp)
## against the GDScript they stand in for, bit for bit, on her real ships' bakes: at every
## step checked, each opening's share open (SinkStepper._share_out), the cells a step
## holds stiff (_hold_stiff before its groups), and her failures' heads across every
## opening that can fail, what gives way at them and how far each stands from it
## (SinkFailures) — at the bake's own state, and at states made harder: heads set on
## every sill, floor and ceiling and a hair either side, water dry or full, cells held,
## heads across set on every leak and collapse head and a hair either side with either
## sign, openings part open, leaking or given way, and the seconds set on every shut
## time and a hair either side. Where the extension is not loaded there is nothing to
## hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing library there fails.

const SEED := 4
## Each ship's window of her first bake checked: the steps taken first, natively alone,
## and the steps checked.
const WINDOWS := {
	&"steamer": Vector2i(0, 1500),
	&"small_titanic": Vector2i(600, 400),
	&"titanic": Vector2i(0, 150),
}


## A stepper that works its shares, its stiff cells and its failures natively and in
## GDScript at each step, keeps the native answer and notes any difference.
class Staged:
	extends SinkStepper

	## A hair: what a made-up head, water or second is set off an edge by, either way.
	const HAIR := 1e-12
	## How many made-up states are tried at each step checked.
	const MADE_UP := 2

	var differences: Array[String] = []
	var asked := {&"shares": 0, &"stiff": 0, &"across": 0, &"failed": 0, &"gaps": 0}
	## What the checks came on: cells held, heads across that were not 0, openings that
	## gave way or leaked: what shows the states tried reach every branch.
	var came_on := {&"held": 0, &"across": 0, &"gave_way": 0, &"leaked": 0}
	var rng := RandomNumberGenerator.new()
	## Off until the window checked: before it, the native answer alone.
	var checking := false

	func _hold_stiff(
		state: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
	) -> PackedInt32Array:
		if checking:
			check_shares(state)
			check_stiff(state, heads, sea, seconds)
			# The step's own shares again, as it would have them.
			_shares_at = NAN
		return super._hold_stiff(state, heads, sea, seconds)

	func step(state: FloodState, seconds: float) -> FloodState:
		var next := super.step(state, seconds)
		if checking and _failures != null:
			check_failures(state, next)
		return next

	## Every opening's share open at the step's second, at each opening's shut time and a
	## hair either side, and with openings part open or given way.
	func check_shares(state: FloodState) -> void:
		var sinces := PackedFloat64Array([state.seconds, 0.0])
		for _try in 3:
			var time := _shut_time[rng.randi_range(0, _shut_time.size() - 1)]
			sinces.append(edged(PackedFloat64Array([time, absf(time), time * 0.5])))
		for since: float in sinces:
			var opened := _opened.duplicate()
			if rng.randf() < 0.5:
				for kind in 4:
					opened[rng.randi_range(0, opened.size() - 1)] = [0.5, 1.0, HAIR][kind % 3]
			var answer := _native.shares(since, opened)
			var reference := PackedFloat64Array()
			for index in _names.size():
				reference.append(SinkOpenings.open_share(_shut_time[index], since, opened[index]))
			asked[&"shares"] += 1
			if not alike(answer, reference):
				note("shares at %s seconds" % var_to_str(since))

	## The cells held stiff at the step's heads and at made-up ones: heads on the edges of
	## each cell's openings, water dry or full, some cells held already, the step longer
	## or shorter.
	func check_stiff(
		state: FloodState, heads: PackedFloat64Array, sea: float, seconds: float
	) -> void:
		var per_metre := _discharge * sqrt(2.0 * _g * STIFF_HEAD) * seconds
		# The step's shares, both sides', after check_shares tried others.
		_share_out(state.seconds)
		for cell in _boxes.size():
			if (_holding[cell] == 1) != _air.holds(cell):
				note("holding of cell %d is not SinkAir's" % cell)
		for trial in MADE_UP + 1:
			var tried := heads.duplicate()
			var twin := state.copy()
			var held := _held.duplicate()
			var metre := per_metre
			if trial > 0:
				made_up_heads(tried, sea)
				for kind in 3:
					var cell := rng.randi_range(0, _boxes.size() - 1)
					var full := _capacity[cell]
					twin.water[cell] = [0.0, full, full - HAIR * full, full * 0.5][kind]
				if rng.randf() < 0.3:
					held[rng.randi_range(0, held.size() - 1)] = 1
				metre *= rng.randf_range(0.1, 10.0)
			var answer := _native.stiff(tried, twin.water, held, _holding, sea, metre)
			var kept := _held
			_held = held.duplicate()
			var reference := _stiff(twin, tried, sea, metre)
			var marked := _held
			_held = kept
			asked[&"stiff"] += 1
			came_on[&"held"] += answer.size()
			for cell: int in answer:
				held[cell] = 1
			if answer != reference or held != marked:
				note("stiff cells of step %d: %s, not %s" % [state.steps, answer, reference])

	## Heads set on the edges of her openings and cells, a hair either side, or the sea.
	func made_up_heads(heads: PackedFloat64Array, sea: float) -> void:
		for _try in maxi(heads.size() / 3, 1):
			var cell := rng.randi_range(0, heads.size() - 1)
			var edges := PackedFloat64Array([_floor[cell], _ceiling[cell], heads[cell], sea])
			for index: int in _touching[cell]:
				edges.append(_bottom[index])
			heads[cell] = edged(edges)

	## Her failures at [param next], stepped from [param state] and turned to: the heads
	## across every watched opening, at it and at made-up heads; what gives way and leaks
	## at those and at made-up ones, from what stood open before or made-up openings,
	## at its second or one on a shut time; and the gaps at each.
	func check_failures(state: FloodState, next: FloodState) -> void:
		var failures := _failures
		var native := _native
		var watched := failures.watched()
		var states: Array[FloodState] = [next]
		for _try in MADE_UP:
			var twin := next.copy()
			made_up_heads(twin.heads, twin.sea)
			for kind in 2:
				var cell := rng.randi_range(0, twin.water.size() - 1)
				twin.water[cell] = [0.0, _capacity[cell]][kind]
			states.append(twin)
		var acrosses: Array[PackedFloat64Array] = []
		for at in states.size():
			var answer := native.across(states[at], _ceiling, _bottom, _air)
			_native = null
			failures._across_state = null
			var reference := failures._heads_across(states[at], self).duplicate()
			_native = native
			asked[&"across"] += 1
			for head: float in answer:
				came_on[&"across"] += 1 if head != 0.0 else 0
			if not alike(answer, reference):
				note("heads across at step %d, state %d" % [next.steps, at])
			acrosses.append(answer)
		# The memo as the step left it.
		failures._across_state = next
		failures._across = acrosses[0]
		var indices: PackedInt32Array = watched[0]
		if indices.is_empty():
			return
		for _try in MADE_UP:
			acrosses.append(made_up_across(watched))
		check_failing(state, next, acrosses, watched)
		# Her watched openings made harder, on both sides, then as they were.
		var layout := made_up_layout(watched)
		hand_over(layout)
		check_failing(state, next, acrosses + [made_up_across(layout)], layout)
		hand_over(watched)

	## What gives way and leaks at each of [param acrosses] past [param next], stepped
	## from [param state], from what stood open before or made-up openings, at its second
	## or one on a shut time, her watched openings [param watched]; and the gaps at each.
	func check_failing(
		state: FloodState, next: FloodState, acrosses: Array, watched: Array
	) -> void:
		var failures := _failures
		var native := _native
		for across: PackedFloat64Array in acrosses:
			var opened := state.opened.duplicate()
			var seconds := next.seconds
			if rng.randf() < 0.5:
				for kind in 4:
					var index: int = watched[0][rng.randi_range(0, watched[0].size() - 1)]
					opened[index] = [0.0, 1.0, 0.25, 0.0][kind]
			if rng.randf() < 0.5:
				var time: float = watched[3][rng.randi_range(0, watched[3].size() - 1)]
				seconds = edged(PackedFloat64Array([absf(time), 0.0]))
			var answer := native.failed(across, opened, seconds)
			var twin := next.copy()
			twin.opened = opened.duplicate()
			twin.seconds = seconds
			failures._fail(twin, across)
			asked[&"failed"] += 1
			for index in opened.size():
				if answer[index] != opened[index]:
					came_on[&"gave_way" if answer[index] == 1.0 else &"leaked"] += 1
			if not alike(answer, twin.opened):
				note("what gives way at step %d, %s seconds" % [next.steps, var_to_str(seconds)])
			asked[&"gaps"] += 1
			if not alike(native.failure_gaps(across), failures._opening_gaps(across)):
				note("failure gaps at step %d" % next.steps)

	## [param watched] (SinkFailures.watched) made harder: some openings that never give
	## way or never leak, that open toward either side or neither, whose leaks pass
	## nothing, or shut from the start, never or over half a minute.
	func made_up_layout(watched: Array) -> Array:
		var layout: Array = []
		for array: Variant in watched:
			layout.append(array.duplicate())
		for at in (layout[0] as PackedInt32Array).size():
			match rng.randi_range(0, 6):
				0:
					layout[5][at] = 0.0
				1:
					layout[4][at] = 0.0
				2:
					layout[7][at] = rng.randi_range(-1, 1)
				3:
					layout[6][at] = 0.0
				4:
					layout[3][at] = [-1.0, 0.0, 30.0][rng.randi_range(0, 2)]
		return layout

	## Hands [param watched] to her failures and the extension alike.
	func hand_over(watched: Array) -> void:
		_native.watched(watched)
		_failures._index = watched[0]
		_failures._first = watched[1]
		_failures._second = watched[2]
		_failures._shut_time = watched[3]
		_failures._leak = watched[4]
		_failures._collapse = watched[5]
		_failures._leak_share = watched[6]
		_failures._toward = watched[7]

	## Heads across each watched opening of [param watched] (SinkFailures.watched) on its
	## leak or collapse head, a hair either side, either sign, none or at random.
	func made_up_across(watched: Array) -> PackedFloat64Array:
		var across := PackedFloat64Array()
		for at in (watched[0] as PackedInt32Array).size():
			var leak: float = watched[4][at]
			var collapse: float = watched[5][at]
			var head := edged(PackedFloat64Array([leak, collapse, 0.0, rng.randf_range(0.0, 20.0)]))
			if at % 7 == 0:
				head = [0.0, -0.0, INF][at % 3]
			across.append(head if rng.randf() < 0.5 else -head)
		return across

	## One of [param edges], or a hair off it either way.
	func edged(edges: PackedFloat64Array) -> float:
		var edge := edges[rng.randi_range(0, edges.size() - 1)]
		match rng.randi_range(0, 3):
			0:
				return edge - HAIR
			1:
				return edge + HAIR
		return edge

	func note(what: String) -> void:
		if differences.size() < 12:
			differences.append(what)

	## Whether [param a] and [param b] are one float to the bit, or both not a number.
	static func same(a: float, b: float) -> bool:
		if is_nan(a) or is_nan(b):
			return is_nan(a) and is_nan(b)
		return var_to_bytes(a) == var_to_bytes(b)

	static func alike(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
		if a.size() != b.size():
			return false
		for at in a.size():
			if not same(a[at], b[at]):
				return false
		return true


func test_her_bakes_share_hold_and_fail_alike() -> void:
	if not _loaded():
		return
	var asked := {}
	var came_on := {}
	for ship: StringName in WINDOWS:
		var structure := Fleet.layout(ship).structure
		var scenario := Fleet.scenario(ship)
		var sea := SeaPhysics.load_default()
		var choosing := MustSink.Choosing.new(
			structure, scenario, SeedStreams.derive(SEED, "sink"), sea
		)
		choosing.work(1)
		var damage: HitDamage = choosing._drawn.damage
		var stepper := Staged.new(structure, damage, sea)
		stepper.rng.seed = 1411
		var bake := SinkBake.new(
			stepper, sea, scenario.bake_cap, HullBreak.of(structure, damage, sea)
		)
		var started := Time.get_ticks_msec()
		bake.run(WINDOWS[ship].x)
		var checked := Time.get_ticks_msec()
		stepper.checking = true
		bake.run(WINDOWS[ship].y)
		gut.p(
			(
				"%s: %s, came on %s, steps %d to %d (%d ms, then %d ms checked)"
				% [
					ship,
					stepper.asked,
					stepper.came_on,
					WINDOWS[ship].x,
					bake.steps(),
					checked - started,
					Time.get_ticks_msec() - checked
				]
			)
		)
		assert_eq(stepper.differences, [] as Array[String], "%s's stages alike" % ship)
		for kind: StringName in stepper.asked:
			asked[kind] = asked.get(kind, 0) + stepper.asked[kind]
		for kind: StringName in stepper.came_on:
			came_on[kind] = came_on.get(kind, 0) + stepper.came_on[kind]
	for kind: StringName in asked:
		assert_gt(asked[kind], 0, "her bakes ask for %s" % kind)
	for kind: StringName in came_on:
		assert_gt(came_on[kind], 0, "the states tried come on %s" % kind)


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeSink"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
