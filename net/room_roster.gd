class_name RoomRoster
extends RefCounted
## A room as the players in it see it (SH12): its code, whether its match is on, and
## its players in the order they joined — the first the room's host, any whose client
## has gone mid-match played by a bot, and any who watch seatless (seated() lists the
## rest, in seat order). What a menu shows; the server sends one to each
## player whenever it changes.


## One player of the room.
class Player:
	extends RefCounted
	var name: String
	## Whether this player starts the match.
	var host: bool
	## Whether this player's client has gone and a bot plays the seat.
	var bot: bool
	## Whether this player only watches, taking no seat.
	var watching: bool

	func _init(display_name: String, is_host: bool, is_bot: bool, watches := false) -> void:
		name = display_name
		host = is_host
		bot = is_bot
		watching = watches


var code := ""
var playing := false
var players: Array[Player] = []
## The receiving player's place in [member players]; -1 when not known.
var you := -1


## Whether the receiving player is the room's host.
func you_host() -> bool:
	return you >= 0 and you < players.size() and players[you].host


## Whether the receiving player only watches.
func you_watch() -> bool:
	return you >= 0 and you < players.size() and players[you].watching


## The players who take a seat, in seat order: every one but those who watch.
func seated() -> Array[Player]:
	var playing: Array[Player] = []
	for player: Player in players:
		if not player.watching:
			playing.append(player)
	return playing
