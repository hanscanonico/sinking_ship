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


## The railings a snapshot has broken and its crates (facts_of), and the arrays of the
## snapshot they were worked out from.
class Facts:
	extends RefCounted
	var broken: PackedInt32Array
	var props: Array[PropState]
	var _railing_hp: PackedFloat64Array
	var _props_of: Array

	## [param seen]'s, its crates each made from its entry — or, the very entry
	## [param earlier]'s snapshot had, the crate [param earlier] made of it: a laid saloon
	## at rest is made once.
	func _init(seen: Dictionary, earlier: Facts = null) -> void:
		_railing_hp = seen["railing_hp"]
		_props_of = seen["props"]
		broken = MatchState.broken_in(_railing_hp)
		var before: Array = [] if earlier == null else earlier._props_of
		for index in _props_of.size():
			var entry: Dictionary = _props_of[index]
			if index < before.size() and is_same(before[index], entry):
				props.append(earlier.props[index])
			else:
				props.append(PropState.from_dict(entry))

	## Whether these are [param seen]'s: worked out from its own railing and crate arrays.
	func of(seen: Dictionary) -> bool:
		return is_same(_railing_hp, seen["railing_hp"]) and is_same(_props_of, seen["props"])


var _deck: WalkGraph
var _config: MatchConfig
var _rules: BrawlRules
var _faces: Faces
var _pieces: Pieces
var _graphs: Dictionary[int, WalkGraph] = {}
## Per snapshot tick, what facts_of worked out from it.
var _facts: Dictionary[int, Facts] = {}
## How many snapshots' facts are kept: one for every tick from the newest a bot reading
## these floors reads to the oldest the slowest of them does (reads_back).
var _kept := 1
## The facts last worked out, whose crates the next may share (Facts).
var _newest: Facts
## Per footing honoured on its decks, its Surfaces, the pose and the facts it was last
## honoured with: honoured again with the same, it is left as it stands — the bots of one
## reaction read one snapshot, and a laid saloon is stood once for them all.
var _honoured := {}
var _worked_out := 0


## The floors of [param config]'s ship, her decks' walk graph [param deck].
func _init(deck: WalkGraph, config: MatchConfig) -> void:
	_deck = deck
	_config = config
	_rules = config.rules
	_faces = Faces.new(config.ship, deck.surfaces(), _rules.brace_holds_to, true)


## A bot reads these floors [param ticks] back (BotProfile.reaction_ticks): enough
## snapshots' facts are kept that each is worked out once however its readings by bots
## of every delay interleave.
func reads_back(ticks: int) -> void:
	_kept = maxi(_kept, ticks + 1)


## How many times a snapshot's broken railings and crates were worked out (facts_of).
func facts_worked_out() -> int:
	return _worked_out


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
	var facts := facts_of(seen)
	var with := [surfaces, pose, facts]
	if _honoured.get(at, []) == with:
		return
	_honoured[at] = with
	if piece == 0:
		surfaces.honour(pose, facts.broken, facts.props)
	else:
		_pieces_of().honour(piece, pose, facts.broken, facts.props)


## The railings [param seen] has broken and its crates, worked out once for every bot
## reading that snapshot: its tick names it, and its own railing and crate arrays, which
## every perceived copy of it shares (BotView), tell it from another snapshot of the same
## tick. The oldest tick kept gives way to a new one: bots read ticks forward, so it is
## the one none reads again. Read only, both ways: every bot is handed the same facts,
## and a snapshot's railing_hp and props must not be edited in place once read.
func facts_of(seen: Dictionary) -> Facts:
	var tick: int = seen["tick"]
	var kept: Facts = _facts.get(tick)
	if kept != null and kept.of(seen):
		return kept
	if kept == null and _facts.size() >= _kept:
		_facts.erase(_facts.keys().min())
	_worked_out += 1
	kept = Facts.new(seen, _newest)
	_facts[tick] = kept
	_newest = kept
	return kept


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


## The share of a standing body's height a body with its feet at [param feet] on piece
## [param piece] stands at, her decks its floors (BrawlRules.height_at): under 1 for a
## crawler, whose eyes are as much lower.
func height_share(feet: Vector3, piece := 0) -> float:
	return _rules.height_at(surfaces(piece), feet) / _rules.body_height


## The faces of the piece of the footing [param at].
func _faces_of(at: int) -> Faces:
	var piece := at / Faces.Up.size()
	return _faces if piece == 0 else _pieces_of().faces(piece)


## Her pieces (Pieces), made the first time a bot stands on one she broke into.
func _pieces_of() -> Pieces:
	if _pieces == null:
		_pieces = Pieces.new(_config.ship, _config.schedule(), _faces, _rules.brace_holds_to, true)
	return _pieces
