class_name ReplayListing
extends RefCounted
## What a list of saved replays says of each one (R6, #214), read off the file's
## summary — its ship, seed, seats, length and who won — and why one can no longer be
## played. Node-free: the menu only lays the words out, and dates them itself.

const MIDWAY := "started mid-way, which no replay can rebuild"
const CHANGED := "the match data has changed since"
const UNREADABLE := "not a replay the game can read"


## The words for [param file]: its ship, seed, seats, length as a clock and who won,
## and — when [param reason] says why it cannot be played — that reason, else "".
static func row(file: ReplayFile, reason: String = "") -> Dictionary:
	return {
		"ship": String(file.ship).capitalize(),
		"seed": "Seed %d" % file.match_seed,
		"seats": seats_text(file.seats) % file.seats,
		"length": MatchTranscript.clock(file.ticks),
		"winner": winner_text(file.winner, file.ended, file.choices.watch),
		"reason": reason,
	}


## Who won: the local seat is "you", the rest bots by their number (bot_number); the
## sea when the match ended with nobody dry; nobody yet when it was left before its
## end. In a match only [param watched] no seat is "you".
static func winner_text(winner: int, ended: bool, watched := false) -> String:
	if not ended:
		return "Left unfinished"
	if winner < 0:
		return "The sea won"
	var bot := bot_number(winner, watched)
	return "You won" if bot == 0 else "Bot %d won" % bot


## The number the bot on [param seat] goes by, as the match named it: its seat after
## the local one, and in a match only [param watched] Bot 1 on from the first seat.
## 0 for the local seat, which is no bot.
static func bot_number(seat: int, watched: bool) -> int:
	return seat + 1 if watched else seat


## The words for [param seats] seats, the count still to be put in.
static func seats_text(seats: int) -> String:
	return "%d seat" if seats == 1 else "%d seats"


## Why [param file] cannot be played under [param match_rules], or "" when it can.
static func reason(file: ReplayFile, match_rules: MatchRules) -> String:
	if file == null or file.log == null or file.choices == null:
		return UNREADABLE
	if file.log.first_tick != 0:
		return MIDWAY
	if not file.playable(match_rules):
		return CHANGED
	return ""
