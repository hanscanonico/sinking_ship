class_name WaterSheet
extends MeshInstance3D
## A sheet of an opening's pour in her water (InnerWater): the pour itself, its crossing
## through a deck's hole or a porthole, or the froth where it lands. It keeps what it was
## last handed, and a frame hands it only what changed — the Titanic draws about 50 pours
## a frame (#410), and a value the same as the frame before costs her renderer nothing
## then. What it draws is what it would draw were everything handed again
## (test_water_sheet): nothing else sets what it keeps.

## Before anything is handed: NaN never equals itself, so the first of each is set.
const UNSET := Transform3D(Basis(), Vector3.ONE * NAN)

## As last handed: where it stands under her, its extent, how hard it pours, how far it
## is thrown — or, laid, how far through its burst — and how much the sky lights it.
var _placed := UNSET
var _extent := Vector2(NAN, NAN)
var _strength := NAN
var _thrown := Vector3(NAN, NAN, NAN)
var _burst := NAN
var _outdoor := NAN


## Hangs it as [param basis] at [param middle], pouring as hard as [param strength] says,
## thrown out of its opening by its foot by [param thrown] in its own units
## (spill.gdshader), lit by the sky by [param outdoor].
func hang(basis: Basis, middle: Vector3, strength: float, thrown: Vector3, outdoor: float) -> void:
	_stand(Transform3D(basis, middle))
	var material := material_override as ShaderMaterial
	var extent := Vector2(basis.x.length(), basis.y.length())
	if extent != _extent:
		_extent = extent
		material.set_shader_parameter(&"extent", extent)
	if strength != _strength:
		_strength = strength
		material.set_shader_parameter(&"strength", strength)
	if thrown != _thrown:
		_thrown = thrown
		material.set_shader_parameter(&"thrown", thrown)
	if outdoor != _outdoor:
		_outdoor = outdoor
		material.set_shader_parameter(&"outdoor", outdoor)
	visible = true


## Lays it flat as [param basis] at [param at], boiling as hard as [param strength] says —
## a burst of air [param burst] of the way through, or below 0 for a pour's landing
## (froth.gdshader).
func lay(basis: Basis, at: Vector3, strength: float, burst: float) -> void:
	_stand(Transform3D(basis, at))
	var material := material_override as ShaderMaterial
	var extent := Vector2(basis.x.length(), basis.z.length())
	if extent != _extent:
		_extent = extent
		material.set_shader_parameter(&"extent", extent)
	if strength != _strength:
		_strength = strength
		material.set_shader_parameter(&"strength", strength)
	if burst != _burst:
		_burst = burst
		material.set_shader_parameter(&"burst", burst)
	visible = true


## Forgets what it was handed: the next hang or lay hands it everything.
func forget() -> void:
	_placed = UNSET
	_extent = Vector2(NAN, NAN)
	_strength = NAN
	_thrown = Vector3(NAN, NAN, NAN)
	_burst = NAN
	_outdoor = NAN


## Stands it at [param placed] under her, on her again if it stood apart (InnerWater._stow):
## standing apart, its own transform was rewritten to keep it where it stood in the
## world, so it is set again.
func _stand(placed: Transform3D) -> void:
	if top_level:
		top_level = false
		_placed = UNSET
	if placed != _placed:
		_placed = placed
		transform = placed
