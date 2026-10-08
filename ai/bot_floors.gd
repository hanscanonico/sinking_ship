class_name BotFloors
extends RefCounted
## The ship as bots find their way about her at the attitude of the moment (§5b.3, D10,
## SH32): a walk graph of the floors of the frame the match stands in — her own layout's
## on her decks; on any other face, the faces turned up then (Faces) — built the first
## time a bot stands in that frame, and asked of the frame's own Surfaces. Her faces are
## square to her axes, so the floors of the moment change only as the frame does: the
## graph is rebuilt then, and when a watertight door's leaf moves in the pose a bot
## reads (D10) — not every tick, and not between. "Down" is the pose's, read in that
## frame (Faces.framed). Once she has broken (SH33) each piece of her (Pieces) has its own
## graphs, of its own floors alone, so no way a bot finds crosses between two pieces: what
## a bot stands on is a footing — a piece and a frame (footing). Shared by the bots of one
## match, as the walk graph is: each answers only for the pose it is handed.

var _deck: WalkGraph
var _config: MatchConfig
var _rules: BrawlRules
var _faces: Faces
var _pieces: Pieces
var _graphs: Dictionary[int, WalkGraph] = {}


## The floors of [param config]'s ship, her decks' walk graph [param deck].
func _init(deck: WalkGraph, config: MatchConfig) -> void:
	_deck = deck
	_config = config
	_rules = config.rules
	_faces = Faces.new(config.ship, deck.surfaces(), _rules.brace_holds_to, true)


## The footing of a body on piece [param piece] of her (Pieces) standing in the frame
## [param up] (Faces.Up): the one number graph, honour and framed read. On the whole
## ship it is the frame.
static func footing(piece: int, up: int) -> int:
	return piece * Faces.Up.size() + up


## The walk graph of the footing [param at] (footing), over its frame's Surfaces with
## the watertight doors' leaves where [param pose] has them (Faces.surfaces) — the pose
## a bot reads, not the sinking's own; without one, as last built.
func graph(at: int, pose: ShipPose = null) -> WalkGraph:
	if at == Faces.Up.DECK:
		return _deck
	var faces := _faces_of(at)
	var up := at % Faces.Up.size()
	var surfaces := faces.surfaces(up, pose)
	if not _graphs.has(at) or _graphs[at].surfaces() != surfaces:
		_graphs[at] = WalkGraph.new(faces.layout(up), surfaces, _rules)
	return _graphs[at]


## Stands the footing [param at]'s Surfaces as a player sees them in [param seen], under
## [param pose] read in its frame: on its piece's decks with the railings the snapshot
## has broken and its crates; the faces it turns up have neither (Faces), whatever a
## snapshot jumped onto one still holds (MatchJump).
func honour(at: int, pose: ShipPose, seen: Dictionary) -> void:
	var surfaces := graph(at, pose).surfaces()
	var piece := at / Faces.Up.size()
	if at % Faces.Up.size() != Faces.Up.DECK:
		surfaces.honour(pose)
		return
	var broken := MatchState.broken_in(seen["railing_hp"])
	if piece == 0:
		surfaces.honour(pose, broken, PropState.from_snapshot(seen))
	else:
		_pieces_of().honour(piece, pose, broken, PropState.from_snapshot(seen))


## [param pose] — the whole ship's — as the footing [param at] reads it: its piece's, in
## its frame (Faces.framed).
func framed(pose: ShipPose, at: int) -> ShipPose:
	var piece := at / Faces.Up.size()
	return _faces_of(at).framed(pose.of_piece(piece), at % Faces.Up.size())


## Her decks' Surfaces, ship space's — or piece [param piece]'s, its space's: what a
## bot's eyes ask whom they see.
func surfaces(piece := 0) -> Surfaces:
	if piece == 0:
		return _deck.surfaces()
	return _pieces_of().faces(piece).surfaces(Faces.Up.DECK)


## The faces of the piece of the footing [param at].
func _faces_of(at: int) -> Faces:
	var piece := at / Faces.Up.size()
	return _faces if piece == 0 else _pieces_of().faces(piece)


## Her pieces (Pieces), made the first time a bot stands on one she broke into.
func _pieces_of() -> Pieces:
	if _pieces == null:
		_pieces = Pieces.new(_config.ship, _config.schedule(), _faces, _rules.brace_holds_to, true)
	return _pieces
