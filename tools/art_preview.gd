extends SceneTree
## `make preview`'s first half: SHIP's art dressed headless as the menu's backdrop
## dresses her (ArtGltf), written as a vertex-coloured glTF binary for
## tools/art_preview.py to render in Blender — the visual check that needs no game
## window. --span=x0,x1 keeps only the stretch along her from x0 aft to x1 fore, in
## ship space; --cut=H cuts her away at and above that height, as `make capture CUT=`
## does.
##
##   godot --headless --path . -s res://tools/art_preview.gd -- --ship=steamer \
##       --out=captures/preview/steamer.glb [--span=-20,10] [--cut=6]

const RunMatch := preload("res://tools/run_match.gd")


func _initialize() -> void:
	var ship_name := ""
	var out := ""
	var cut := INF
	var span := Vector2(-INF, INF)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="):
			ship_name = arg.trim_prefix("--ship=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--cut="):
			cut = float(arg.trim_prefix("--cut="))
		elif arg.begins_with("--span="):
			var ends := arg.trim_prefix("--span=").split(",")
			if ends.size() != 2 or not ends[0].is_valid_float() or not ends[1].is_valid_float():
				push_error("art_preview: --span=x0,x1 takes two numbers, not %s" % arg)
				quit(1)
				return
			span = Vector2(float(ends[0]), float(ends[1]))
	var layout := Fleet.layout(StringName(ship_name))
	if layout == null or out.is_empty():
		printerr("art_preview: --ship=<a ship of the fleet> and --out=<.glb> are required")
		quit(1)
		return
	var config := RunMatch.default_config(RunMatch.DEFAULT_SEED, 0, StringName(ship_name))
	var art := ArtGltf.dressed(layout, config.rules, cut)
	var holder := ArtGltf.flattened(art, "Ship_%s" % ship_name, span)
	art.free()
	var error := ArtGltf.write(holder, out)
	var meshes := holder.get_child_count()
	holder.free()
	print("art_preview: %s, %d meshes, %s -> %s" % [ship_name, meshes, error_string(error), out])
	quit(0 if error == OK and meshes > 0 else 1)
