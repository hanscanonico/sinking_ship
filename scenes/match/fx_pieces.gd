class_name FxPieces
extends Node3D
## Where the sinking's effects are drawn once she has broken (SH33, #466): each on the
## piece of her its point lies on (ShipPieces.leaf_at) — a seat's on the piece its seat is
## drawn on — as MatchView draws that piece, never where her aft piece, which the ship's
## own node follows, would carry it. It follows the ship as drawn, and under it a node per
## piece past her first follows that piece: the wet decks' overlays (DeckWetness) hang from
## the piece each stretch of a deck lies on, a deck across a cut drawn on both, and each
## piece's wreckage on deck (DeckDebris) from its own. While she is whole, or for a hull
## that never breaks, all of it is the ship's: one piece. Presentation only (D12).

## The wet decks' overlay stands this far over the planks.
const WET_LIFT := 0.004
const WET_SHADER := preload("res://scenes/match/wet_deck.gdshader")

var _view: MatchView
var _wetness: DeckWetness
## The pieces she ends in (ShipPieces.leaves_of), none while she never breaks; where each
## past the first begins along her; and per piece its space to the ship's own node's as
## last followed, its node — this one, for the first — and its wreckage on deck.
var _leaves := PackedInt32Array()
var _cuts := PackedFloat64Array()
var _offsets: Array[Transform3D] = [Transform3D.IDENTITY]
var _holders: Array[Node3D] = []
var _debris: Array[DeckDebris] = []
## Per stretch of a tracked deck on one piece (DeckWetness.bands), its overlay; per
## tracked deck, its picture and the first of its overlays, one past the last at the end.
var _overlays: Array[MeshInstance3D] = []
var _textures: Array[ImageTexture] = []
var _first_overlay := PackedInt32Array([0])
## The deck whose wetness the next step brings up to date.
var _next_wet := 0


func _init() -> void:
	_holders = [self]
	var first := DeckDebris.new()
	first.name = "Debris"
	add_child(first)
	_debris = [first]


## The place along [param cuts] — where each piece past the first begins along her, aft to
## fore — of the piece the point [param x] along her lies on: 0 aft of every cut, and for
## none.
static func leaf_along(cuts: PackedFloat64Array, x: float) -> int:
	for at in range(cuts.size(), 0, -1):
		if x >= cuts[at - 1]:
			return at
	return 0


## Draws the effects of [param sim]'s match on the pieces [param view] draws her in: a
## node and wreckage per piece, [param wetness]'s decks soaked and drawn on the pieces each
## stretch of them lies on.
func setup(view: MatchView, sim: MatchSim, wetness: DeckWetness) -> void:
	_view = view
	_wetness = wetness
	_leaves = ShipPieces.leaves_of(sim.schedule)
	_cuts.clear()
	for at in range(1, _leaves.size()):
		_cuts.append(sim.schedule.span_of(_leaves[at]).x)
	for at in range(_holders.size() - 1, 0, -1):
		_holders[at].queue_free()
	_holders.resize(1)
	_debris.resize(1)
	_offsets = [Transform3D.IDENTITY]
	for at in range(1, _leaves.size()):
		var holder := Node3D.new()
		holder.name = "Piece%d" % at
		add_child(holder)
		var debris := DeckDebris.new()
		debris.name = "Debris"
		holder.add_child(debris)
		_holders.append(holder)
		_debris.append(debris)
		_offsets.append(Transform3D.IDENTITY)
	for debris: DeckDebris in _debris:
		debris.setup(sim.config.ship)
	wetness.cut_at(_cuts)
	_build_overlays(sim.config.ship)


## Follows the ship drawn at [param ship], every piece where the view draws it.
func follow(ship: Transform3D) -> void:
	transform = ship
	if _view == null or _leaves.is_empty():
		return
	var root := _view.ship_to_world().affine_inverse()
	for at in range(1, _leaves.size()):
		_offsets[at] = root * _view.piece_to_world(at)
		_holders[at].transform = _offsets[at]


## Where the piece ship point [param point] lies on is drawn, in the space of the ship's
## own node — as last followed; none while she is whole.
func of(point: Vector3) -> Transform3D:
	return _offsets[leaf_along(_cuts, point.x)]


## Where the piece [param cue] plays on is drawn, as of() has it: its seat's, for a cue of
## a seat's.
func of_cue(cue: FxCue) -> Transform3D:
	if cue.seat < 0 or _view == null or _leaves.is_empty():
		return of(cue.position)
	var root := _view.ship_to_world().affine_inverse()
	return root * _view.global_transform * _view.seat_to_world(cue.seat)


