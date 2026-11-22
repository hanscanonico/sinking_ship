extends SceneTree
func _init() -> void:
	var name := "steamer"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ship="):
			name = a.trim_prefix("--ship=")
	var l: ShipLayout = load("res://data/ships/%s.tres" % name)
	print("PLATFORMS")
	for i in l.platforms.size():
		var p := l.platforms[i]
		print("  %d %s x %.1f..%.1f z %.1f..%.1f h %.1f" % [i, p.name, p.area.position.x, p.area.end.x, p.area.position.y, p.area.end.y, p.height])
	print("ROOMS")
	for r in l.rooms:
		print("  %s x %.1f..%.1f z %.1f..%.1f floor %.1f" % [r.name, r.area.position.x, r.area.end.x, r.area.position.y, r.area.end.y, r.floor_height])
	print("RAMPS")
	for r in l.ramps:
		print("  x %.1f..%.1f z %.1f..%.1f axis %d h %.1f -> %.1f" % [r.area.position.x, r.area.end.x, r.area.position.y, r.area.end.y, r.axis, r.start_height, r.end_height])
	print("LADDERS")
	for r in l.ladders:
		print("  plat %d from %s to %s" % [r.platform, r.from, r.to])
	print("BLOCKERS")
	for b in l.blockers:
		if b.shape == 0:
			print("  %s x %.2f..%.2f z %.2f..%.2f y %.1f..%.1f" % [b.name, b.area.position.x, b.area.end.x, b.area.position.y, b.area.end.y, b.bottom, b.top])
		else:
			print("  %s c %s r %.2f y %.1f..%.1f" % [b.name, b.centre, b.radius, b.bottom, b.top])
	quit()
