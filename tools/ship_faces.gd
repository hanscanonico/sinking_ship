extends RefCounted
## art-lint's view of the ship as drawn: every triangle a dressed ship's art draws, in her
## space — a packed art's (ShipArt.pack) as its unpacked one draws them, each lamp drawn
## together (LampGlobes) where it hangs.

const OpenSpanCheck := preload("res://tools/open_span_check.gd")


## Every triangle drawn under [param art], in the ship's space — those shown now
## alone when [param shown] says so. Into [param spans], when given, per triangle the
## railing span it is drawn under (ShipArt's "Railing<n>" nodes) or for (a packed art's
## RailingBatches), OpenSpanCheck.LAMP for a lamp's, or -1. Into [param hidden], when
## given, per triangle 1 when it is not shown now, else 0: the triangles it has 0 for
## are, in their order, the ones [param shown] alone gives, so one list read past its
## hidden ones stands in for both — a liner's is millions of triangles, and filing it
## (FaceCells) twice was a part's dearest step after her build.
static func of(
	art: Node3D, shown := false, spans := PackedInt32Array(), hidden := PackedByteArray()
) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var ship := art
	while ship != null and not ship is ShipArt:
		ship = ship.get_parent() as Node3D
	var batched: RailingBatches = (ship as ShipArt).railings() if ship != null else null
	var span_name := RegEx.create_from_string("^Railing(\\d+)$")
	for node: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var unseen := not mesh_instance.is_visible_in_tree()
		if shown and unseen:
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
		var drawn := batched.spans_of(mesh_instance) if batched != null else PackedInt32Array()
		if drawn.is_empty():
			_placed(to_ship, corners, span, unseen, faces, spans, hidden)
			continue
		# A batch of railings: each triangle its own span's, hidden as that span is.
		for triangle in drawn.size():
			var off := drawn[triangle] >= 0 and not batched.drawn(drawn[triangle])
			if shown and off:
				continue
			for corner in 3:
				faces.append(to_ship * corners[triangle * 3 + corner])
			spans.append(drawn[triangle])
			hidden.append(1 if unseen or off else 0)
	# The lamps a packed art draws together (ShipArt.pack), each where its lamp hangs.
	for node: Node in art.find_children("Globes", "Node3D", true, false):
		var globes := node as LampGlobes
		if globes == null or (shown and not globes.is_visible_in_tree()):
			continue
		var unseen := not globes.is_visible_in_tree()
		var to_ship := _to_ship(globes, ship)
		_placed(to_ship, globes.faces(), OpenSpanCheck.LAMP, unseen, faces, spans, hidden)
	return faces


## The triangles of [param corners], placed by [param to_ship], onto [param faces],
## and for each of them [param span] onto [param spans] and whether they are
## [param unseen] onto [param hidden], as of() has the three: whole arrays at a time.
static func _placed(
	to_ship: Transform3D,
	corners: PackedVector3Array,
	span: int,
	unseen: bool,
	faces: PackedVector3Array,
	spans: PackedInt32Array,
	hidden: PackedByteArray
) -> void:
	var count := corners.size() / 3
	faces.append_array(to_ship * corners)
	var theirs := PackedInt32Array()
	theirs.resize(count)
	theirs.fill(span)
	spans.append_array(theirs)
	var unseens := PackedByteArray()
	unseens.resize(count)
	unseens.fill(1 if unseen else 0)
	hidden.append_array(unseens)


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
