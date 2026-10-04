class_name SecureDraws
extends Draws
## Draws from the system's CSPRNG (Crypto): nothing a client is shown tells it the next
## draw. Every server draws its room codes here, and its match seeds too unless --seed
## asks for a run that repeats.

## The draws a u32 holds.
const SPAN := 1 << 32

var _crypto := Crypto.new()


func below(count: int) -> int:
	# A draw past the last whole multiple of count is drawn again, or the low numbers
	# would come up more often than the high.
	var limit := SPAN - SPAN % count
	while true:
		var drawn := u32()
		if drawn < limit:
			return drawn % count
	return 0


func u32() -> int:
	return _crypto.generate_random_bytes(4).decode_u32(0)
