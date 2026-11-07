class_name StillInstances
extends Node
## The instances of one dressed ship's art that never move under her (ShipArt.pack): her
## lamp-lit indoor chunks (PackedChunks) and her railings drawn apart from them
## (RailingBatches). Each stands apart from her node (top level), so her moving every
## frame spends no transform propagation or notification on any of them — the Titanic
## held 4,500 such meshes under each piece (#410) — and once a frame, just before the
## frame is drawn, one call sets every one's RenderingServer transform to where the
## ShipArt it hangs under now stands: what the node would have handed RenderingServer,
## her transform times its own, which is the identity. A stretch of her riding its piece
## once she has broken is a ShipArt of its own, so each piece's instances follow it.
## The call is the extension's (NativeStill) where it is loaded, else the GDScript's,
## handing RenderingServer the same transform, one instance at a time (the web). It places
## its groups too (StillGroup): instances hung each at its own transform under a node of
## her, her lamps' globes and her signs' letters, each where that node stands.

## Where it last placed them: none yet (NaN never equals itself), so the next frame does.
const UNPLACED := Transform3D(Basis(), Vector3.ONE * NAN)

## The instances held, their RenderingServer instances, and where they last were placed.
var _instances: Array[MeshInstance3D] = []
var _rids: Array[RID] = []
var _placed := UNPLACED
var _native: Object = ArtNative.made(&"NativeStill")
var _groups: Array[StillGroup] = []


func _init() -> void:
	name = "StillInstances"


## Stands each of [param instances], hung under this node's parent as the identity, apart
## from it, to be placed where it stands from now on. One hung any other way keeps
## following her as a node.
func take(instances: Array[MeshInstance3D]) -> void:
	for instance: MeshInstance3D in instances:
		if instance.transform != Transform3D.IDENTITY or instance.top_level:
			continue
		instance.top_level = true
		instance.transform = Transform3D.IDENTITY
		_instances.append(instance)
		_rids.append(instance.get_instance())
	if _native != null:
		_native.call(&"hold", _rids)
	_placed = UNPLACED


## The instances it places.
func held() -> Array[MeshInstance3D]:
	return _instances


## A new group of instances hung under [param frame], a node of her, placed with these.
func group(frame: Node3D) -> StillGroup:
	var made := StillGroup.new(frame)
	_groups.append(made)
	return made


## Its groups (group), in the order made.
func groups() -> Array[StillGroup]:
	return _groups


## Where it last placed them (UNPLACED before it first does).
func placed() -> Transform3D:
	return _placed


## Places every instance held where [param at] has its ShipArt, unless they stand there
## already; [param native] false places them with the GDScript, as the web does.
func place(at: Transform3D, native := true) -> void:
	if at == _placed:
		return
	_placed = at
	if native and _native != null:
		_native.call(&"place", at)
		return
	for rid: RID in _rids:
		RenderingServer.instance_set_transform(rid, at)


func _enter_tree() -> void:
	# Entering the world, each instance is handed its own node's transform: placed again.
	_placed = UNPLACED
	for each: StillGroup in _groups:
		each.unplace()
	if not RenderingServer.frame_pre_draw.is_connected(drawing):
		RenderingServer.frame_pre_draw.connect(drawing)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(drawing):
		RenderingServer.frame_pre_draw.disconnect(drawing)


## Places them for the frame about to be drawn, after every node has moved for it
## (RenderingServer.frame_pre_draw, never emitted while no window draws: headless).
func drawing() -> void:
	var art := get_parent() as Node3D
	if art != null and art.is_inside_tree():
		place(art.global_transform)
		for each: StillGroup in _groups:
			each.place()
