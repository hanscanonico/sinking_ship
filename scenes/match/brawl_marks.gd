class_name BrawlMarks
extends Node3D
## The brawl's marks on the deck, drawn from two snapshots (D5): where a body braces,
## its boots scuff the planks over the arc its brace covers — a soft smudge of dark
## wood dust, skid marks dragged in toward the feet and a pale crescent of torn grain
## at its far edge. It lies in the ship's plane — the deck's tilt is the ship's — on
## a flat floor alone: never on a stair, whose treads step under any one plane, and
## never under the sea. It reaches past the disc at the feet where the floor runs on,
## and shrinks back toward the body's own edge rather than run through a wall, over a
## railing or off the floor's edge (Surfaces), fitted again only as the planted body
## is moved or turns. Never on the seat whose eyes the view is in, as MatchView draws
## no body there (D14). A charge is drawn on the body itself (Brawler). Presentation
## only (D12): it never moves a body, and never reads a live PlayerState.

## How far the scuffs reach from the middle of the feet at most, in metres, and as
## shares of that: where the smudge starts, its darkest ring, and its far edge.
const SCUFF_REACH := 0.8
const SCUFF_FROM := 0.3
const SCUFF_DEEPEST := 0.55
const SCUFF_TO := 1.0
## The smudge's opacity at its darkest, the skid marks' and the crescent's.
const SMUDGE_ALPHA := 0.45
const SKID_ALPHA := 0.7
const DUST_ALPHA := 0.65
## How many slices a band of the scuffs takes round its arc, and how far in from
## either end of it it fades out, as a share of the arc.
const SMUDGE_SLICES := 14
const SMUDGE_FEATHER := 0.3
## Skid marks across the arc, as shares of it, how wide each is at its widest, in
## metres, and between which shares of the reach each runs.
const SKIDS: Array[float] = [0.18, 0.36, 0.5, 0.64, 0.82]
const SKID_WIDTH := 0.035
const SKID_FROM := 0.35
const SKID_TO := 0.85
## The crescent's depth, as a share of the reach; it lies in soft clumps round the
## arc, drawn in DUST_SLICES, pulled in by as much as DUST_RAGGED of the reach and
## thinned by as much as DUST_THIN between them, so it never reads as a ruled arc.
const DUST_DEPTH := 0.2
const DUST_SLICES := 30
const DUST_RAGGED := 0.05
const DUST_THIN := 0.9
## Lift off the deck so the scuffs never fight the planks for depth.
const SCUFF_LIFT := 0.025
## Reaches tried, from SCUFF_REACH down to the body's radius, as the scuffs are
## fitted; how far a planted body is moved, in metres, or turned, in radians, before
## they are fitted again; and how near the floor at the scuffs' edge must lie to the
## feet's height, in metres, for the floor to run on.
const FITS := 4
const REFIT_MOVE := 0.05
const REFIT_TURN := 0.1
const FLOOR_STEP := 0.02

var _driver: SimDriver
var _view: MatchView
var _schedule: SinkSchedule
var _surfaces: Surfaces
var _rules: BrawlRules
var _scuffs: Array[MeshInstance3D] = []
## Per seat: where its scuffs were last fitted, feet and facing, and to what share
## of SCUFF_REACH; a facing of INF until first fitted.
var _fitted_at := PackedVector3Array()
var _fitted_facing := PackedFloat32Array()
var _fits := PackedFloat32Array()


func setup(driver: SimDriver, view: MatchView, sim: MatchSim) -> void:
	_driver = driver
	_view = view
	_schedule = sim.schedule
	_surfaces = sim.surfaces
	_rules = sim.config.rules
	for scuff: MeshInstance3D in _scuffs:
		scuff.queue_free()
	_scuffs.clear()
	var mesh := scuffs(SCUFF_REACH, deg_to_rad(_rules.brace_arc_deg))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for seat in sim.config.seats:
		var scuff := MeshInstance3D.new()
		scuff.name = "Scuffs%d" % seat
		scuff.mesh = mesh
		scuff.material_override = material
		scuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scuff.visible = false
		add_child(scuff)
		_scuffs.append(scuff)
	_fitted_at.resize(sim.config.seats)
	_fitted_facing.resize(sim.config.seats)
	_fitted_facing.fill(INF)
	_fits.resize(sim.config.seats)


func _process(_delta: float) -> void:
	if _driver == null or _driver.current.is_empty():
		return
	var current := _driver.current
	var seats_then: Array = _driver.previous["seats"]
	var seats_now: Array = current["seats"]
	var pose := _schedule.pose_at(current["tick"])
	var ship := pose.transform.basis
	for index in seats_now.size():
		var now: Dictionary = seats_now[index]
		var seat: int = now["seat"]
		var scuff := _scuffs[seat]
		var feet := _view.seat_feet(seat)
		var was_shown := scuff.visible
		scuff.visible = seat != _view.eye_seat() and scuffed(now, feet, _surfaces, pose)
		if not scuff.visible:
			continue
		var facing := lerp_angle(seats_then[index]["facing"], now["facing"], _driver.alpha)
		var turned := absf(angle_difference(facing, _fitted_facing[seat])) > REFIT_TURN
		if not was_shown or turned or feet.distance_to(_fitted_at[seat]) > REFIT_MOVE:
			_fitted_at[seat] = feet
			_fitted_facing[seat] = facing
			_fits[seat] = fitted(feet, facing, now["surface"], _surfaces, _rules)
		var turn := ship * Basis(Vector3.UP, -facing)
		scuff.global_transform = Transform3D(
			turn.scaled_local(Vector3(_fits[seat], 1.0, _fits[seat])),
			_view.seat_world_position(seat) + ship.y * SCUFF_LIFT
		)


