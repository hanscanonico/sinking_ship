extends GutTest
## The wire format (D11): input packets that repeat their frames, snapshots
## quantized to the stated quanta, the protocol version and the data hash on every
## packet, and seats listed by id.

const SEED := 11
## What a Vector3's single precision may add to a quantum's rounding, at 50 m.
const VECTOR_ROUNDING := 4e-6

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = SEED


func _codec(config: MatchConfig = null) -> WireCodec:
	return WireCodec.new((config if config != null else _config()).data_hash())


## Three seats on the steamer: crates, railings and every seat field there is.
func _config() -> MatchConfig:
	return SimFixtures.config(3, null, 1, SimFixtures.steamer())


## A snapshot of [param config]'s match carrying an event of every shape, with every
## number in it, however deep, replaced by a roll of the same type.
func _scrambled(config: MatchConfig) -> Dictionary:
	var snapshot := MatchSim.create(config).snapshot()
	var collapse := SimFixtures.collapse(4.0, &"bridge")
	snapshot["events"] = [
		SimEvent.sinking(9, collapse, true).to_dict(),
		SimEvent.seat_out(9, 1, 3, PlayerState.Cause.COLD, 2, 0).to_dict(),
	]
	assert_false(snapshot["props"].is_empty(), "the steamer carries crates")
	assert_false(snapshot["railing_hp"].is_empty(), "and railings")
	return _scramble(snapshot)


