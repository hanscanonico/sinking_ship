extends GutTest
## A ship the dressed art does not draw — the trawler (SH30) — is drawn as the greybox
## her data makes, her hull the shell her structure's sections enclose (GreyboxHull):
## keel to sheer, end to end, her freeing ports and portholes marked through it.

const TRAWLER := "res://data/ships/trawler.tres"
## How far the drawn shell may stand off her sections' reach, in metres.
const NEAR := 0.05

var _layout: ShipLayout


func before_each() -> void:
	_layout = load(TRAWLER)


## Every mesh under [param root], in its ship space, as one box.
func _drawn(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for instance: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		var box := mesh.transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func test_her_hull_is_drawn_from_her_sections() -> void:
	assert_false(_layout.dressed, "the trawler is drawn from her data")
	var hull := GreyboxHull.new()
	add_child_autofree(hull)
	hull.build(_layout)
	var structure := _layout.structure
	var first := structure.sections[0]
	var last := structure.sections[structure.sections.size() - 1]
	var drawn := _drawn(hull)
	assert_almost_eq(drawn.position.x, first.x - first.length * 0.5, NEAR, "from her transom")
	assert_almost_eq(drawn.end.x, last.x + last.length * 0.5, NEAR, "to her stem")
	assert_almost_eq(drawn.position.y, structure.keel_y, NEAR, "down to her keel")
	var widest := 0.0
	for section: HullSection in structure.sections:
		for point: Vector2 in section.outline:
			widest = maxf(widest, absf(point.x))
	assert_almost_eq(drawn.end.z, widest, NEAR, "out to her widest")
	assert_almost_eq(drawn.position.z, -widest, NEAR, "either side")


func test_her_freeing_ports_and_portholes_are_marked() -> void:
	var hull := GreyboxHull.new()
	add_child_autofree(hull)
	hull.build(_layout)
	var marked := 0
	for opening: ShipOpening in _layout.structure.openings:
		if opening.kind in [ShipOpening.Kind.FREEING_PORT, ShipOpening.Kind.PORTHOLE]:
			marked += 1
	var marks := 0
	for child: Node in hull.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			marks += 1
	assert_gt(marked, 0, "she has freeing ports and portholes")
	assert_eq(marks, marked, "one mark at each")


func test_the_greybox_draws_her_hull_in_place_of_hull_blocks() -> void:
	var greybox := ShipGreybox.new()
	add_child_autofree(greybox)
	greybox.build(_layout, 1.0)
	var hulls := greybox.get_children().filter(
		func(child: Node) -> bool: return child is GreyboxHull
	)
	assert_eq(hulls.size(), 1)
