extends GutTest
## Every snapshot record declares its persisted fields once, in FIELDS (SnapshotField):
## its to_dict() carries exactly those keys in that order, from_dict() takes every one
## back, and the wire carries every one within its kind's quantum (D5, D11).

const SEED := 71
## Fields with no variable of their own: the format version, a seat's derived out and
## its last input, spread over four variables.
const COMPOSITE := ["v", "out", "last_input"]
## What a Vector3's single precision may add to a quantum's rounding, at 50 m.
const VECTOR_ROUNDING := 4e-6

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = SEED


## Each record's table, a snapshot entry of it filled with values off every quantum,
## and that entry as the record takes it back and gives it again.
func _records() -> Array:
	var seat := _filled(PlayerState.FIELDS)
	var prop := _filled(PropState.FIELDS)
	var event := _filled(SimEvent.FIELDS)
	var snapshot := _filled(MatchState.FIELDS)
	snapshot["events"] = []
	return [
		["MatchState", MatchState.FIELDS, snapshot, _again_match(snapshot)],
		["PlayerState", PlayerState.FIELDS, seat, PlayerState.from_dict(seat).to_dict()],
		["PropState", PropState.FIELDS, prop, PropState.from_dict(prop).to_dict()],
		["SimEvent", SimEvent.FIELDS, event, SimEvent.from_dict(event).to_dict()],
	]


func _again_match(snapshot: Dictionary) -> Dictionary:
	return MatchState.from_dict(snapshot).to_dict(snapshot["v"])


## A record of [param fields] with every field set to a roll of its kind.
func _filled(fields: Array) -> Dictionary:
	var record := {}
	for row: Dictionary in fields:
		record[SnapshotField.key_of(row)] = _roll(row)
	if record.has("out"):
		record["out"] = record["state"] == PlayerState.Body.OUT
	return record


func _roll(row: Dictionary) -> Variant:
	var rolled: Variant = _float()
	match row["kind"] as SnapshotField.Kind:
		SnapshotField.Kind.INT:
			rolled = _rng.randi_range(2, 3) if SnapshotField.key_of(row) == "state" else _int()
		SnapshotField.Kind.BOOL:
			rolled = true
		SnapshotField.Kind.LENGTHS, SnapshotField.Kind.SPEEDS:
			rolled = Vector3(_float(), _float(), _float())
		SnapshotField.Kind.AMOUNTS:
			rolled = PackedFloat64Array([_float(), _float(), _float()])
		SnapshotField.Kind.NAME:
			rolled = StringName("deck_%d" % _rng.randi_range(0, 99))
		SnapshotField.Kind.INTS:
			rolled = [_rng.randi_range(-9, 9), _rng.randi_range(0, 99), _rng.randi_range(0, 7), 3]
		SnapshotField.Kind.RECORDS:
			rolled = [_filled(row["fields"]), _filled(row["fields"])]
	return rolled


## Any 64-bit int, the rng's state and the match seed among them.
func _int() -> int:
	return (_rng.randi() << 32) | _rng.randi()


func _float() -> float:
	return _rng.randf_range(-50.0, 50.0)


func test_every_kind_has_its_quantum() -> void:
	assert_eq(SnapshotField.quantum(SnapshotField.Kind.LENGTH), 0.001, "1 mm")
	assert_eq(SnapshotField.quantum(SnapshotField.Kind.LENGTHS), 0.001, "1 mm a side")
	assert_eq(SnapshotField.quantum(SnapshotField.Kind.SPEEDS), 0.01, "1 cm/s")
	assert_almost_eq(
		SnapshotField.quantum(SnapshotField.Kind.ANGLE), deg_to_rad(0.01), 1e-12, "0.01°"
	)
	assert_eq(SnapshotField.quantum(SnapshotField.Kind.DEGREES), 0.01, "0.01°")
	assert_eq(SnapshotField.quantum(SnapshotField.Kind.AMOUNT), 0.001)
	assert_eq(SnapshotField.quantum(SnapshotField.Kind.AMOUNTS), 0.001)
	for kind: SnapshotField.Kind in [
		SnapshotField.Kind.INT,
		SnapshotField.Kind.BOOL,
		SnapshotField.Kind.NAME,
		SnapshotField.Kind.INTS,
		SnapshotField.Kind.RECORDS,
	]:
		assert_eq(SnapshotField.quantum(kind), 0.0, "%s exactly" % kind)


