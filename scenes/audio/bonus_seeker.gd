class_name BonusSeeker
extends RefCounted
## The finder's ping (#307): a metal detector's, toward the bonus aboard nearest the
## listening seat, coming faster and a little higher the closer its feet are to where that
## bonus lies, so a bonus is found by walking toward the ping. Which bonus it seeks reads a
## snapshot and the layout's bonus spots alone (D5); when the next ping falls is paced by
## the frames' seconds given it (MatchAudio), presentation only, never the sim's.

## Metres from the listener's feet to the bonus's spot past which nothing pings.
const RANGE := 30.0
## Within this many metres the ping comes at its quickest and highest.
const CLOSE := 1.5
## Seconds between pings at the range's edge, and within CLOSE.
const SLOWEST := 1.4
const QUICKEST := 0.18
## The ping's pitch at the range's edge, and within CLOSE.
const LOWEST := 1.0
const HIGHEST := 1.3

## Seconds until the next ping. Kept while nothing is sought, so a ping train coming back,
## or turning to another bonus, carries on rather than bursting.
var _until := 0.0


## The index into [param snapshot]'s bonuses of the one nearest [param seat]'s feet —
## in a straight line, ship space, to where it lies in [param layout] — and within RANGE;
## -1 when there is none, no seat listens (-1), or the seat is out.
static func sought(snapshot: Dictionary, layout: ShipLayout, seat: int) -> int:
	var seats: Array = snapshot["seats"]
	if seat < 0 or seat >= seats.size() or seats[seat]["out"]:
		return -1
	var feet: Vector3 = seats[seat]["pos"]
	var best := -1
	var nearest := RANGE
	var bonuses: Array = snapshot["bonuses"]
	for index in bonuses.size():
		var gap := feet.distance_to(layout.bonus_spots[bonuses[index]["spot"]].point)
		if gap <= nearest:
			best = index
			nearest = gap
	return best


## How near [param distance] metres is, 0 at RANGE and beyond, 1 within CLOSE.
static func closeness(distance: float) -> float:
	return clampf((RANGE - distance) / (RANGE - CLOSE), 0.0, 1.0)


## Seconds between pings with the bonus [param distance] metres off: evenly quicker as
## it nears.
static func interval(distance: float) -> float:
	return lerpf(SLOWEST, QUICKEST, closeness(distance))


## The ping's pitch with the bonus [param distance] metres off.
static func pitch(distance: float) -> float:
	return lerpf(LOWEST, HIGHEST, closeness(distance))


## Whether a ping sounds this frame, [param delta] seconds on, the bonus sought
## [param distance] metres off — INF for none sought, when nothing pings and the wait
## left is kept. The wait left is never longer than the interval now, so a ping train
## quickens at once as the bonus nears, without two pings in one frame.
func ping(delta: float, distance: float) -> bool:
	if distance > RANGE:
		return false
	var every := interval(distance)
	_until = minf(_until, every) - delta
	if _until > 0.0:
		return false
	_until += every
	if _until <= 0.0:
		_until = every
	return true
