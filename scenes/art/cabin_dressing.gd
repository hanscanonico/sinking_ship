class_name CabinDressing
extends RefCounted
## The passengers' rooms' own (RoomDressing), placed by rules on the layout: the
## fittings every cabin's walls take — a washstand under a mirror, a locker, curtains
## at the glass, a luggage shelf, a picture, a coat on a hook — and the dressing of a
## deckhouse cabin too narrow for furniture, with its berth folded up flat, and of a
## saloon. Each stands flat on its wall, within a fitting's depth, or over HEADROOM.

## How far along a wall either side of a pane's middle a fitting keeps clear of it,
## and how finely a wall is searched for a clear stretch.
const GLASS_CLEAR := 0.45
const CLEAR_STEP := 0.2
## How far apart a berth's chain's links stand.
const CHAIN_LINK := 0.045

var _space: ShipSpace


func _init(space: ShipSpace) -> void:
	_space = space


## A washstand flat on [param wall] at [param along]: a cabinet under a marble top
## with a white basin let into it, a brass tap and a jug, a towel on a rail, and a
## mirror over it.
static func washstand(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var floor := wall.floor
	var cabinet := wall.rect(along - 0.25, along + 0.25, 0.0, 0.08)
	RoomDressing.block(
		mesh, cabinet, floor + 0.25, floor + 0.86, ShipPaints.frame, ShipMesh.RIM_ALL
	)
	for side: float in [-1.0, 1.0]:
		var door := wall.at(along + side * 0.12, 0.55, 0.082)
		RoomDressing.panel(
			mesh, door, wall.right, Vector2(0.1, 0.24), wall.normal, ShipPaints.teak, 0
		)
	var marble := wall.rect(along - 0.28, along + 0.28, 0.0, 0.1)
	RoomDressing.block(mesh, marble, floor + 0.86, floor + 0.9, ShipPaints.enamel)
	var bowl := wall.at(along, 0.905, 0.05)
	RoomDressing.disc(mesh, bowl, Vector3.UP, 0.045, ShipPaints.mirror, 8)
	var tap := wall.at(along, 0.97, 0.03)
	mesh.turned_box(wall.place(tap), Vector3(0.03, 0.12, 0.04), ShipPaints.brass, 0)
	var jug := wall.at(along + 0.17, 0.9, 0.05)
	mesh.cylinder(Vector2(jug.x, jug.z), 0.045, jug.y, jug.y + 0.2, 8, ShipPaints.enamel, false)
	var mirror := wall.at(along, 1.55, 0.012)
	RoomDressing.panel(mesh, mirror, wall.right, Vector2(0.2, 0.25), wall.normal, ShipPaints.frame)
	var glass := mirror + wall.normal * 0.006
	RoomDressing.panel(mesh, glass, wall.right, Vector2(0.16, 0.21), wall.normal, ShipPaints.mirror)
	var rail := wall.at(along - 0.27, 0.75, 0.05)
	mesh.beam(rail, rail - wall.right * 0.25, Vector2.ONE * 0.015, ShipPaints.brass, 0)
	var towel := wall.at(along - 0.4, 0.62, 0.052)
	RoomDressing.panel(
		mesh, towel, wall.right, Vector2(0.1, 0.13), wall.normal, ShipPaints.linen, 0
	)


## A tall locker flat on [param wall] at [param along]: two panelled doors, louvred
## at the top, and a brass knob.
static func locker(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var body := wall.rect(along - 0.3, along + 0.3, 0.0, 0.08)
	RoomDressing.block(mesh, body, wall.floor, wall.floor + 1.9, ShipPaints.frame, ShipMesh.RIM_ALL)
	for side: float in [-1.0, 1.0]:
		var door := wall.at(along + side * 0.14, 0.95, 0.083)
		RoomDressing.panel(
			mesh, door, wall.right, Vector2(0.12, 0.85), wall.normal, ShipPaints.teak
		)
		for slat in 5:
			var louvre := wall.at(along + side * 0.14, 1.5 + slat * 0.06, 0.088)
			RoomDressing.panel(
				mesh, louvre, wall.right, Vector2(0.09, 0.008), wall.normal, ShipPaints.dark, 0
			)
	var knob := wall.at(along + 0.03, 1.0, 0.095)
	mesh.turned_box(wall.place(knob), Vector3.ONE * 0.03, ShipPaints.brass, 0)


## Curtains drawn back either side of the glass centred on [param centre] facing
## [param normal] into its room, under a brass rod, in [param paint].
static func curtains(
	mesh: ShipMesh, centre: Vector3, normal: Vector3, paint: ShipMesh.Paint
) -> void:
	var right := normal.cross(Vector3.UP).normalized()
	var rod := centre + Vector3.UP * 0.3 + normal * 0.04
	mesh.beam(rod - right * 0.38, rod + right * 0.38, Vector2.ONE * 0.016, ShipPaints.brass, 0)
	for side: float in [-1.0, 1.0]:
		for fold in 3:
			var at := centre + right * side * (0.24 + fold * 0.045) + Vector3.UP * 0.02
			var proud := 0.025 + 0.015 * (fold % 2)
			RoomDressing.panel(
				mesh, at + normal * proud, right, Vector2(0.024, 0.27), normal, paint, 0
			)


## A shelf over the doorway in [param wall], over head height, with a suitcase on it.
static func luggage_shelf(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	var middle := wall.middle()
	var low := wall.floor + 2.1
	RoomDressing.block(
		mesh, wall.rect(middle - 0.35, middle + 0.35, 0.0, 0.3), low, low + 0.03, ShipPaints.frame
	)
	var suitcase := wall.rect(middle - 0.24, middle + 0.24, 0.04, 0.27)
	RoomDressing.block(
		mesh, suitcase, low + 0.03, low + 0.21, ShipPaints.upholstery, ShipMesh.RIM_ALL
	)
	RoomDressing.block(mesh, suitcase.grow(0.006), low + 0.1, low + 0.13, ShipPaints.dark)


## A framed picture flat on [param wall] at [param along]: a seascape, a band of
## sky over a band of sea, in a dark frame.
static func picture(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var centre := wall.at(along, 1.45, 0.012)
	RoomDressing.panel(mesh, centre, wall.right, Vector2(0.24, 0.18), wall.normal, ShipPaints.frame)
	var sky := centre + wall.normal * 0.004 + Vector3.UP * 0.06
	RoomDressing.panel(mesh, sky, wall.right, Vector2(0.2, 0.08), wall.normal, ShipPaints.chart, 0)
	var sea := centre + wall.normal * 0.004 - Vector3.UP * 0.08
	RoomDressing.panel(
		mesh, sea, wall.right, Vector2(0.2, 0.06), wall.normal, ShipPaints.blanket, 0
	)
	# A steamer on the horizon: a dark hull under a buff funnel.
	var ship := centre + wall.normal * 0.007 - Vector3.UP * 0.01 - wall.right * 0.04
	RoomDressing.panel(
		mesh, ship, wall.right, Vector2(0.07, 0.012), wall.normal, ShipPaints.dark, 0
	)
	var stack := ship + Vector3.UP * 0.03 + wall.right * 0.01
	RoomDressing.panel(
		mesh, stack, wall.right, Vector2(0.008, 0.02), wall.normal, ShipPaints.mast, 0
	)


## A coat with a collar of [param paint] hanging from a hook on [param wall] at
## [param along]: narrow at the collar, its shoulders sloping and its skirt flaring
## to the hem, with some depth to it, its sleeves hanging at its sides and a row of
## buttons down its front.
static func coat(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, paint: ShipMesh.Paint
) -> void:
	var hook := wall.at(along, 1.75, 0.03)
	mesh.turned_box(wall.place(hook), Vector3(0.03, 0.06, 0.06), ShipPaints.brass, 0)
	# Its outline, (along, height) from the hook's foot, and how far out its back and
	# its front stand.
	var outline: Array[Vector2] = [
		Vector2(-0.07, 1.71),
		Vector2(0.07, 1.71),
		Vector2(0.18, 1.62),
		Vector2(0.22, 0.98),
		Vector2(-0.22, 0.98),
		Vector2(-0.18, 1.62),
	]
	var back := 0.02
	var front := 0.075
	var face := PackedVector3Array()
	for point: Vector2 in outline:
		face.append(wall.at(along + point.x, point.y, front))
	mesh.polygon(face, wall.normal, ShipPaints.leather, wall.floor + 0.98, NAN)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var out := Vector2(b.y - a.y, a.x - b.x).normalized()
		if out.dot(a + b - Vector2(0.0, 2.69)) < 0.0:
			out = -out
		mesh.quad(
			wall.at(along + a.x, a.y, front),
			wall.at(along + b.x, b.y, front),
			wall.at(along + b.x, b.y, back),
			wall.at(along + a.x, a.y, back),
			wall.right * out.x + Vector3.UP * out.y,
			ShipPaints.leather,
			0
		)
	for side: float in [-1.0, 1.0]:
		var shoulder := wall.at(along + side * 0.17, 1.6, front)
		var cuff := wall.at(along + side * 0.2, 1.12, front)
		var hang := (cuff - shoulder).normalized()
		var across := hang.cross(wall.normal).normalized()
		var sleeve := Transform3D(Basis(across, hang, wall.normal), (shoulder + cuff) * 0.5)
		var length := shoulder.distance_to(cuff)
		mesh.turned_box(sleeve, Vector3(0.08, length, 0.05), ShipPaints.leather)
		var band := Transform3D(sleeve.basis, cuff - hang * 0.03)
		mesh.turned_box(band, Vector3(0.085, 0.05, 0.055), paint, 0)
	var opening := wall.at(along, 1.32, front + 0.002)
	RoomDressing.panel(
		mesh, opening, wall.right, Vector2(0.004, 0.34), wall.normal, ShipPaints.dark, 0
	)
	for button in 3:
		var at := wall.at(along + 0.035, 1.5 - button * 0.14, front + 0.004)
		RoomDressing.disc(mesh, at, wall.normal, 0.013, ShipPaints.brass, 6)
	var collar := wall.at(along, 1.66, front + 0.003)
	RoomDressing.panel(mesh, collar, wall.right, Vector2(0.1, 0.05), wall.normal, paint)


## A cabin too narrow for furniture, the [param number]th: a berth folded up flat on
## the long wall with the longest clear stretch, a luggage rack over it and a picture
## between; a washstand and a coat on the wall across; curtains drawn back from each
## of [param glass]. Each stands flat on its wall or over HEADROOM, clear of whatever
## else stands in the room (a funnel's casing).
func cuddy(mesh: ShipMesh, room: ShipRoom, number: int, glass: Array[Array]) -> void:
	var finish := ShipMesh.Finish.PLAIN
	var blankets := ArtPalette.CABIN_BLANKETS
	var curtains := ArtPalette.CABIN_CURTAINS
	var blanket := ShipMesh.Paint.new(finish, blankets[(number + 3) % blankets.size()])
	var curtain := ShipMesh.Paint.new(finish, curtains[(number + 3) % curtains.size()])
	var along_x := room.area.size.x >= room.area.size.y
	var long: Array[RoomDressing.Wall] = []
	var clear: Array[Vector2] = []
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if (wall.side % 2 == 0) == along_x:
			long.append(wall)
			clear.append(_clear_stretch(wall, glass))
	if long.size() < 2:
		return
	var first := 0 if clear[0].y - clear[0].x >= clear[1].y - clear[1].x else 1
	var berth := long[first]
	var span := clear[first]
	if span.y - span.x >= RoomDressing.BERTH.x + 0.1:
		var middle := (span.x + span.y) * 0.5
		_folded_berth(
			mesh,
			berth,
			middle - RoomDressing.BERTH.x * 0.5,
			middle + RoomDressing.BERTH.x * 0.5,
			blanket
		)
		picture(mesh, berth, middle)
		_rack(mesh, berth, middle)
	var stand := long[1 - first]
	var other := clear[1 - first]
	var room_for := other.y - other.x
	var wash := other.y - 0.45 if number % 2 == 0 else other.x + 0.45
	if room_for >= 0.9:
		washstand(mesh, stand, wash)
	if room_for >= 1.5:
		coat(mesh, stand, other.x + 0.25 if number % 2 == 0 else other.y - 0.25, blanket)
	elif room_for >= 0.3 and room_for < 0.9:
		coat(mesh, stand, (other.x + other.y) * 0.5, blanket)
	for pane: Array in glass:
		curtains(mesh, pane[1], pane[2], curtain)


## The longest stretch (from, to) along [param wall] with nothing but floor standing
## before it up to HEADROOM, a fitting's depth out, and none of [param glass] (as
## RoomDressing.build has it) in it.
func _clear_stretch(wall: RoomDressing.Wall, glass: Array[Array]) -> Vector2:
	var best := Vector2.ZERO
	var start := NAN
	var count := maxi(1, ceili(wall.length() / CLEAR_STEP))
	var head := wall.floor + RoomDressing.HEADROOM
	# Most walls stand clear all along: then only their glass breaks them up.
	var whole := _space.clear(wall.rect(wall.from, wall.to, 0.0, 0.15), wall.floor, head)
	for index in count + 1:
		var along := lerpf(wall.from, wall.to, float(index) / count)
		var next := lerpf(wall.from, wall.to, float(index + 1) / count)
		var free := index < count
		if free and not whole:
			free = _space.clear(wall.rect(along, next, 0.0, 0.15), wall.floor, head)
		for pane: Array in glass:
			var across := wall.right.dot((pane[1] as Vector3) - wall.at(along, 0.0))
			if (pane[2] as Vector3).is_equal_approx(wall.normal) and absf(across) < GLASS_CLEAR:
				free = false
		if free and is_nan(start):
			start = along
		elif not free and not is_nan(start):
			if along - start > best.y - best.x:
				best = Vector2(start, along)
			start = NAN
	return best


## A berth folded up flat against [param wall] from [param a] to [param b] along it:
## its varnished underside in two panels on brass hinges, its bedding of
## [param blanket] showing over its top, held by two straps, on chains to the wall.
func _folded_berth(
	mesh: ShipMesh, wall: RoomDressing.Wall, a: float, b: float, blanket: ShipMesh.Paint
) -> void:
	var low := wall.floor + 0.42
	var high := wall.floor + 1.12
	RoomDressing.block(
		mesh, wall.rect(a, b, 0.0, 0.08), low, high, ShipPaints.frame, ShipMesh.RIM_ALL
	)
	var middle := (a + b) * 0.5
	var quarter := (b - a) * 0.25
	for side: float in [-1.0, 1.0]:
		var face := wall.at(middle + side * quarter, 0.77, 0.082)
		RoomDressing.panel(
			mesh, face, wall.right, Vector2(quarter - 0.07, 0.27), wall.normal, ShipPaints.teak
		)
		var hinge := middle + side * (quarter * 2.0 - 0.2)
		RoomDressing.block(
			mesh,
			wall.rect(hinge - 0.06, hinge + 0.06, 0.0, 0.09),
			low,
			low + 0.05,
			ShipPaints.brass
		)
		var strap := wall.at(middle + side * quarter * 1.3, 1.08, 0.091)
		RoomDressing.panel(
			mesh, strap, wall.right, Vector2(0.025, 0.12), wall.normal, ShipPaints.leather, 0
		)
		var end := middle + side * (quarter * 2.0 - 0.05)
		chain(mesh, wall.at(end, 1.1, 0.06), wall.at(end, 1.62, 0.012), wall.normal)
	var bedding := wall.rect(a + 0.04, b - 0.04, 0.0, 0.09)
	RoomDressing.block(mesh, bedding, high, high + 0.08, blanket, ShipMesh.RIM_ALL)


## A chain from [param from] to [param to], its links each turned a quarter from the
## last, the first flat to a wall facing [param normal].
static func chain(mesh: ShipMesh, from: Vector3, to: Vector3, normal: Vector3) -> void:
	var length := from.distance_to(to)
	var count := maxi(2, roundi(length / CHAIN_LINK))
	var along := (to - from) / length
	var flat := along.cross(normal).normalized()
	var edge := along.cross(flat).normalized()
	for link in count:
		var at := from.lerp(to, (link + 0.5) / count)
		var size := Vector3(0.022, length / count + 0.012, 0.006)
		var turn := Basis(flat, along, edge) if link % 2 == 0 else Basis(edge, along, flat)
		mesh.turned_box(Transform3D(turn, at), size, ShipPaints.steel, 0)


## A luggage rack over head height on [param wall] about [param along]: a shelf on two
## brackets, a strapped suitcase and a bundle on it.
func _rack(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var low := wall.floor + 2.05
	RoomDressing.block(
		mesh, wall.rect(along - 0.55, along + 0.55, 0.0, 0.28), low, low + 0.03, ShipPaints.frame
	)
	for end: float in [along - 0.45, along + 0.45]:
		RoomDressing.block(
			mesh, wall.rect(end - 0.012, end + 0.012, 0.0, 0.2), low - 0.1, low, ShipPaints.frame
		)
	var suitcase := wall.rect(along - 0.45, along + 0.05, 0.04, 0.26)
	RoomDressing.block(mesh, suitcase, low + 0.03, low + 0.2, ShipPaints.leather, ShipMesh.RIM_ALL)
	for strap: float in [along - 0.32, along - 0.08]:
		var band := wall.rect(strap - 0.015, strap + 0.015, 0.035, 0.265)
		RoomDressing.block(mesh, band, low + 0.03, low + 0.205, ShipPaints.dark)
	var bundle := wall.rect(along + 0.15, along + 0.42, 0.05, 0.25)
	RoomDressing.block(mesh, bundle, low + 0.03, low + 0.15, ShipPaints.linen)


## A saloon's own, against its walls: curtains at each of [param glass], a clock and
## pictures over the banquette on its longest inside wall with no stair beside it —
## clear of an opening's railing — and a sideboard under the glass of each short
## stretch of wall beside a doorway.
func saloon(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	var curtain := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.SALOON_CURTAIN)
	for pane: Array in glass:
		if not pane[3]:
			curtains(mesh, pane[1], pane[2], curtain)
	var longest: RoomDressing.Wall = null
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.length() >= 0.6 and wall.length() < 1.0 and wall.outdoors_beyond():
			var span := _clear_stretch(wall, [])
			if span.y - span.x >= 0.6:
				_sideboard(mesh, wall, (span.x + span.y) * 0.5)
		# Beside a stair down as well as up: a railing round its opening stands there.
		var stair := wall.rect(wall.from, wall.to, 0.0, 0.5)
		var floor := wall.floor
		if (
			wall.outdoors_beyond()
			or RoomDressing.over_a_ramp(_space.layout, stair, floor - 0.01, floor + 2.5)
		):
			continue
		if longest == null or wall.length() > longest.length():
			longest = wall
	if longest == null or longest.length() < 2.4:
		return
	var middle := longest.middle()
	var clock := longest.at(middle, 1.6, 0.03)
	RoomDressing.disc(mesh, clock, longest.normal, 0.14, ShipPaints.enamel, 14)
	RoomDressing.ring(
		mesh, clock + longest.normal * 0.004, longest.normal, 0.13, 0.17, ShipPaints.brass, 14
	)
	var hands := clock + longest.normal * 0.008
	mesh.beam(hands, hands + Vector3.UP * 0.1, Vector2(0.012, 0.004), ShipPaints.dark, 0)
	var minute := hands + (longest.right * 0.7 - Vector3.UP * 0.4).normalized() * 0.07
	mesh.beam(hands, minute, Vector2(0.012, 0.004), ShipPaints.dark, 0)
	for side: float in [-1.0, 1.0]:
		var along := middle + side * minf(1.1, longest.length() * 0.3)
		picture(mesh, longest, along)


## A sideboard flat on [param wall] at [param along]: a cabinet of two doors under a
## marble top, a decanter and a pair of glasses on it.
func _sideboard(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var floor := wall.floor
	var body := wall.rect(along - 0.3, along + 0.3, 0.0, 0.1)
	RoomDressing.block(mesh, body, floor, floor + 0.75, ShipPaints.frame, ShipMesh.RIM_ALL)
	for side: float in [-1.0, 1.0]:
		var door := wall.at(along + side * 0.14, 0.4, 0.102)
		RoomDressing.panel(
			mesh, door, wall.right, Vector2(0.12, 0.26), wall.normal, ShipPaints.teak
		)
		var knob := wall.place(door + wall.normal * 0.01 - wall.right * side * 0.09)
		mesh.turned_box(knob, Vector3.ONE * 0.025, ShipPaints.brass, 0)
	var top := wall.rect(along - 0.32, along + 0.32, 0.0, 0.11)
	RoomDressing.block(mesh, top, floor + 0.75, floor + 0.78, ShipPaints.enamel)
	var decanter := wall.at(along - 0.12, 0.78, 0.06)
	var spot := Vector2(decanter.x, decanter.z)
	mesh.cylinder(spot, 0.045, decanter.y, decanter.y + 0.15, 8, ShipPaints.mirror)
	mesh.cylinder(spot, 0.015, decanter.y + 0.15, decanter.y + 0.21, 6, ShipPaints.mirror)
	for index in 2:
		var cup := wall.at(along + 0.1 + index * 0.1, 0.78, 0.06)
		mesh.cylinder(Vector2(cup.x, cup.z), 0.025, cup.y, cup.y + 0.08, 6, ShipPaints.mirror)
