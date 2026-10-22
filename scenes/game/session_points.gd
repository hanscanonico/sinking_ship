class_name SessionPoints
extends Resource
## What each place in a match is worth to the session's tally (SessionTally), from
## data/match/session_points.tres. Only the results screen reads it: no match, digest,
## transcript or replay does (D4, D5).

const PATH := "res://data/match/session_points.tres"

## Points by place, 1st first, for a match of as many seats as it has entries.
@export var by_place := PackedInt32Array()


static func load_default() -> SessionPoints:
	return load(PATH)


## What [param place] of [param seats] is worth. A match of other than the table's seats
## spreads its places over the table, 1st always worth its first entry and last its
## last: 1st of 4 is worth 10, 2nd 5, 3rd 2 and 4th nothing on the default table. A seat
## never placed (0) is worth nothing.
func for_place(place: int, seats: int) -> int:
	if by_place.is_empty() or place < 1 or place > seats:
		return 0
	if seats == 1:
		return by_place[0]
	var last := by_place.size() - 1
	return by_place[roundi(float((place - 1) * last) / float(seats - 1))]


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if by_place.is_empty():
		found.append("session: by_place needs at least one place")
	for at in by_place.size():
		if by_place[at] < 0:
			found.append("session: by_place must not be negative")
			break
		if at > 0 and by_place[at] > by_place[at - 1]:
			found.append("session: a place must not be worth more than the one above it")
			break
	return found
