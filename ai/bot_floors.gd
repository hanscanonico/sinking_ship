class_name BotFloors
extends RefCounted
## The ship as bots find their way about her at the attitude of the moment (§5b.3, D10,
## SH32): a walk graph of the floors of the frame the match stands in — her own layout's
## on her decks; on any other face, the faces turned up then (Faces) — built the first
## time a bot stands in that frame, and asked of the frame's own Surfaces. Her faces are
## square to her axes, so the floors of the moment change only as the frame does: the
## graph is rebuilt then, not every tick, and not between. "Down" is the pose's, read in
## that frame (Faces.framed). Shared by the bots of one match, as the walk graph is:
## each answers only for the pose it is handed.

var _deck: WalkGraph
var _rules: BrawlRules
var _faces: Faces
var _graphs: Dictionary[int, WalkGraph] = {}


## The floors of [param config]'s ship, her decks' walk graph [param deck].
func _init(deck: WalkGraph, config: MatchConfig) -> void:
	_deck = deck
	_rules = config.rules
	_faces = Faces.new(config.ship, deck.surfaces(), null, _rules.brace_holds_to, true)


## The walk graph of the frame [param up] (Faces.Up), over that frame's Surfaces.
func graph(up: int) -> WalkGraph:
	if up == Faces.Up.DECK:
		return _deck
	if not _graphs.has(up):
		_graphs[up] = WalkGraph.new(_faces.layout(up), _faces.surfaces(up), _rules)
	return _graphs[up]


## [param pose] as the frame [param up] reads it (Faces.framed).
func framed(pose: ShipPose, up: int) -> ShipPose:
	return _faces.framed(pose, up)


## Her decks' Surfaces, ship space's: what a bot's eyes ask whom they see.
func surfaces() -> Surfaces:
	return _deck.surfaces()
