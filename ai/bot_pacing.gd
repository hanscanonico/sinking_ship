class_name BotPacing
extends RefCounted
## How hard a bot fights, as its last think found the match (SH7d, R3). Early on, the
## ship level, it spars (BotProfile.spar_margin): the margin fades as the ship's
## platforms go under and as the match goes on from going live. Late in the sinking it
## presses, by late_hunt_gain times the share under. Down to the last hunt_at_seats
## seats left — as the HUD counts them for every player — it hunts them: no spar margin
## and the hunt and line-up pressed as hard as late in the sinking. Under survival
## (#61) only the sinking paces it: a match that plays to her end is not hurried along,
## so neither the clock nor the seats left take its spar margin away — and while it
## spars, the margin is a shove's whole carry more: a seat sent over is a life, not
## position, when outliving them is the game.

## What the hunt and line-up scores are multiplied by: 1 with every deck dry, more the
## more are under, the most when hunting the last seats.
var pressing := 1.0
## How far from the water, an open drop or a railing it keeps whoever it shoves; none
## once it fights to the death.
var spar := 0.0

var _profile: BotProfile
var _plays_for: MatchRules.Goal
## How far a shove carries an unbraced body on a level deck (BotTargeting.carry).
var _carry: float
## The tick of the first snapshot its view showed the match live on, or -1 before.
var _live_from := -1


## [param plays_for] is what the match is played for (MatchRules.Goal); [param carry]
## how far a shove carries an unbraced body on a level deck.
func _init(profile: BotProfile, plays_for := MatchRules.Goal.LAST_STANDING, carry := 0.0) -> void:
	_profile = profile
	_plays_for = plays_for
	_carry = carry


## Paces the bot for [param seen], the snapshot its view shows, with the share
## [param under] of the ship's platforms under water and [param seats_left] seats
## left in the match.
func pace(seen: Dictionary, under: float, seats_left: int) -> void:
	var tick: int = seen["tick"]
	if _live_from < 0 and seen["phase"] != MatchState.Phase.COUNTDOWN:
		_live_from = tick
	if _plays_for == MatchRules.Goal.SURVIVAL:
		pressing = 1.0 + _profile.late_hunt_gain * under
		var margin := _profile.spar_margin(under, 0.0)
		spar = margin + _carry if margin > 0.0 else 0.0
		return
	if seats_left <= _profile.hunt_at_seats:
		pressing = 1.0 + _profile.late_hunt_gain
		spar = 0.0
		return
	pressing = 1.0 + _profile.late_hunt_gain * under
	var live_s := Ticks.to_seconds(tick - _live_from) if _live_from >= 0 else 0.0
	spar = _profile.spar_margin(under, live_s)
