class_name StillGroup
extends RefCounted
## Instances of one dressed ship's art hung straight under one node of her, its frame, each
## at its own transform under it and never moved there: her lamps' globes (LampGlobes) and
## the door signs' letters drawn near the eye (SignPool). Each stands apart from her (top
## level), so her moving every frame spends no transform notification on any of them, and
## StillInstances places them all just before each frame is drawn: each where Godot would
## have drawn it as a node, the frame's global transform times its own, multiplied as
## Node3D multiplies a child's (#410). The call is the extension's (NativeStill) where it
## is loaded, else the GDScript's, handing RenderingServer the same transforms.

## The node they hang under, which moves as she does.
var frame: Node3D
## The instances held, their RenderingServer instances and their own transforms.
var _instances: Array[GeometryInstance3D] = []
var _rids: Array[RID] = []
var _locals: Array[Transform3D] = []
## Where the frame stood when they were last placed: none yet (NaN never equals itself).
var _placed := StillInstances.UNPLACED
## Whether the extension holds the instances as they are now.
var _handed := false
var _native: Object = ArtNative.made(&"NativeStill")


func _init(under: Node3D) -> void:
	frame = under


## Stands [param instance], hung straight under the frame, apart from her, to be placed
## where it hangs from now on: its own transform kept as it was. Twice is once.
func hold(instance: GeometryInstance3D) -> void:
	assert(instance.get_parent() == frame, "hung straight under the frame")
	if instance in _instances:
		return
	var own := instance.transform
	instance.top_level = true
	instance.transform = own
	_instances.append(instance)
	_rids.append(instance.get_instance())
	_locals.append(own)
	_handed = false
	_placed = StillInstances.UNPLACED


## Lets [param instance] go: it follows the frame as a node again, hung as it was.
func release(instance: GeometryInstance3D) -> void:
	var at := _instances.find(instance)
	if at == -1:
		return
	_instances.remove_at(at)
	_rids.remove_at(at)
	_locals.remove_at(at)
	var own := instance.transform
	instance.top_level = false
	instance.transform = own
	_handed = false


## The instances held.
func held() -> Array[GeometryInstance3D]:
	return _instances


## Where the frame stood when they were last placed (StillInstances.UNPLACED before).
func placed() -> Transform3D:
	return _placed


## Where held instance [param index] was last placed: the frame's transform then, times
## its own.
func placed_of(index: int) -> Transform3D:
	return _placed * _locals[index]


## To be placed again on the next frame, wherever the frame stands: an instance entering
## the world is handed its node's own transform.
func unplace() -> void:
	_placed = StillInstances.UNPLACED


## Places every instance held where the frame now stands, unless it stood there when they
## were last placed; [param native] false places them with the GDScript, as the web does.
func place(native := true) -> void:
	if not frame.is_inside_tree():
		return
	var at := frame.global_transform
	if at == _placed:
		return
	_placed = at
	if native and _native != null:
		if not _handed:
			_native.call(&"hold_each", _rids, _locals)
			_handed = true
		_native.call(&"place", at)
		return
	for index in _rids.size():
		RenderingServer.instance_set_transform(_rids[index], at * _locals[index])
