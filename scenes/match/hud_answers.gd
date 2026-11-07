class_name HudAnswers
extends RefCounted
## What the first-person HUD reads off the snapshot it draws (FirstPersonHud, #410): her
## pose whole and of the eyes' piece, the eyes' own entry, the bodies as seen from that
## piece and framed on the face the eyes stand on, and the Surfaces honoured with the
## snapshot's broken railings and crates that the crosshair, the prompts and the
## chevrons ask. A snapshot is shown frame after frame until the next tick's, so each is
## asked once — and each body's line of sight once per eye height — and every frame of
## it is drawn from the same answers.

## Her pose at the snapshot's tick, whole and of the eyes' piece; the eyes' entry, {} for
## none; and whether it is in, so the rest below is answered.
var whole: ShipPose
var pose: ShipPose
var me: Dictionary
var is_in := false
## The snapshot as seen from the eyes' piece (Pieces.seen_from), and framed on the face
## they stand on (Faces.framed_snapshot); the eyes' piece's faces, the Surfaces of that
## face and of its deck, and her pose in that face's frame while the eyes swim, else null.
var seen: Dictionary
var framed: Dictionary
var faces: Faces
var here: Surfaces
var deck: Surfaces
var framed_pose: ShipPose

var _schedule: SinkSchedule
var _faces: Faces
## Its own, honoured with the pose, broken railings and crates of the snapshot asked:
## what a climb, a shove or a look meets is the ship as that tick has it, and the sim's
## stays the sim's. Once she has broken, the eyes' piece's (Pieces).
var _surfaces: Surfaces
var _pieces: Pieces
## The crates of the snapshot asked, and that snapshot's crate entries they were made
## from: made again only for another snapshot's.
var _crates: Array[PropState] = []
var _crates_of: Array = []
## The snapshot last asked, its tick, its seat and what else it was asked with.
var _asked: Dictionary
var _asked_tick := -1
var _asked_seat := -1
var _asked_with := []
## Per seat, whether it is seen from the eyes at height _sight_eye over the snapshot
## asked (sees).
var _sight := {}
var _sight_eye := NAN


func _init(sim: MatchSim) -> void:
	_schedule = sim.schedule
	_faces = sim.faces
	_surfaces = Surfaces.new(sim.config.ship)
	_pieces = Pieces.new(
		sim.config.ship,
		sim.schedule,
		sim.faces,
		sim.config.rules.brace_holds_to,
		SeaPhysics.load_default().capsized_movement
	)


## Asks [param snapshot] for [param seat]'s eyes, with [param with] — whatever else what
## is drawn of it depends on — unless that was what was last asked: a snapshot is the
## same one while it is the same dictionary at the same tick (a client's view keeps its
## dictionary, a tick on, while it waits on the host). Whether it was asked anew.
func ask(snapshot: Dictionary, seat: int, with: Array = []) -> bool:
	var tick: int = snapshot["tick"] if not snapshot.is_empty() else -1
	if (
		is_same(snapshot, _asked)
		and tick == _asked_tick
		and seat == _asked_seat
		and with == _asked_with
	):
		return false
	_asked = snapshot
	_asked_tick = tick
	_asked_seat = seat
	_asked_with = with
	_answer(snapshot, seat)
	return true


## Whether the eyes at [param from], [param eye_height] over their feet, see the body of
## [param seat] whose eyes stand at [param to] (Surfaces.line_of_sight on the eyes' deck):
## asked once per snapshot and eye height.
func sees(seat: int, from: Vector3, to: Vector3, eye_height: float) -> bool:
	if eye_height != _sight_eye:
		_sight.clear()
		_sight_eye = eye_height
	if not _sight.has(seat):
		_sight[seat] = deck.line_of_sight(from, to, pose)
	return _sight[seat]


func _answer(snapshot: Dictionary, seat: int) -> void:
	is_in = false
	_sight.clear()
	_sight_eye = NAN
	if snapshot.is_empty() or snapshot["phase"] == MatchState.Phase.ENDED:
		return
	whole = _schedule.pose_at(snapshot["tick"])
	me = MatchState.entry_of(snapshot["seats"], seat)
	var piece: int = me["piece"] if not me.is_empty() else 0
	pose = whole.of_piece(piece)
	# As the snapshot has them: the railings the match has broken, and its crates.
	var broken := MatchState.broken_in(snapshot["railing_hp"])
	if not is_same(_crates_of, snapshot["props"]):
		_crates_of = snapshot["props"]
		_crates = PropState.from_snapshot(snapshot, _crates)
	deck = _surfaces
	if piece == 0:
		_surfaces.honour(whole, broken, _crates)
	else:
		_pieces.honour(piece, whole, broken, _crates)
		deck = _pieces.faces(piece).surfaces(Faces.Up.DECK)
	if me.is_empty() or me["out"]:
		return
	is_in = true
	# On a face but her decks the bodies' moves and looks are in its frame, and so are
	# the crosshair's, the climb's and the wedges' answers (Faces); on a piece of her, in
	# its space.
	var up := MatchState.up_of(snapshot, me)
	faces = _faces if piece == 0 else _pieces.faces(piece)
	seen = Pieces.seen_from(snapshot, piece, whole)
	framed = Faces.framed_snapshot(seen, up)
	here = deck if up == Faces.Up.DECK else faces.surfaces(up)
	framed_pose = null
	if me["state"] == PlayerState.Body.SWIMMING:
		framed_pose = faces.framed(pose, up)
