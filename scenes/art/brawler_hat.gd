class_name BrawlerHat
extends RefCounted
## A brawler's hat as one small mesh coloured by its vertices, in the head bone's
## space: +y up the head, +z the way the face looks, the crown 0.26 up and the brows
## 0.16 up, which every brim stays above. Each part is tipped forward (positive) or
## back about the ear-to-ear axis. A thin brim is a flattened ball rather than a
## short tube: its normals run on round its edge, so its outline does too.

## Facets round a hat: few, as the rest of the ship is faceted.
const SEGMENTS := 12
const RINGS := 4


## The mesh for [param hat] in [param colour]; a bare head shows [param hair].
static func build(hat: Brawler.Hat, colour: Color, hair: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match hat:
		Brawler.Hat.CAP:
			# A flat cap: a soft crown pulled forward over a short peak.
			_dome(tool, Vector3(0.0, 0.18, 0.005), Vector3(0.105, 0.07, 0.13), 0.14, colour)
			var peak := colour.darkened(0.25)
			_box(tool, Vector3(0.0, 0.185, 0.12), Vector3(0.15, 0.014, 0.07), 0.3, peak)
		Brawler.Hat.SOUWESTER:
			# Oilskin: a deep dome and a brim that runs down over the neck.
			_dome(tool, Vector3(0.0, 0.165, -0.005), Vector3(0.105, 0.13, 0.118), -0.05, colour)
			_tube(tool, Vector3(0.0, 0.165, -0.03), 0.11, 0.2, 0.04, -0.2, colour.darkened(0.12))
		Brawler.Hat.BOATER:
			# Straw, flat-topped, with a deep band in the seat's colour.
			var brim := Vector3(0.175, 0.008, 0.175)
			_ball(tool, Vector3(0.0, 0.19, 0.0), brim, -0.08, ArtPalette.STRAW)
			_tube(tool, Vector3(0.0, 0.23, -0.003), 0.098, 0.1, 0.075, -0.08, ArtPalette.STRAW)
			_tube(tool, Vector3(0.0, 0.217, -0.002), 0.103, 0.104, 0.05, -0.08, colour)
		Brawler.Hat.BARE:
			# No hat: hair swept back from the brow, a lock lifted at the front.
			_dome(tool, Vector3(0.0, 0.165, -0.01), Vector3(0.092, 0.08, 0.12), -0.3, hair)
			_ball(tool, Vector3(0.025, 0.235, 0.05), Vector3(0.06, 0.035, 0.05), -0.4, hair)
		Brawler.Hat.BOBBLE:
			# A knitted watch cap: a turned-up cuff and a bobble.
			_dome(tool, Vector3(0.0, 0.18, -0.008), Vector3(0.094, 0.135, 0.11), -0.15, colour)
			var cuff := colour.darkened(0.22)
			_tube(tool, Vector3(0.0, 0.2, -0.008), 0.099, 0.103, 0.04, -0.15, cuff)
			var bobble := colour.lightened(0.2)
			_ball(tool, Vector3(0.0, 0.33, -0.035), Vector3.ONE * 0.04, 0.0, bobble)
		Brawler.Hat.TOP:
			# A topper with a dark band.
			_ball(tool, Vector3(0.0, 0.2, 0.0), Vector3(0.15, 0.008, 0.15), -0.06, colour)
			_tube(tool, Vector3(0.0, 0.31, -0.007), 0.1, 0.09, 0.21, -0.06, colour)
			_tube(tool, Vector3(0.0, 0.225, -0.001), 0.093, 0.093, 0.035, -0.06, ArtPalette.INK)
		Brawler.Hat.PEAKED:
			# A mate's cap: a band in the seat's colour with a brass badge, a wide top, a
			# black peak.
			_tube(tool, Vector3(0.0, 0.2, 0.0), 0.1, 0.1, 0.05, -0.05, colour.darkened(0.15))
			_tube(tool, Vector3(0.0, 0.245, -0.004), 0.13, 0.1, 0.04, -0.05, colour)
			var peak := Vector3(0.15, 0.012, 0.075)
			_box(tool, Vector3(0.0, 0.18, 0.11), peak, 0.35, ArtPalette.INK)
			var badge := Vector3(0.03, 0.025, 0.01)
			_box(tool, Vector3(0.0, 0.205, 0.101), badge, 0.0, ArtPalette.BRASS)
	tool.index()
	return tool.commit()


## A half-sphere standing on its cut at [param at], [param size] across, high and
## deep.
static func _dome(tool: SurfaceTool, at: Vector3, size: Vector3, tip: float, colour: Color) -> void:
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = SEGMENTS
	dome.rings = RINGS
	_add(tool, dome, at, size, tip, colour)


## A ball round [param at], [param size] its radii.
static func _ball(tool: SurfaceTool, at: Vector3, size: Vector3, tip: float, colour: Color) -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = SEGMENTS
	ball.rings = RINGS
	_add(tool, ball, at, size, tip, colour)


## A box round [param at], [param size] across, high and deep.
static func _box(tool: SurfaceTool, at: Vector3, size: Vector3, tip: float, colour: Color) -> void:
	_add(tool, BoxMesh.new(), at, size, tip, colour)


## A short tube round [param at]: [param top] and [param bottom] radii, [param height].
static func _tube(
	tool: SurfaceTool,
	at: Vector3,
	top: float,
	bottom: float,
	height: float,
	tip: float,
	colour: Color
) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = top
	tube.bottom_radius = bottom
	tube.height = height
	tube.radial_segments = SEGMENTS
	tube.rings = 1
	_add(tool, tube, at, Vector3.ONE, tip, colour)


## Every triangle of [param mesh] into [param tool]: scaled by [param size], tipped
## by [param tip] and moved to [param at], in [param colour].
static func _add(
	tool: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, size: Vector3, tip: float, colour: Color
) -> void:
	var place := Transform3D(Basis.from_euler(Vector3(tip, 0.0, 0.0)).scaled_local(size), at)
	var turn := place.basis.inverse().transposed()
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		tool.set_color(colour)
		tool.set_normal((turn * normals[index]).normalized())
		tool.add_vertex(place * vertices[index])
