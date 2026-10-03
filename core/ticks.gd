class_name Ticks
extends RefCounted
## The sim's only clock (D2): a duration is a count of ticks at a fixed 30 Hz.
##
## Data is authored in seconds and converted here, once per match — the single
## conversion authority. RATE is code, not tuning: changing it moves every timing,
## the wire format and the golden.

const RATE := 30
const SECONDS_PER_TICK := 1.0 / RATE


## Rounds half away from zero, so 0.25 s is 8 ticks and -0.25 s is -8.
static func from_seconds(seconds: float) -> int:
	return int(roundf(seconds * RATE))


static func to_seconds(ticks: int) -> float:
	return float(ticks) / RATE
