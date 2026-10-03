class_name MatchStats
extends RefCounted
## The results screen's numbers, built from the match's events and nothing else
## (D5): places and time dry from SEAT_OUT and MATCH_ENDED, shoves landed from
## SHOVE_LANDED, and knock-outs from the credit each SEAT_OUT carries.


class SeatStats:
	extends RefCounted

	var seat: int
	## 0 until the seat is out or the match has ended.
	var place: int
	## Ticks from the start of the brawl to going out or to the end; -1 while still
	## dry in a match that has not ended.
	var dry_ticks: int = -1
	## One per shove that hit, however many bodies it hit.
	var shoves_landed: int
	## Seats out with this one's shove as their credit.
	var knockouts: int

	func _init(seat_id: int) -> void:
		seat = seat_id

	func to_dict() -> Dictionary:
		return {
			"seat": seat,
			"place": place,
			"dry_ticks": dry_ticks,
			"shoves_landed": shoves_landed,
			"knockouts": knockouts,
		}


var seats: Array[SeatStats] = []
var ended: bool
## The last seat dry once the match has ended; -1 before then, or for a draw.
var winner: int = -1

## The tick the brawl starts on, after the countdown: time dry counts from here.
var _live_from: int
## Each seat's last tick with a landed shove, so a shove hitting two bodies counts
## once.
var _landed_at := PackedInt32Array()


func _init(seat_count: int, live_from_tick: int) -> void:
	_live_from = live_from_tick
	for seat in seat_count:
		seats.append(SeatStats.new(seat))
	_landed_at.resize(seat_count)
	_landed_at.fill(-1)


func add(events: Array[SimEvent]) -> void:
	for event: SimEvent in events:
		match event.kind:
			SimEvent.Kind.SHOVE_LANDED:
				if _landed_at[event.seat] != event.tick:
					_landed_at[event.seat] = event.tick
					seats[event.seat].shoves_landed += 1
			SimEvent.Kind.SEAT_OUT:
				var out := seats[event.seat]
				out.place = event.place
				out.dry_ticks = _dry_until(event.tick)
				if event.credit != -1:
					seats[event.credit].knockouts += 1
			SimEvent.Kind.MATCH_ENDED:
				ended = true
				winner = event.seat
				if winner != -1:
					seats[winner].place = event.place
					seats[winner].dry_ticks = _dry_until(event.tick)


## The seat among [param candidates] doing best so far: the most knock-outs
## credited, then the most shoves landed, then the lowest seat id; -1 when there
## are none.
func best_of(candidates: Array[int]) -> int:
	var best := -1
	for seat: int in candidates:
		if best == -1 or _ahead(seats[seat], seats[best]):
			best = seat
	return best


## Every seat, best place first; seats still without a place come last, in seat
## order.
func standings() -> Array[SeatStats]:
	var ranked: Array[SeatStats] = seats.duplicate()
	ranked.sort_custom(_placed_before)
	return ranked


func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for line: SeatStats in seats:
		entries.append(line.to_dict())
	return {"ended": ended, "winner": winner, "seats": entries}


func _dry_until(tick: int) -> int:
	return maxi(tick - _live_from, 0)


static func _ahead(a: SeatStats, b: SeatStats) -> bool:
	if a.knockouts != b.knockouts:
		return a.knockouts > b.knockouts
	if a.shoves_landed != b.shoves_landed:
		return a.shoves_landed > b.shoves_landed
	return a.seat < b.seat


static func _placed_before(a: SeatStats, b: SeatStats) -> bool:
	if (a.place == 0) != (b.place == 0):
		return b.place == 0
	if a.place != b.place:
		return a.place < b.place
	return a.seat < b.seat
