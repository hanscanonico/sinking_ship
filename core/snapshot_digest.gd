class_name SnapshotDigest
extends RefCounted
## A running hash of a match (D4): the snapshot quantized to 1 mm, 1 cm/s and
## 0.01°, folded in every RATE ticks and at the end. Same seed + same input log on
## the same build and platform ⇒ the same digest.

var _hash: String = ""


## Folds [param snapshot] in when its tick is on the digest's beat, or when
## [param final] says it is the match's last.
func add(snapshot: Dictionary, final: bool = false) -> void:
	if final or int(snapshot["tick"]) % Ticks.RATE == 0:
		_hash = (_hash + quantized(snapshot)).sha256_text()


func hex() -> String:
	return _hash


static func quantized(snapshot: Dictionary) -> String:
	var parts := PackedStringArray(
		[str(snapshot["tick"]), str(snapshot["phase"]), str(snapshot["rng"])]
	)
	for entry: Dictionary in snapshot["seats"]:
		var pos: Vector3 = entry["pos"]
		var vel: Vector3 = entry["vel"]
		var fields: Array = [
			entry["seat"],
			entry["state"],
			entry["place"],
			entry["out_tick"],
			entry["out_cause"],
			roundi(pos.x * 1000.0),
			roundi(pos.y * 1000.0),
			roundi(pos.z * 1000.0),
			roundi(vel.x * 100.0),
			roundi(vel.y * 100.0),
			roundi(vel.z * 100.0),
			roundi(rad_to_deg(entry["facing"]) * 100.0),
			entry["surface"],
			roundi(float(entry["fall_from"]) * 1000.0),
			entry["action"],
			entry["action_ticks"],
			int(entry["shove_spent"]),
			roundi(rad_to_deg(entry["shove_facing"]) * 100.0),
			entry["charge"],
			int(entry["bracing"]),
			roundi(float(entry["stamina"]) * 100.0),
			entry["stamina_wait"],
			int(entry["exhausted"]),
			entry["stagger"],
			entry["last_hit_by"],
			entry["prev_buttons"],
		]
		fields.append_array(entry["last_input"])
		var text := PackedStringArray()
		for field: Variant in fields:
			text.append(str(field))
		parts.append(",".join(text))
	return "|".join(parts)
