class_name RemoteMatch
extends PlayedMatch
## A match played from a server (SH12): this player's MatchClient, over its share of
## the connection RoomClient holds. Each step() is one beat: this seat's frames sent,
## then what the server sent taken in — read off the wire by RoomClient.poll() before.


func _init(match_client: MatchClient) -> void:
	client = match_client


func step() -> Array[SimEvent]:
	client.sample()
	return client.step()
