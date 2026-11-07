class_name LampGlobes
extends Node3D
## The rooms' hanging lamps of one dressed ship drawn together (ShipArt.pack): each
## pendant's and cargo lamp's model an instance of a MultiMesh, one a CELL of her and a
## model, rather than a node of its own — the Titanic hangs 2,700, and every node moves as
## she does. Each lamp (ShipLamp) still swings and burns as its own: it poses its
## instance as it swings and hands it its glass's glow (draw_lamp), which the instance draws
## as its material would (lamp_glass.gdshader, lamp_metal.gdshader). A fire, set in its
## wall, and a lamp hung from a deck that can fall stay nodes of their own.

const GLASS_SHADER := preload("res://scenes/art/lamp_glass.gdshader")
const METAL_SHADER := preload("res://scenes/art/lamp_metal.gdshader")
const TIN_SHADER := preload("res://scenes/art/lamp_tin.gdshader")
## The box of her, in ship metres, whose lamps share a MultiMesh: drawn and culled as
## one, a storey high, a stretch of a deck's rooms long and half her beam wide — on the
## Titanic about seven lamps a cell, 354 cells for her 2,574 hanging lamps. A lamp drawn
## alone already stands within reach of more lights than Compatibility lights a mesh with
## (a median of 23 on the Titanic, if all burned); a cell, of 38. Only the glass, unshaded,
## shows a lamp lit, and the brass a light misses is a few pixels.
const CELL := Vector3(12.0, 2.5, 15.0)
## Where a hidden lamp's instance is drawn: nowhere.
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

## Per lamp drawn, by its slot: its MultiMesh, its instance in it, and the transform of
## its model under it.
var _multis: Array[MultiMesh] = []
var _instances := PackedInt32Array()
var _parts: Array[Transform3D] = []
## Per slot, where its instance was last drawn and the glow and power it was last given
## (custom data), so each is set as it changes — and read here, never back from the
## MultiMesh.
var _placed: Array[Transform3D] = []
var _glows: Array[Color] = []


## Draws each of [param lamps] hung straight from this node's parent, not a fire, here:
## its model's node taken from it, and the lamp told its slot (ShipLamp.hang_in). Its
## MultiMeshes stand apart from her, placed by [param still] where this node stands
## (StillGroup), when given.
func take(lamps: Array[ShipLamp], still: StillInstances = null) -> void:
	var group := still.group(self) if still != null else null
	# Per model and cell, the lamps drawn by it; and per model its mesh as drawn here.
	var cells := {}
	var order: Array = []
	var meshes := {}
	for lamp: ShipLamp in lamps:
		if lamp.get_parent() != get_parent() or lamp.kind() == ShipLamp.Kind.FIRE:
			continue
		var part := lamp.model_part()
		if part == null:
			continue
		var cell := Vector3i((lamp.position / CELL).floor())
		var key := [part.mesh, cell]
		if not cells.has(key):
			cells[key] = []
			order.append(key)
		(cells[key] as Array).append(lamp)
		if not meshes.has(part.mesh):
			meshes[part.mesh] = _drawn(part)
	for key: Array in order:
		var held: Array = cells[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = meshes[key[0]]
		multi.instance_count = held.size()
		var drawn := MultiMeshInstance3D.new()
		drawn.name = "Cell"
		drawn.multimesh = multi
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index in held.size():
			var lamp: ShipLamp = held[index]
			var part := lamp.model_part()
			_multis.append(multi)
			_instances.append(index)
			_parts.append(part.transform)
			_placed.append(Transform3D(Basis(), Vector3.ONE * NAN))
			_glows.append(Color(-1.0, -1.0, 0.0, 0.0))
			lamp.remove_child(part)
			# Its mesh let go first: a headless build complains of a lamp part freed with it.
			part.mesh = null
			part.free()
			lamp.hang_in(self, _multis.size() - 1)
		add_child(drawn)
		if group != null:
			group.hold(drawn)


## How many lamps it draws.
func size() -> int:
	return _multis.size()


## Where [param slot]'s lamp's model is drawn under it (HIDDEN, nowhere, while hidden),
## and the glow and power it was last given: its glass's emission energy, and 1 when red.
func placed(slot: int) -> Transform3D:
	return _placed[slot]


func lit(slot: int) -> Vector2:
	return Vector2(_glows[slot].r, _glows[slot].g)


## Every triangle it draws, under it: each lamp's model where it hangs, but a hidden one's.
func faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	var corners := {}
	for slot in _multis.size():
		if _placed[slot] == HIDDEN:
			continue
		var mesh := _multis[slot].mesh
		if not corners.has(mesh):
			corners[mesh] = mesh.get_faces()
		for corner: Vector3 in corners[mesh]:
			faces.append(_placed[slot] * corner)
	return faces


## Draws [param slot]'s lamp hung as [param lamp_transform] has it under her, hidden
## unless [param shown], its glass glowing [param glow] (its material's emission energy)
## and red when [param emergency].
func draw_lamp(
	slot: int, lamp_transform: Transform3D, shown: bool, glow: float, emergency: bool
) -> void:
	place(slot, lamp_transform, shown)
	var lit := Color(glow, 1.0 if emergency else 0.0, 0.0, 0.0)
	if _glows[slot] != lit:
		_glows[slot] = lit
		_multis[slot].set_instance_custom_data(_instances[slot], lit)


## Draws [param slot]'s lamp hung as [param lamp_transform] has it under her, hidden
## unless [param shown], glowing as draw_lamp last had it.
func place(slot: int, lamp_transform: Transform3D, shown: bool) -> void:
	var placed := lamp_transform * _parts[slot] if shown else HIDDEN
	if _placed[slot] != placed:
		_placed[slot] = placed
		_multis[slot].set_instance_transform(_instances[slot], placed)


## Places each of [param slots]' lamps as place would, hung as [param transforms] has it
## and shown as [param shown] (1) has it: LampSwing's frame of them, at once.
func place_all(
	slots: PackedInt32Array, transforms: Array[Transform3D], shown: PackedByteArray
) -> void:
	for index in slots.size():
		var slot := slots[index]
		var placed := transforms[index] * _parts[slot] if shown[index] == 1 else HIDDEN
		if _placed[slot] != placed:
			_placed[slot] = placed
			_multis[slot].set_instance_transform(_instances[slot], placed)


## The model [param part] draws, each surface in the shader that draws its material among
## its fellows (StandardMaterial3D's own, but for the fade judged per instance).
static func _drawn(part: MeshInstance3D) -> Mesh:
	var mesh := ArrayMesh.new()
	for surface in part.mesh.get_surface_count():
		mesh.add_surface_from_arrays(
			part.mesh.surface_get_primitive_type(surface), part.mesh.surface_get_arrays(surface)
		)
		var own := part.get_active_material(surface) as BaseMaterial3D
		var drawn := ShaderMaterial.new()
		if own.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			drawn.shader = GLASS_SHADER
			drawn.set_shader_parameter("glow", ArtPalette.LAMP_GLASS)
			drawn.set_shader_parameter("emergency_glow", ArtPalette.EMERGENCY_GLASS)
		elif own.cull_mode == BaseMaterial3D.CULL_DISABLED:
			drawn.shader = TIN_SHADER
		else:
			drawn.shader = METAL_SHADER
		drawn.set_shader_parameter("albedo", own.albedo_color)
		drawn.set_shader_parameter("distance_fade_min", own.distance_fade_min_distance)
		drawn.set_shader_parameter("distance_fade_max", own.distance_fade_max_distance)
		mesh.surface_set_material(surface, drawn)
	return mesh