func _scramble(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL:
			return _rng.randf() < 0.5
		TYPE_INT:
			# Any 64-bit int, the rng's state and the match seed among them.
			return (_rng.randi() << 32) | _rng.randi()
		TYPE_FLOAT:
			return _rng.randf_range(-50.0, 50.0)
		TYPE_VECTOR3:
			return Vector3(_scramble(0.0), _scramble(0.0), _scramble(0.0))
		TYPE_STRING_NAME:
			return StringName("deck_%d" % _rng.randi_range(0, 99))
	return _scramble_each(value)


## [param value]'s items scrambled, when it holds any.
func _scramble_each(value: Variant) -> Variant:
	if value is PackedFloat64Array:
		var amounts := PackedFloat64Array()
		for _amount: float in value:
			amounts.append(_scramble(0.0))
		return amounts
	if value is Array:
		var items: Array = (value as Array).duplicate()
		for index in items.size():
			items[index] = _scramble(items[index])
		return items
	if value is Dictionary:
		var record: Dictionary = (value as Dictionary).duplicate()
		for key: String in record:
			record[key] = _scramble(record[key])
		return record
	return value


## Every key of [param sent], however deep, as [param received] has it: there, and
## within half its quantum. Names what is not.
func _within_quantum(
	sent: Dictionary, received: Dictionary, section: StringName, path: String
) -> void:
	for key: String in sent:
		var where := "%s.%s" % [path, key]
		if not received.has(key):
			fail_test("%s lost on the wire" % where)
			continue
		var quantum := WireCodec.quantum(section, key)
		assert_true(quantum >= 0.0, "%s is in the codec's tables" % where)
		var value: Variant = sent[key]
		var back: Variant = received[key]
		match typeof(value):
			TYPE_ARRAY when key in ["seats", "props", "events"]:
				assert_eq((back as Array).size(), (value as Array).size(), where)
				for index in mini((back as Array).size(), (value as Array).size()):
					_within_quantum(value[index], back[index], key, "%s[%d]" % [where, index])
			TYPE_FLOAT, TYPE_VECTOR3, TYPE_PACKED_FLOAT64_ARRAY:
				var off := _farthest(value, back)
				assert_true(off <= quantum * 0.5 + VECTOR_ROUNDING, "%s off by %s" % [where, off])
			_:
				assert_eq(back, value, where)
	assert_eq(received.size(), sent.size(), "%s carries what was sent and nothing else" % path)


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


func test_snapshot_round_trip_within_quantum() -> void:
	assert_eq(WireCodec.quantum(&"seats", "pos"), 0.001, "1 mm")
	assert_eq(WireCodec.quantum(&"seats", "vel"), 0.01, "1 cm/s")
	assert_almost_eq(WireCodec.quantum(&"seats", "facing"), deg_to_rad(0.01), 1e-12, "0.01°")
	assert_eq(WireCodec.quantum(&"props", "pos"), 0.001, "a crate's 1 mm")
	var config := _config()
	var codec := _codec(config)
	for _round in 5:
		var sent := _scrambled(config)
		var packet := codec.decode_snapshot(codec.encode_snapshot(sent, 41, 44, 2))
		assert_not_null(packet, "the snapshot decodes")
		if packet == null:
			return
		assert_eq([packet.ack, packet.heard, packet.early], [41, 44, 2], "the client's ack")
		_within_quantum(sent, packet.snapshot, &"snapshot", "snapshot")
	# A match carried on the wire continues as the sim would from where it is.
	var sim := MatchSim.create(config)
	var carried := codec.decode_snapshot(codec.encode_snapshot(sim.snapshot(), -1, -1, 0))
	var resumed := MatchSim.from_snapshot(carried.snapshot, config)
	assert_eq(resumed.state.tick, sim.state.tick)
	assert_eq(resumed.state.rng.state, sim.state.rng.state, "the match stream exactly")


func test_a_field_the_codec_forgets_is_lost_loudly() -> void:
	var config := _config()
	var codec := _codec(config)
	var sent := MatchSim.create(config).snapshot()
	var seat: Dictionary = sent["seats"][1]
	seat["grudge"] = 3
	var bytes := codec.encode_snapshot(sent, -1, -1, 0)
	assert_push_error("wire:", "the codec says so as it encodes")
	var received: Dictionary = codec.decode_snapshot(bytes).snapshot["seats"][1]
	assert_false(received.has("grudge"), "and the field never arrives")


func test_input_redundancy_recovers_a_lost_packet() -> void:
	var codec := _codec()
	var played: Array[InputFrame] = []
	for tick in range(20, 30):
		var stick := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		var look := _rng.randi_range(0, InputFrame.YAW_STEPS - 1)
		var buttons := _rng.randi_range(0, 7)
		played.append(InputFrame.new(0, tick, InputFrame.quantize(stick), buttons, look))
	var redundancy := NetRules.load_default().input_redundancy
	assert_gt(redundancy, 1, "each packet repeats frames")
	# One packet per tick, each with the last frames; the one sent at tick 25 is lost.
	var heard := {}
	for newest in range(redundancy - 1, played.size()):
		var frames := played.slice(newest - redundancy + 1, newest + 1)
		var bytes := codec.encode_inputs(frames)
		if played[newest].tick == 25:
			continue
		for frame: InputFrame in codec.decode_inputs(bytes, 2):
			heard[frame.tick] = frame
	for frame: InputFrame in played.slice(redundancy - 1):
		var got: InputFrame = heard.get(frame.tick)
		assert_not_null(got, "tick %d is heard" % frame.tick)
		if got == null:
			continue
		assert_eq(got.seat, 2, "for the seat the host reads it as")
		assert_eq(
			[got.move, got.look_yaw, got.buttons],
			[frame.move, frame.look_yaw, frame.buttons],
			"tick %d exactly" % frame.tick
		)


func test_version_and_data_hash_are_carried() -> void:
	var config := _config()
	var codec := _codec(config)
	var frames: Array[InputFrame] = [InputFrame.new(0, 5, Vector2i(3, -4), 1, 900)]
	var inputs := codec.encode_inputs(frames)
	var snapshot := codec.encode_snapshot(MatchSim.create(config).snapshot(), 4, 5, 1)
	assert_eq(inputs[0], WireCodec.PROTOCOL_VERSION, "the version opens a packet")
	assert_eq(snapshot[0], WireCodec.PROTOCOL_VERSION)
	assert_eq(codec.kind_of(inputs), WireCodec.Kind.INPUT)
	assert_eq(codec.kind_of(snapshot), WireCodec.Kind.SNAPSHOT)
	assert_eq(codec.decode_inputs(inputs, 0).size(), 1)
	assert_not_null(codec.decode_snapshot(snapshot))

	var changed := _config()
	changed.rules = changed.rules.duplicate()
	changed.rules.knockback += 1.0
	var other := _codec(changed)
	assert_eq(other.kind_of(inputs), -1, "another match's data is refused")
	assert_eq(other.decode_inputs(inputs, 0).size(), 0)
	assert_null(other.decode_snapshot(snapshot))

	for packet: PackedByteArray in [inputs, snapshot]:
		var newer := packet.duplicate()
		newer[0] = WireCodec.PROTOCOL_VERSION + 1
		assert_eq(codec.kind_of(newer), -1, "another protocol is refused")
	var short := snapshot.slice(0, snapshot.size() - 3)
	assert_null(codec.decode_snapshot(short), "and so is a packet cut short")


func test_partial_seat_list_round_trips() -> void:
	var config := SimFixtures.config(6, null, 1, SimFixtures.steamer())
	var codec := _codec(config)
	var sent := _scramble(MatchSim.create(config).snapshot()) as Dictionary
	var some: Array[Dictionary] = []
	for entry: Dictionary in sent["seats"]:
		some.append(entry)
	some = [some[4], some[1], some[5]]
	some[0]["seat"] = 4
	some[1]["seat"] = 1
	some[2]["seat"] = 5
	sent["seats"] = some
	var received := codec.decode_snapshot(codec.encode_snapshot(sent, -1, -1, 0)).snapshot
	var ids: Array[int] = []
	for entry: Dictionary in received["seats"]:
		ids.append(entry["seat"])
	assert_eq(ids, [4, 1, 5] as Array[int], "the seats it lists, by id, in its order")
	_within_quantum(sent, received, &"snapshot", "snapshot")
