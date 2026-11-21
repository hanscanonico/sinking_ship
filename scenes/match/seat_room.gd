class_name SeatRoom
extends RefCounted
## The room of her a seat is in, as the words that name where it is ask it: the
## first-person HUD's plate, its "In the water" for "In the sea", and the word for a
## seat the cold put out inside her (Hud.out_word). A body on its feet is in the room
## whose floor it stands on (ShipLayout.room_at); one afloat is off every floor, and in
## the room round it while it is inside her at all — in one of her cells
## (ShipPose.cell_at), as the sim asks of a seat going down with her
## (MatchVerdict.gone_with). The ghost stands in a room as a seat does (ghost_place).

## Per layout asked of, its rooms indexed (RoomIndex).
var _indexes := {}
## Per seat out of the match asked of, whether it went out inside one of her rooms
## (out_aboard).
var _aboard := {}
## Where the ghost last asked of stood, and the tick, its piece and its feet that was
## asked for (ghost_place).
var _ghost_place := ""
var _ghost_at := []


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


## What the HUD's plate calls a place of [param layout]: its room [param room], else,
## for -1, the platform [param surface] is — a body's surface on her decks — else "".
static func named(layout: ShipLayout, room: int, surface: int) -> String:
	if room != -1:
		return layout.rooms[room].name
	if surface >= 0 and surface < layout.platforms.size():
		return layout.platforms[surface].name
	return ""


## Where [param ghost] stands on her as [param snapshot] has her under [param schedule],
## as named() calls it: the room it is in, within [param step] of its floor, else the
## platform under it on her decks — on the piece of her it walks, as a seat's is. "" while
## the view is not its (GhostWalk.active). Worked out again only once it has moved, or
## for another tick.
func ghost_place(
	ghost: GhostWalk, schedule: SinkSchedule, snapshot: Dictionary, step: float
) -> String:
	if ghost == null or not ghost.active or snapshot.is_empty():
		return ""
	var body := ghost.body
	var at := [snapshot["tick"], body.piece, body.pos, body.surface, ghost.up()]
	if at != _ghost_at:
		_ghost_at = at
		var layout := ghost.layout()
		var pose := schedule.pose_at(snapshot["tick"]).of_piece(body.piece)
		var room := of(layout, pose, body.pos, step)
		var decks := ghost.up() == Faces.Up.DECK
		_ghost_place = named(layout, room, body.surface if decks else Surfaces.NONE)
	return _ghost_place


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
