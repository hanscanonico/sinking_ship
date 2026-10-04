class_name RoomRoster
extends RefCounted
## A room as the players in it see it (SH12): its code, whether its match is on, and
## its players in seat order — the first the room's host, and any whose client has
## gone mid-match played by a bot. What a menu shows; the server sends one to each
## player whenever it changes.


## One player of the room.
class Player:
	extends RefCounted
	var name: String
	## Whether this player starts the match.
	var host: bool
	## Whether this player's client has gone and a bot plays the seat.
	var bot: bool

	func _init(display_name: String, is_host: bool, is_bot: bool) -> void:
		name = display_name
		host = is_host
		bot = is_bot


var code := ""
var playing := false
var players: Array[Player] = []
## The receiving player's place in [member players]: their seat once the match is
## on; -1 when not known.
var you := -1


## Whether the receiving player is the room's host.
func you_host() -> bool:
	return you >= 0 and you < players.size() and players[you].host
