class_name SessionTally
extends RefCounted
## Points by place summed over a session of matches against bots: one match and the
## rematches pressed after it with the same seats (Game). Going back to the menu, or a
## match of another seat count, starts a new session. Fed from a live match's
## MatchStats as its results first show (MatchScene) — never from a replay — and read
## by the results alone (EndOverlay): it never enters the sim, its digest, transcripts
## or replays (D4, D5). Local only: online, the results lead back to the room.


## A name's standing in the session.
class Line:
	extends RefCounted

	var name: String
	var points: int
	## 1 for the most points; names level on points share a rank (1, 1, 3).
	var rank: int

	func _init(seat_name: String, total: int, place: int) -> void:
		name = seat_name
		points = total
		rank = place


var points: SessionPoints
## The matches counted this session.
var matches: int

var _seats: int
## Each name's points this session, and the names in the order first counted: a tie on
## points stands in that order.
var _totals: Dictionary[String, int] = {}
var _names := PackedStringArray()


func _init(table: SessionPoints = null) -> void:
	points = table if table != null else SessionPoints.load_default()


## A match of [param seats] is starting: a [param rematch] of the last one carries the
## session on, as long as its seats are the same; anything else starts a new one.
func begin(seats: int, rematch: bool) -> void:
	if not rematch or seats != _seats:
		reset()
	_seats = seats


func reset() -> void:
	matches = 0
	_seats = 0
	_totals.clear()
	_names.clear()


## Adds [param stats]' places, once it has ended, to the names [param names] gives its
## seats. A match of another seat count than the session's starts a new session.
func count(stats: MatchStats, names: PackedStringArray) -> void:
	if not stats.ended:
		return
	var seats := stats.seats.size()
	if seats != _seats:
		reset()
		_seats = seats
	matches += 1
	for line: MatchStats.SeatStats in stats.seats:
		var seat_name := names[line.seat]
		if not _totals.has(seat_name):
			_totals[seat_name] = 0
			_names.append(seat_name)
		_totals[seat_name] += points.for_place(line.place, seats)


## Every name counted, most points first.
func standings() -> Array[Line]:
	var ordered: Array[String] = []
	ordered.assign(_names)
	ordered.sort_custom(_ahead)
	var lines: Array[Line] = []
	for at in ordered.size():
		var seat_name := ordered[at]
		var rank := at + 1
		if at > 0 and _totals[seat_name] == lines[at - 1].points:
			rank = lines[at - 1].rank
		lines.append(Line.new(seat_name, _totals[seat_name], rank))
	return lines


func _ahead(a: String, b: String) -> bool:
	if _totals[a] != _totals[b]:
		return _totals[a] > _totals[b]
	return _names.find(a) < _names.find(b)
