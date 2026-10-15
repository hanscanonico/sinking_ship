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
## The modelled fittings (assets/models/README.md), each with its origin on the floor at
## its wall's face under its middle, x along the wall (Wall.right), z out of it, and
## each one's box over all there: no deeper than a wall fitting under HEADROOM, a
## shelf's depth over it.
const WASHSTAND_MODEL := "washstand"
const WASHSTAND := AABB(Vector3(-0.51, 0.25, 0.0), Vector3(0.79, 1.55, 0.1))
const LOCKER_MODEL := "locker"
const LOCKER := AABB(Vector3(-0.31, 0.0, 0.0), Vector3(0.62, 1.9, 0.1))
const LUGGAGE_SHELF_MODEL := "luggage_shelf"
const LUGGAGE_SHELF := AABB(Vector3(-0.35, 1.94, 0.0), Vector3(0.7, 0.38, 0.3))
const LUGGAGE_RACK_MODEL := "luggage_rack"
const LUGGAGE_RACK := AABB(Vector3(-0.55, 1.89, 0.0), Vector3(1.1, 0.37, 0.28))
## The coat's model, its origin under its hook, its collar and cuffs painted blanket
## for its cabin's colour.
const COAT_MODEL := "coat"
const COAT := AABB(Vector3(-0.245, 0.98, 0.0), Vector3(0.49, 0.77, 0.095))
## The folded berths _folded_berth draws, by the length each is made for
## (RoomDressing.variant()), never one model stretched, its bedding painted blanket for
## its cabin's colour; and each one's box but for its length.
const FOLDED_BERTHS := {1.9: "folded_berth_190"}
const FOLDED_BERTH := AABB(Vector3(0.0, 0.41, 0.0), Vector3(0.0, 1.22, 0.1))
## The sideboards a saloon and a dining saloon stand, by the length along its wall of
## the top each is made for (RoomDressing.variant()), never one model stretched; and the
## box over all of the saloon's, a decanter on its top.
const SIDEBOARDS := {0.64: "sideboard_64", 1.8: "sideboard_180"}
const SIDEBOARD := AABB(Vector3(-0.32, 0.0, 0.0), Vector3(0.64, 0.99, 0.11))

var _space: ShipSpace


func _init(space: ShipSpace) -> void:
	_space = space


## A washstand flat on [param wall] at [param along] (WASHSTAND_MODEL): a cabinet
## under a marble top with a basin and a jug on it, a towel on a rail beside it, and a
## mirror over it.
static func washstand(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	mesh.model(ShipModel.named(WASHSTAND_MODEL), wall.place(wall.at(along, 0.0)))


## A tall locker flat on [param wall] at [param along] (LOCKER_MODEL): two panelled
## doors, louvred at the top, each with a brass knob.
static func locker(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	mesh.model(ShipModel.named(LOCKER_MODEL), wall.place(wall.at(along, 0.0)))


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


## A shelf over the doorway in [param wall], over head height, with a suitcase on it
## (LUGGAGE_SHELF_MODEL).
static func luggage_shelf(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	mesh.model(ShipModel.named(LUGGAGE_SHELF_MODEL), wall.place(wall.at(wall.middle(), 0.0)))


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


## A coat with a collar and cuffs of [param paint] hanging from a hook on [param wall]
## at [param along] (COAT_MODEL): narrow at the collar, its shoulders sloping and its
## skirt flaring to the hem, its sleeves hanging at its sides and a row of buttons down
## its front.
static func coat(
	mesh: ShipMesh, wall: RoomDressing.Wall, along: float, paint: ShipMesh.Paint
) -> void:
	var place := wall.place(wall.at(along, 0.0))
	mesh.model(ShipModel.named(COAT_MODEL), place, {ShipPaints.blanket: paint})


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


## A berth folded up flat against [param wall] from [param a] to [param b] along it,
## FOLDED_BERTHS' model for that length: its varnished underside in two panels on
## brass hinges, its bedding of [param blanket] showing over its top, held by two
## straps, on chains to the wall.
func _folded_berth(
	mesh: ShipMesh, wall: RoomDressing.Wall, a: float, b: float, blanket: ShipMesh.Paint
) -> void:
	var model := ShipModel.named(RoomDressing.variant(FOLDED_BERTHS, b - a))
	mesh.model(model, wall.place(wall.at((a + b) * 0.5, 0.0)), {ShipPaints.blanket: blanket})


## A luggage rack over head height on [param wall] about [param along]
## (LUGGAGE_RACK_MODEL): a shelf on two brackets, a strapped suitcase and a rolled
## blanket on it.
func _rack(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	mesh.model(ShipModel.named(LUGGAGE_RACK_MODEL), wall.place(wall.at(along, 0.0)))


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


## A sideboard flat on [param wall] at [param along] (SIDEBOARDS' made for
## SIDEBOARD's length): two cupboard doors under two drawers under a marble top, a
## brass gallery rail along its back, a decanter and a pair of glasses on it.
func _sideboard(mesh: ShipMesh, wall: RoomDressing.Wall, along: float) -> void:
	var sideboard := RoomDressing.variant(SIDEBOARDS, SIDEBOARD.size.x)
	mesh.model(ShipModel.named(sideboard), wall.place(wall.at(along, 0.0)))
