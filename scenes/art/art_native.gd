class_name ArtNative
extends RefCounted
## The dressed ship's face emission in the game's extension (native/, #411): a ShipMesh
## hands its faces, quads and boxes to a NativeShipMesh, which cuts them, judges each
## piece indoors or out and gathers the batches, and an IndoorGrid its reads of her rooms
## to a NativeIndoorGrid — each to the same arrays bit for bit (test_ship_mesh_native).
## None where the extension is not loaded — the web, a checkout that never ran make
## native — and the GDScript draws them instead.

## Whether meshes and grids made from now on may use the extension: a test turns it off
## to draw the same ship with the GDScript alone.
static var allowed := true


## A new instance of the extension's class [param name], or null where it is not loaded
## or not [member allowed].
static func made(name: StringName) -> Object:
	if not allowed or not ClassDB.class_exists(name):
		return null
	return ClassDB.instantiate(name)