## The wreckage on the decks of the piece ship point [param point] lies on.
func debris_on(point: Vector3) -> DeckDebris:
	return _debris[leaf_along(_cuts, point.x)]


## How many bits of wreckage are out on every piece's decks.
func debris_count() -> int:
	var count := 0
	for debris: DeckDebris in _debris:
		count += debris.count()
	return count


func advance_debris(delta: float) -> void:
	for debris: DeckDebris in _debris:
		debris.advance(delta)


## No wreckage on any deck, and the decks' wetness brought up to date from the first.
func clear() -> void:
	for debris: DeckDebris in _debris:
		debris.clear()
	_next_wet = 0


## Brings the next deck's wetness up to date with the ship drawn at [param ship], each
## stretch of it as its own piece stands — one deck a step, round them all in turn, so no
## step pays for them all — and its overlays with it.
func dry_next(ship: Transform3D) -> void:
	if _textures.is_empty():
		return
	var slot := _next_wet
	_next_wet = (_next_wet + 1) % _textures.size()
	var seconds := _textures.size() * Ticks.SECONDS_PER_TICK
	if _wetness.update_one(slot, ship, seconds, _offsets):
		_textures[slot].update(_wetness.picture(slot))
	var shows := _wetness.shows(slot)
	for overlay in range(_first_overlay[slot], _first_overlay[slot + 1]):
		_overlays[overlay].visible = shows


## Sends under every piece of [param flotsam] afloat over a deck shallow under the sea, each
## deck as its own piece stands in [param pose].
func sink_shallows(flotsam: Flotsam, pose: ShipPose) -> void:
	var world := _view.global_transform if _view != null else Transform3D.IDENTITY
	if _leaves.is_empty():
		flotsam.go_under_shallows(world * pose.transform)
		return
	var fore: Array[Transform3D] = []
	for at in range(1, _leaves.size()):
		fore.append(world * pose.of_piece(_leaves[at]).transform)
	flotsam.go_under_shallows(world * pose.of_piece(_leaves[0]).transform, fore, _cuts)


## An overlay per stretch of a deck DeckWetness tracks on one piece, just over its planks,
## hung from that piece, in the deck's own picture of its wetness.
func _build_overlays(layout: ShipLayout) -> void:
	for overlay: MeshInstance3D in _overlays:
		overlay.queue_free()
	_overlays.clear()
	_textures.clear()
	_first_overlay = PackedInt32Array([0])
	for slot in _wetness.platforms.size():
		var index := _wetness.platforms[slot]
		var platform := layout.platforms[index]
		var texture := ImageTexture.create_from_image(_wetness.picture(slot))
		var material := ShaderMaterial.new()
		material.shader = WET_SHADER
		material.set_shader_parameter("wetness", texture)
		var bands := _wetness.bands(slot)
		for at in bands.size() - 1:
			if bands[at] >= bands[at + 1]:
				continue
			var from := platform.area.position.x + bands[at] * DeckWetness.CELL
			var to := platform.area.position.x + bands[at + 1] * DeckWetness.CELL
			var overlay := MeshInstance3D.new()
			overlay.name = "Wet%d" % index if at == 0 else "Wet%d_%d" % [index, at]
			overlay.mesh = _overlay(
				platform, _wetness.extent(slot), from, minf(to, platform.area.end.x)
			)
			overlay.material_override = material
			overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			overlay.visible = false
			_holders[at].add_child(overlay)
			_overlays.append(overlay)
		_textures.append(texture)
		_first_overlay.append(_overlays.size())


## [param platform]'s area from [param from] to [param to] along her as a quad WET_LIFT
## over it, its UV running over [param extent] metres from the platform's least corner.
static func _overlay(platform: ShipPlatform, extent: Vector2, from: float, to: float) -> ArrayMesh:
	var area := platform.area
	var height := platform.height + WET_LIFT
	var least := Vector2(from, area.position.y)
	var most := Vector2(to, area.end.y)
	var points := PackedVector3Array()
	var uvs := PackedVector2Array()
	for corner: Vector2 in [least, Vector2(most.x, least.y), most]:
		points.append(Vector3(corner.x, height, corner.y))
		uvs.append((corner - area.position) / extent)
	for corner: Vector2 in [least, most, Vector2(least.x, most.y)]:
		points.append(Vector3(corner.x, height, corner.y))
		uvs.append((corner - area.position) / extent)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