func test_to_dict_carries_the_table() -> void:
	var sim := SimFixtures.sim(3, null, SimFixtures.steamer())
	SimFixtures.step(sim, {}, 3)
	var state := sim.state
	state.events = [SimEvent.crate_hit(2, 1, 0)]
	var made: Array = [
		["MatchState", MatchState.FIELDS, state.to_dict(MatchSim.SNAPSHOT_VERSION), state],
		["PlayerState", PlayerState.FIELDS, state.seats[0].to_dict(), state.seats[0]],
		["PropState", PropState.FIELDS, state.props[0].to_dict(), state.props[0]],
		["SimEvent", SimEvent.FIELDS, state.events[0].to_dict(), state.events[0]],
	]
	for record: Array in made:
		var keys: Array = []
		for row: Dictionary in record[1]:
			keys.append(SnapshotField.key_of(row))
			var name: String = row["name"]
			assert_true(
				name in COMPOSITE or name in record[3],
				"%s.%s is a variable of the record" % [record[0], name]
			)
		assert_eq((record[2] as Dictionary).keys(), keys, "%s: to_dict() is FIELDS" % record[0])


func test_from_dict_takes_back_to_dict() -> void:
	for record: Array in _records():
		assert_eq(record[3], record[2], "%s round-trips" % record[0])


func test_a_state_taken_back_leaves_the_last_tick_s_events() -> void:
	var snapshot := _filled(MatchState.FIELDS)
	assert_eq(MatchState.from_dict(snapshot).events.size(), 0, "a report of a tick, not state")


func test_the_wire_carries_every_field_within_its_quantum() -> void:
	var snapshot := _filled(MatchState.FIELDS)
	var codec := WireCodec.new("71".repeat(32))
	var packet := codec.decode_snapshot(codec.encode_snapshot(snapshot, 1, 2, 3))
	assert_not_null(packet, "the snapshot decodes")
	if packet != null:
		_within_quantum(MatchState.FIELDS, snapshot, packet.snapshot, "snapshot")


func _within_quantum(fields: Array, sent: Dictionary, back: Dictionary, path: String) -> void:
	assert_eq(back.keys(), sent.keys(), "%s carries its table's keys" % path)
	for row: Dictionary in fields:
		var key := SnapshotField.key_of(row)
		var where := "%s.%s" % [path, key]
		var quantum := SnapshotField.quantum(row["kind"])
		if row["kind"] == SnapshotField.Kind.RECORDS:
			assert_eq((back[key] as Array).size(), (sent[key] as Array).size(), where)
			for index in mini((back[key] as Array).size(), (sent[key] as Array).size()):
				_within_quantum(
					row["fields"], sent[key][index], back[key][index], "%s[%d]" % [where, index]
				)
		elif quantum == 0.0:
			assert_eq(back[key], sent[key], where)
		else:
			var off := _farthest(sent[key], back[key])
			assert_true(off <= quantum * 0.5 + VECTOR_ROUNDING, "%s off by %s" % [where, off])


func _farthest(sent: Variant, received: Variant) -> float:
	match typeof(sent):
		TYPE_VECTOR3:
			var off: Vector3 = (sent as Vector3) - (received as Vector3)
			return maxf(absf(off.x), maxf(absf(off.y), absf(off.z)))
		TYPE_PACKED_FLOAT64_ARRAY:
			var amounts: PackedFloat64Array = sent
			var back: PackedFloat64Array = received
			if back.size() != amounts.size():
				return INF
			var most := 0.0
			for index in amounts.size():
				most = maxf(most, absf(amounts[index] - back[index]))
			return most
	return absf(float(sent) - float(received))
