extends RefCounted
## `make art-lint`'s check of the openings a broken railing leaves (D6): a ship dressed
## with every railing breakable, then each span a body could pass broken in turn —
## through the opening it leaves, nothing is drawn across it but what the rules hold
## a body out of. It builds her art of its own, so a part of the lint (--part) can
## take it alone.

const StructureSteel := preload("res://tools/structure_steel.gd")
## A lamp's triangles' span in art-lint's faces (_ship_faces): it fades near the eye
## (ShipLamp.fade_near), so no lamp is a barrier.
const LAMP := -2
## Through a broken railing span: probes stand OPENING_STEP apart along it, at least
## OPENING_INSET in from its ends where the posts it shares and its remains stand,
## at heights OPENING_RISE apart; they start OPENING_INBOARD inboard of its line.
const OPENING_STEP := 0.4
const OPENING_INSET := 0.6
const OPENING_RISE := 0.15
const OPENING_INBOARD := 0.05


## [param layout] dressed with every railing breakable, then each span broken in
## turn: through the opening it leaves, from a step over its deck up to a body's
## height, no face is drawn across its line or out to a body's breadth past it —
## across it, or straight down over it — neither the hull, its ends, the fittings,
## its neighbours nor its own remains: the gap the rules leave open is open as drawn
## (D6). The art is built under [param root]; [param ship_faces] gathers the faces
## drawn under a node, and the railing span or LAMP each is drawn for (art-lint's
## _ship_faces); a face within [param blocker_tolerance] of a blocker is its own;
## [param file] names the ship: [problems found, checks made].
static func check(
	root: Window,
	file: String,
	layout: ShipLayout,
	rules: BrawlRules,
	ship_faces: Callable,
	blocker_tolerance: float
) -> Array:
	var problems := PackedStringArray()
	var checks := 0
	var art := ShipArt.new()
	root.add_child(art)
	var none: Array[StringName] = []
	var every := PackedInt32Array(range(layout.railings.size()))
	art.rules = rules
	art.build(layout, rules.railing_height, rules.body_radius, none, every)
	var spans := PackedInt32Array()
	var faces: PackedVector3Array = ship_faces.call(art, false, spans)
	var cells := FaceCells.file(faces)
	var breadth := rules.body_radius * 2.0
	var space := ShipSpace.new(layout)
	for index in layout.railings.size():
		checks += 1
		var railing := layout.railings[index]
		var platform := layout.platforms[railing.platform]
		var along := (railing.to - railing.from).normalized()
		var outward := along.orthogonal()
		if (platform.area.get_center() - railing.from).dot(outward) > 0.0:
			outward = -outward
		var low := platform.height + rules.step_height
		# A span too short for a body to pass leaves no opening to keep open, and so does
		# one with a wall within a body's radius behind it all along: no body stands there.
		var walled := Array(_along_span(railing)).all(
			func(at: Vector2) -> bool: return space.walled(at, -outward, low, rules.body_radius)
		)
		if walled or railing.from.distance_to(railing.to) < breadth:
			continue
		art.show_sinking(none, {}, PackedInt32Array([index]), false)
		var remains: PackedVector3Array = ship_faces.call(
			art.find_child("Railing%dRemains" % index, true, false) as Node3D
		)
		var high := platform.height + rules.body_height
		var segments: Array[PackedVector3Array] = []
		for point in _along_span(railing):
			var height := low
			while height <= high + 0.001:
				var from := point - outward * OPENING_INBOARD
				var to := point + outward * breadth
				segments.append(
					PackedVector3Array(
						[Vector3(from.x, height, from.y), Vector3(to.x, height, to.y)]
					)
				)
				height += OPENING_RISE
			var out := OPENING_STEP * 0.25
			while out <= breadth:
				var over := point + outward * out
				segments.append(
					PackedVector3Array(
						[Vector3(over.x, high, over.y), Vector3(over.x, low, over.y)]
					)
				)
				out += OPENING_STEP * 0.5
		for segment: PackedVector3Array in segments:
			if _blocked(faces, cells, spans, index, remains, segment, layout, blocker_tolerance):
				problems.append(
					(
						"art-lint: %s railing %d: drawn face across its opening, broken, on %s"
						% [file, index, segment]
					)
				)
				break
	art.free()
	return [problems, checks]


## Points along [param railing]'s line OPENING_STEP apart, OPENING_INSET in from
## its ends — its middle alone when it is too short for more.
static func _along_span(railing: ShipRailing) -> PackedVector2Array:
	var length := railing.from.distance_to(railing.to)
	var inset := minf(OPENING_INSET, length * 0.5)
	var count := floori((length - inset * 2.0) / OPENING_STEP)
	var points := PackedVector2Array()
	for step in count + 1:
		var share := 0.5 if count == 0 else (inset + (length - inset * 2.0) * step / count) / length
		points.append(railing.from.lerp(railing.to, share))
	return points


## Whether [param segment] (from, to) crosses a face of [param faces] — but those of
## span [param broken], per [param spans], a lamp's (LAMP), and [param layout]'s
## structure's own steel and its blockers' faces, within [param blocker_tolerance] of
## them (StructureSteel) — or one of [param remains].
static func _blocked(
	faces: PackedVector3Array,
	cells: Dictionary,
	spans: PackedInt32Array,
	broken: int,
	remains: PackedVector3Array,
	segment: PackedVector3Array,
	layout: ShipLayout,
	blocker_tolerance: float
) -> bool:
	var from := segment[0]
	var to := segment[1]
	for index in range(0, remains.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			from, to, remains[index], remains[index + 1], remains[index + 2]
		)
		if hit != null:
			return true
	var low := FaceCells.cell_of(Vector3(minf(from.x, to.x), 0.0, minf(from.z, to.z)))
	var high := FaceCells.cell_of(Vector3(maxf(from.x, to.x), 0.0, maxf(from.z, to.z)))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for index: int in cells.get(Vector2i(x, z), []):
				if spans[index / 3] == broken:
					continue
				var hit: Variant = Geometry3D.segment_intersects_triangle(
					from, to, faces[index], faces[index + 1], faces[index + 2]
				)
				if hit == null or StructureSteel.holds(layout, hit):
					continue
				if StructureSteel.in_a_blocker(layout, hit, blocker_tolerance):
					continue
				if spans[index / 3] != LAMP:
					return true
	return false
