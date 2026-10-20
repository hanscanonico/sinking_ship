class_name ByteCursor
extends RefCounted
## A little-endian byte buffer written field by field, and read back the same way:
## whole numbers, a string, a Variant or a run of bytes. Reading past the end, or a
## field that does not decode, turns [member ok] off and answers a zero value, so a
## reader checks [member ok] once at the end and refuses the whole buffer — the shape of
## every file the match writes (InputLog, ReplayFile).

var ok := true
var _bytes: PackedByteArray
var _at := 0


func _init(bytes := PackedByteArray()) -> void:
	_bytes = bytes


func bytes() -> PackedByteArray:
	return _bytes


## Whether every byte has been read.
func at_end() -> bool:
	return _at == _bytes.size()


func put_s32(value: int) -> void:
	var at := _bytes.size()
	_bytes.resize(at + 4)
	_bytes.encode_s32(at, value)


func put_s64(value: int) -> void:
	var at := _bytes.size()
	_bytes.resize(at + 8)
	_bytes.encode_s64(at, value)


## The string's bytes, their length first.
func put_string(value: String) -> void:
	put_bytes(value.to_utf8_buffer())


## A length, then that many bytes.
func put_bytes(value: PackedByteArray) -> void:
	put_s32(value.size())
	_bytes.append_array(value)


## [param value] as var_to_bytes makes it (no objects), its length first.
func put_var(value: Variant) -> void:
	put_bytes(var_to_bytes(value))


func s32() -> int:
	if not _take(4):
		return 0
	return _bytes.decode_s32(_at - 4)


func s64() -> int:
	if not _take(8):
		return 0
	return _bytes.decode_s64(_at - 8)


func string() -> String:
	var encoded := bytes_next()
	return encoded.get_string_from_utf8() if ok else ""


## The next length-prefixed run of bytes.
func bytes_next() -> PackedByteArray:
	var count := s32()
	if not ok or count < 0 or not _take(count):
		ok = false
		return PackedByteArray()
	return _bytes.slice(_at - count, _at)


## The next length-prefixed Variant; null, and not ok, when it does not decode.
func variant() -> Variant:
	var encoded := bytes_next()
	if not ok:
		return null
	var decoded: Variant = bytes_to_var(encoded)
	if decoded == null:
		ok = false
	return decoded


## Exactly [param count] raw bytes.
func raw(count: int) -> PackedByteArray:
	if count < 0 or not _take(count):
		ok = false
		return PackedByteArray()
	return _bytes.slice(_at - count, _at)


func _take(count: int) -> bool:
	if not ok or _at + count > _bytes.size():
		ok = false
		return false
	_at += count
	return true
