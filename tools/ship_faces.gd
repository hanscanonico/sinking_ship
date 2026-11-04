extends RefCounted
## art-lint's view of the ship as drawn: every triangle a dressed ship's art draws, in her
## space — a packed art's (ShipArt.pack) as its unpacked one draws them, each lamp drawn
## together (LampGlobes) where it hangs.

const OpenSpanCheck := preload("res://tools/open_span_check.gd")


## Every triangle drawn under [param art], in the ship's space — those shown now
## alone when [param shown] says so. Into [param spans], when given, per triangle the
## railing span it is drawn under (ShipArt's "Railing<n>" nodes), OpenSpanCheck.LAMP
## for a lamp's, or -1.
static func of(art: Node3D, shown := false, spans := PackedInt32Array()) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var ship := art
	while ship != null and not ship is ShipArt:
		ship = ship.get_parent() as Node3D
	var span_name := RegEx.create_from_string("^Railing(\\d+)$")
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if shown and not mesh_instance.is_visible_in_tree():
			continue
		var span := -1
		var up := mesh_instance.get_parent()
		while up != null and up != ship:
			var found := span_name.search(up.name)
			if found != null:
				span = found.get_string(1).to_int()
			if up is ShipLamp:
				span = OpenSpanCheck.LAMP
			up = up.get_parent()
		var to_ship := _to_ship(mesh_instance, ship)
		var corners := mesh_instance.mesh.get_faces()
		for corner: Vector3 in corners:
			faces.append(to_ship * corner)
		for _triangle in corners.size() / 3:
			spans.append(span)
	# The lamps a packed art draws together (ShipArt.pack), each where its lamp hangs.
	for node: Node in art.find_children("Globes", "Node3D", true, false):
		var globes := node as LampGlobes
		if globes == null or (shown and not globes.is_visible_in_tree()):
			continue
		var to_ship := _to_ship(globes, ship)
		var drawn := globes.faces()
		for corner: Vector3 in drawn:
			faces.append(to_ship * corner)
		for _triangle in drawn.size() / 3:
			spans.append(OpenSpanCheck.LAMP)
	return faces


## Where [param node] stands in [param ship]'s space: each node up to her as it hangs, a
## node hidden apart from her as it hung (ShipArt.show_apart).
static func _to_ship(node: Node3D, ship: Node3D) -> Transform3D:
	var place := Transform3D.IDENTITY
	var up := node
	while up != null and up != ship:
		var hung: Transform3D = up.transform
		if up.top_level:
			hung = up.get_meta(ShipArt.HUNG_AT, up.transform)
		place = hung * place
		up = up.get_parent_node_3d()
	return place
