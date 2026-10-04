class_name SecureDraws
extends Draws
## Draws from the system's CSPRNG (Crypto): nothing a client is shown tells it the next
## draw. Every server draws its room codes here, and its match seeds too unless --seed
## asks for a run that repeats. It fails closed: given fewer bytes than it asked for, it
## draws nothing (-1), and the server makes no room and starts no match on it.

## The draws a u32 holds.
const SPAN := 1 << 32

var _crypto := Crypto.new()


func below(count: int) -> int:
	# A draw past the last whole multiple of count is drawn again, or the low numbers
	# would come up more often than the high.
	var limit := SPAN - SPAN % count
	while true:
		var drawn := u32()
		if drawn < 0:
			return -1
		if drawn < limit:
			return drawn % count
	return -1


func u32() -> int:
	var bytes := _bytes(4)
	if bytes.size() < 4:
		push_error("SecureDraws: the CSPRNG gave %d of 4 bytes" % bytes.size())
		return -1
	return bytes.decode_u32(0)


func _bytes(count: int) -> PackedByteArray:
	return _crypto.generate_random_bytes(count)
