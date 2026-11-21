class_name SeatRoom
extends RefCounted
## The room of her a seat is in, as the words that name where it is ask it: the
## first-person HUD's plate, its "In the water" for "In the sea", and the word for a
## seat the cold put out inside her (Hud.out_word). A body on its feet is in the room
## whose floor it stands on (ShipLayout.room_at); one afloat is off every floor, and in
## the room round it while it is inside her at all — in one of her cells
## (ShipPose.cell_at), as the sim asks of a seat going down with her
## (MatchVerdict.gone_with).

## Per layout asked of, its rooms indexed (RoomIndex).
var _indexes := {}
## Per seat out of the match asked of, whether it went out inside one of her rooms
## (out_aboard).
var _aboard := {}


## The room of [param layout] holding [param feet] — a seat's, in the space of its
## piece of her, which [param pose] is that piece's — within [param step] of its floor
## or afloat over it inside her; -1 in none: on an open deck, or out in the sea.
func of(layout: ShipLayout, pose: ShipPose, feet: Vector3, step: float) -> int:
	if not _indexes.has(layout):
		_indexes[layout] = RoomIndex.new(layout)
	var index: RoomIndex = _indexes[layout]
	var room := index.room_at(feet, step)
	if room == -1 and pose != null and pose.cell_at(feet) != CellMap.NONE:
		room = index.room_around(feet, step)
	return room


## Whether [param seat], out of [param sim]'s match in [param snapshot], lies inside one
## of her rooms: the cold put it out aboard, never overboard (Hud.out_word). Asked once
## per seat until forget() — one out of the match stays where it went out, in its piece's
## space, which is her ship space — and false for no seat, or one still in.
func out_aboard(sim: MatchSim, snapshot: Dictionary, seat: int) -> bool:
	if _aboard.has(seat):
		return _aboard[seat]
	var mine := MatchState.entry_of(snapshot.get("seats", []), seat)
	if mine.is_empty() or not mine["out"]:
		return false
	var pose := sim.schedule.pose_at(snapshot["tick"]).of_piece(mine["piece"])
	_aboard[seat] = of(sim.config.ship, pose, mine["pos"], sim.config.rules.step_height) != -1
	return _aboard[seat]


## Forgets where every seat went out: for the next match.
func forget() -> void:
	_aboard.clear()
