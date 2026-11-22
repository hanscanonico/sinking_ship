class_name ReplayEyes
extends SpectateOrder
## Whose eyes a replay is seen through (R5): the seat chosen — the recorded one at first,
## then whichever Q / E or the d-pad cycles to, at any moment, as nobody plays — while
## that seat is in the match as the replay stands; once it is out, a seat still in, as a
## live match's view moves on (SpectateOrder): a seat out of the match is drawn nowhere,
## and eyes left in it looked from wherever its body last was, its spawn after a seek.
## Sought back before it went out, the view is the chosen seat's again.


## Moves to the next seat still in the match by seat id ([param step] 1) or the previous
## (-1), and chooses it: a replay's eyes cycle while the seat chosen is dry too.
func cycle(snapshot: Dictionary, step: int) -> void:
	var dry := _dry(snapshot)
	if dry.is_empty():
		return
	_local = dry[posmod(dry.find(target(snapshot)) + step, dry.size())]
	_picked = -1


## The same choice of seat over [param stats]: a seek's, which counts the match again.
func again(stats: MatchStats) -> ReplayEyes:
	return ReplayEyes.new(_local, stats)