## The share of SCUFF_REACH the scuffs of a body planted at [param feet] on
## [param surface], facing [param facing], reach without running through a wall,
## over a railing or off the floor's edge as [param surfaces] has them: the furthest
## of FITS tried, and the body's own radius, as [param rules] has it, when none will.
static func fitted(
	feet: Vector3, facing: float, surface: int, surfaces: Surfaces, rules: BrawlRules
) -> float:
	var half_arc := deg_to_rad(rules.brace_arc_deg)
	for step in FITS:
		var reach := lerpf(SCUFF_REACH, rules.body_radius, float(step) / (FITS - 1))
		var clear := true
		for side in 3:
			var angle := facing + (side - 1) * half_arc
			var end := feet + Vector3(cos(angle), 0.0, sin(angle)) * reach
			clear = (
				clear
				and not surfaces.blocked(feet, end, rules.body_height, rules.step_height)
				and not surfaces.railed(feet, end, surface)
				and surfaces.under(end, FLOOR_STEP) != Surfaces.NONE
			)
		if clear:
			return reach / SCUFF_REACH
	return rules.body_radius / SCUFF_REACH


## Whether the body of [param entry], a seat's snapshot entry, its feet drawn at
## [param feet] in ship space, scuffs the floor: bracing, standing on a floor that
## is not a stair as [param surfaces] has it, and out of the sea under [param pose].
static func scuffed(entry: Dictionary, feet: Vector3, surfaces: Surfaces, pose: ShipPose) -> bool:
	return (
		entry["bracing"]
		and not entry["out"]
		and entry["state"] == PlayerState.Body.GROUNDED
		and not surfaces.is_ramp(entry["surface"])
		and not surfaces.wet(feet, pose)
	)


## A brace's scuffs reaching [param radius] from the middle of the feet, its brace
## covering [param half_arc] either side of +x, the body's facing in its own frame:
## one mesh coloured and faded by its vertices.
static func scuffs(radius: float, half_arc: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var smudge := Vector3(SCUFF_FROM, SCUFF_DEEPEST, SCUFF_TO) * radius
	_band(tool, smudge, half_arc, Color(ArtPalette.SCUFF, SMUDGE_ALPHA), SMUDGE_SLICES, 0.0)
	for across: float in SKIDS:
		_skid(tool, radius, lerpf(-half_arc, half_arc, across))
	var dust := Vector3(SCUFF_TO - DUST_DEPTH, SCUFF_TO - DUST_DEPTH * 0.5, SCUFF_TO) * radius
	var dusty := Color(ArtPalette.SCUFF_DUST, DUST_ALPHA)
	_band(tool, dust, half_arc, dusty, DUST_SLICES, DUST_RAGGED)
	return tool.commit()


## A band round the arc in [param colour], in [param slices], from [param reach].x
## out to .z: clear at both edges and full at .y, faded off either end of the arc,
## and — by [param ragged] of the reach — pulled in and thinned in clumps.
static func _band(
	tool: SurfaceTool, reach: Vector3, half_arc: float, colour: Color, slices: int, ragged: float
) -> void:
	var rings := PackedVector2Array(
		[Vector2(reach.x, 0.0), Vector2(reach.y, 1.0), Vector2(reach.z, 0.0)]
	)
	for ring in rings.size() - 1:
		for slice in slices:
			var corners := PackedVector3Array()
			var shades := PackedFloat32Array()
			for corner: Vector2i in [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
			]:
				var share := float(slice + corner.x) / slices
				var clump := _clump(share) if ragged > 0.0 else 0.0
				var at := rings[ring + corner.y]
				var angle := lerpf(-half_arc, half_arc, share)
				var out := at.x - reach.z * ragged * clump
				corners.append(Vector3(cos(angle), 0.0, sin(angle)) * out)
				var fade := smoothstep(0.0, SMUDGE_FEATHER, minf(share, 1.0 - share))
				shades.append(at.y * fade * (1.0 - DUST_THIN * clump))
			_quad(tool, corners, shades, colour)


## How thin the dust lies [param share] of the way round the arc, 0…1: a few soft
## clumps of unequal size, the same every brace.
static func _clump(share: float) -> float:
	var wave := sin(share * 17.0 + sin(share * 7.0) * 1.6) * 0.6 + sin(share * 41.0) * 0.4
	return clampf(0.5 + 0.5 * wave, 0.0, 1.0)


## A skid mark at [param angle] off the facing: a thin streak dragged in toward the
## feet, tapering to nothing at both ends.
static func _skid(tool: SurfaceTool, radius: float, angle: float) -> void:
	var along := Vector3(cos(angle), 0.0, sin(angle))
	var side := Vector3(-along.z, 0.0, along.x) * SKID_WIDTH * 0.5
	var middle := along * (SKID_FROM + SKID_TO) * 0.5 * radius
	var corners := PackedVector3Array(
		[along * SKID_FROM * radius, middle + side, along * SKID_TO * radius, middle - side]
	)
	var shades := PackedFloat32Array([0.0, 1.0, 0.0, 1.0])
	_quad(tool, corners, shades, Color(ArtPalette.SCUFF, SKID_ALPHA))


## Two triangles over [param corners], in order round a quad, each corner in
## [param colour] faded by its [param shades].
static func _quad(
	tool: SurfaceTool, corners: PackedVector3Array, shades: PackedFloat32Array, colour: Color
) -> void:
	for corner: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(Color(colour, colour.a * shades[corner]))
		tool.add_vertex(corners[corner])
