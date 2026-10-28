class_name RoomDressing
extends RefCounted
## What makes each room of a ship its own (ShipArt), placed by rules on the layout,
## never by hand: the kind of room its shape says it is — the one answer, which
## ShipFittings asks too — the lining its walls, floor and ceiling take, the lamps it
## is lit by, and its fittings. An engine room of riveted steel over checker plate,
## its engine filling the block the rules hold bodies out of, boilers in its forward
## bulkhead with their fires glowing and their steam pipes overhead; a hold of rough
## timber, framed up its hull sides, its cargo stowed on a tween deck overhead under
## a net, lit by shaded cargo lamps; lower-deck cabins, each a little different, with
## a berth slung overhead, a washstand, a locker and curtains at the portholes, and
## the deckhouse's narrow cabins and saloon (CabinDressing, with the cabins' wall
## fittings); a corridor with handrails, a lifebelt and fire buckets; a wheelhouse
## panelled in teak with its wheel, binnacle, telegraph and chart against its walls
## (HelmDressing);
## the tables, benches, counters and ranges the layout stands on a room's floor, each
## drawn inside its box (FurnitureDressing);
## and over every doorway out of a corridor, an engine room or a hold, a plate naming
## the room beyond as the HUD does. Between a step over the floor and a body's
## height, where a body walks, nothing it draws stands out from a wall further than a
## fitting's depth — the rest stands in a blocker's footprint or over HEADROOM — and
## art-lint holds it to that.

## What a room is: by its name when that says, else by its shape and where it stands.
## A liner's rooms each take one of her own kinds, by name: a dining saloon, a public
## room, a grand staircase's landing, a first-class corridor, a room of the ship's
## service, a block of berths — each with its own dresser (LinerDining, LinerPublic,
## LinerCorridor, LinerService, LinerBerths); a boiler room, a bath, a squash court too
## (LinerBoiler, LinerBath, LinerSquash).
enum Kind {
	PASSAGE,
	CUDDY,
	ENGINE,
	HOLD,
	STEERAGE,
	HELM,
	SALOON,
	CABIN,
	DINING,
	PUBLIC,
	STAIRCASE,
	FIRST_CORRIDOR,
	SERVICE,
	BERTHS,
	BOILER,
	BATH,
	SQUASH,
	TANK,
	SHAFT,
	STEERING,
	LOCKER,
	VEHICLE,
}
## What of a room a face is: its walls, its floor, its ceiling, its beams.
enum Part { WALL, FLOOR, OVERHEAD, BEAM }

## A room narrower than CORRIDOR is a passage when it opens onto two rooms or more,
## else a cuddy too narrow for furniture; one below the main deck this big is a hold,
## a smaller one a cabin; one above it this big is a saloon, a smaller one a cabin,
## and the highest room, if small, the helm — but on a ship that names her wheelhouse,
## which is. A room whose name says what it is — the first of NAMED its name holds, any
## case, "officer" read as no "office" — is that, though: a liner's saloons stand
## below her main deck, and her holds' shape is a saloon's; a name says it ahead of the
## machinery a room holds, so a boiler room with its boilers is one. Her own kinds come
## first, so a "dining saloon" dines and a "deck corridor" is first class; the engine
## and boiler rooms, her baths and her court last, so "Scotland Road, boiler room 1" is
## a road.
const NAMED: Array[Array] = [
	["dining", Kind.DINING],
	["staircase", Kind.STAIRCASE],
	["deck corridor", Kind.FIRST_CORRIDOR],
	["berths", Kind.BERTHS],
	# Ahead of "office": the officers' quarters are berths, and so is a block of cabins
	# drawn as one room — the freighter's officers', crew's and forward cabins.
	["quarters", Kind.BERTHS],
	["cabins", Kind.BERTHS],
	# A liner's stateroom is a cabin, however big.
	["stateroom", Kind.CABIN],
	# A liner's small rooms of service, ahead of her public rooms' words, so the smoking
	# room's lavatory and the lounge's pantry are tiled too; the wireless's rooms and the
	# bridge's chart and navigating rooms are offices (LinerService.OFFICES); a vestibule
	# off a promenade a passage; her tank and machinery rooms bare, as a tank is.
	["lavatory", Kind.SERVICE],
	["pantry", Kind.SERVICE],
	["servery", Kind.SERVICE],
	["cloak room", Kind.SERVICE],
	["darkroom", Kind.SERVICE],
	["marconi room", Kind.SERVICE],
	["silent room", Kind.SERVICE],
	["chart room", Kind.SERVICE],
	["navigating room", Kind.SERVICE],
	["vestibule", Kind.PASSAGE],
	["tank room", Kind.TANK],
	["machinery room", Kind.TANK],
	["galley", Kind.SERVICE],
	["gymnasium", Kind.SERVICE],
	["office", Kind.SERVICE],
	["café", Kind.PUBLIC],
	["restaurant", Kind.PUBLIC],
	["lounge", Kind.PUBLIC],
	["smoking", Kind.PUBLIC],
	["reading", Kind.PUBLIC],
	["reception", Kind.PUBLIC],
	["entrance", Kind.PUBLIC],
	["general room", Kind.PUBLIC],
	["open space", Kind.PUBLIC],
	# The spaces in her old voids (#148, LowerSpaces): her stores are holds, and so are a
	# liner's coal bunkers; a peak's tank is a tank, the firemen's passage a passage.
	["double bottom", Kind.TANK],
	["side passage", Kind.TANK],
	["peak tank", Kind.TANK],
	["passage", Kind.PASSAGE],
	["shaft tunnel", Kind.SHAFT],
	["steering gear", Kind.STEERING],
	["chain locker", Kind.LOCKER],
	# A ferry's vehicle deck (VehicleDeck), no saloon for all its size.
	["car deck", Kind.VEHICLE],
	["store", Kind.HOLD],
	["bunker", Kind.HOLD],
	["engine", Kind.ENGINE],
	# Ahead of "hold": a stokehold is where her engine stands, no cargo hold.
	["stokehold", Kind.ENGINE],
	["hold", Kind.HOLD],
	["wheelhouse", Kind.HELM],
	["corridor", Kind.PASSAGE],
	["road", Kind.PASSAGE],
	["saloon", Kind.SALOON],
	["engine", Kind.ENGINE],
	["boiler", Kind.BOILER],
	# The Turkish bath and the swimming bath.
	["bath", Kind.BATH],
	["court", Kind.SQUASH],
]
const CORRIDOR := 1.8
const HOLD_AREA := 40.0
const SALOON_AREA := 15.0
## How high over its floor anything standing out from a wall begins: nobody's head
## goes there but in a jump.
const HEADROOM := 1.85
## How near the eye what stands over HEADROOM is gone, and from how near it starts
## to fade out (ship_near.gdshader, ShipLamp): a jumping head rises into it, and it
## would fill the view.
const NEAR_FADE := Vector2(0.3, 0.6)
const PIPE_SIDES := 8
## A passenger room longer or broader than this hangs a pendant under each square of
## this side it is cut into (lights()).
const LAMP_SPACING := 12.0
## A berth slung overhead: its length and its depth out from its wall.
const BERTH := Vector2(1.9, 0.7)
## Its model (assets/models), origin on the wall's face under its middle at HEADROOM,
## x along the wall with its head toward -x, z out of it; BERTH_RISE its top over its
## underside, and the eye on each end's cap its chain goes up from, along it from its
## middle, over its underside and out from the wall.
const BERTH_MODEL := "berth"
const BERTH_RISE := 0.46
const BERTH_EYE := Vector3(0.915, 0.46, 0.665)
## The modelled lifebelt, its middle on the wall's face facing +z: its ring's radius and
## how far out it stands; its grab line hangs no more than LIFEBELT_LINE past the ring.
const LIFEBELT_MODEL := "lifebelt"
const LIFEBELT_RADIUS := 0.33
const LIFEBELT_DEPTH := 0.075
const LIFEBELT_LINE := 0.08
## The modelled fire buckets in their rack, origin on the wall's face under the rack's
## middle at HEADROOM, x along the wall, z out of it; their box over all there.
const FIRE_BUCKETS_MODEL := "fire_buckets"
const FIRE_BUCKETS := AABB(Vector3(-0.45, 0.0, 0.0), Vector3(0.9, 0.275, 0.3))
## The wheelhouse's modelled fittings (assets/models): against its forward wall the
## wheel on its pedestal between the binnacle and the telegraph, and on its after wall
## the chart over its case — each with its origin on the floor at the wall's face under
## its middle, x along the wall, z out of it — and each one's box over all there, no
## deeper than a wall fitting.
const WHEEL_STAND_MODEL := "wheel_stand"
const WHEEL_STAND := AABB(Vector3(-0.69, 0.0, 0.0), Vector3(1.37, 1.41, 0.1))
const CHART_CASE_MODEL := "chart_case"
const CHART_CASE := AABB(Vector3(-0.5, 0.46, 0.0), Vector3(1.0, 1.29, 0.105))
## The modelled gauges and handwheels gauge() and wheel() draw, by the radius each is
## made for (variant()): a gauge's face's middle at its origin, its case reaching
## GAUGE_BACK behind it; a handwheel's hub at its origin, its spindle reaching
## HANDWHEEL_SPINDLE back; each facing +z.
const GAUGES := {0.085: "gauge_small"}
const GAUGE_BACK := 0.014
const HANDWHEELS := {0.15: "handwheel_large"}
const HANDWHEEL_SPINDLE := 0.05
## Wall decor modelled once and hung by several rooms (assets/models). The wall clock:
## its origin on the wall's face behind its dial's middle, facing +z (facing(), so it
## never reads mirrored); its bezel CLOCK_RADIUS round and nothing CLOCK_DEPTH out.
const CLOCK_MODEL := "clock"
const CLOCK_RADIUS := 0.16
const CLOCK_DEPTH := 0.045
## The brass sconce with its tulip shade: its origin on the wall's face at its back
## plate's middle, x along the wall, z out of it; nothing of it SCONCE_REACH out from
## the wall nor SCONCE_RISE over its origin.
const SCONCE_MODEL := "sconce_tulip"
const SCONCE_REACH := 0.1
const SCONCE_RISE := 0.15
## A pilaster's capital, by its width along its wall (variant()): its origin on the
## wall's face at its top's middle, under the ceiling, hanging down from there; each
## painted white, which its placing code swaps for its room's paint.
const CAPITALS := {0.32: "capital_32", 0.38: "capital_38"}
## The longest piece a furnishing's box is drawn in.
const PIECE := 1.5
## A sign over a doorway: its letters' size in pixels and the metres one stands for,
## and how high its plate stands over the floor.
const SIGN_FONT := 40
const SIGN_PIXEL := 0.0028
const SIGN_HEIGHT := 2.24


## A light a room is lit by (ShipLamp): where it hangs from its ceiling or burns in a
## wall, ship space, what it is, and which way a fire faces out of its wall.
class Light:
	var at: Vector3
	var kind: ShipLamp.Kind
	var facing: Vector3

	func _init(point: Vector3, lamp: ShipLamp.Kind, out := Vector3.DOWN) -> void:
		at = point
		kind = lamp
		facing = out


## One full wall along a side of a room, seen from inside it (ShipSpace.wall_runs):
## where a point along it, over the floor and out from its face stands.
class Wall:
	var room: ShipRoom
	var side: int
	## Along the side, the way it counts, from and to.
	var from: float
	var to: float
	var floor: float
	## Into the room, and along the wall the way it counts.
	var normal: Vector3
	var right: Vector3
	var _space: ShipSpace
	var _half: float

	func _init(space: ShipSpace, of: ShipRoom, run: Array) -> void:
		_space = space
		room = of
		side = run[0]
		from = run[1]
		to = run[2]
		_half = run[3]
		floor = of.floor_height
		var out := ShipSpace.outward(side)
		normal = Vector3(-out.x, 0.0, -out.y)
		right = Vector3.RIGHT if side % 2 == 0 else Vector3.BACK

	func middle() -> float:
		return (from + to) * 0.5

	func length() -> float:
		return to - from

	## Ship point [param along] it, [param height] over the floor, [param out] from
	## its face.
	func at(along: float, height: float, out := 0.0) -> Vector3:
		var point := _space.on_side(room, side, along, _half + out)
		return Vector3(point.x, floor + height, point.y)

	## The ship-plane rectangle [param a]…[param b] along it and [param near]…
	## [param far] out from its face.
	func rect(a: float, b: float, near: float, far: float) -> Rect2:
		var low := _space.on_side(room, side, a, _half + near)
		return Rect2(low, Vector2.ZERO).expand(_space.on_side(room, side, b, _half + far))

	## Turned to face into the room, at [param point].
	func place(point: Vector3) -> Transform3D:
		return Transform3D(Basis(right, Vector3.UP, normal), point)

	## Whether what stands beyond it, at a body's middle, is outdoors: the hull side.
	func outdoors_beyond() -> bool:
		var beyond := _space.on_side(room, side, middle(), -_half - ShipMesh.PROBE)
		return _space.outdoors(Vector3(beyond.x, floor + 1.0, beyond.y))

	## The end of it by side [param hull]: where along it the light of its portholes is.
	func end_by(hull: int) -> float:
		var low_side := 0 if side % 2 == 1 else 3
		return from if hull == low_side else to


var _space: ShipSpace
var _layout: ShipLayout
## Per room, its Kind.
var _kinds: Array[Kind] = []
## Per room, 1 for one that has a lining of its own, and that one's box from its floor
## to its highest ceiling.
var _has_lining := PackedByteArray()
var _lined_boxes: Array[AABB] = []
var _cut_above: float
var _engine: EngineRoom
var _hold: CargoHold
var _cabins: CabinDressing
var _dining: LinerDining
var _public: LinerPublic
var _corridor: LinerCorridor
var _service: LinerService
var _berths: LinerBerths
var _boiler: LinerBoiler
var _bath: LinerBath
var _squash: LinerSquash
var _helm: HelmDressing
var _lower: LowerSpaces
var _vehicle: VehicleDeck
## How many lower-deck cabins build() has dressed so far: the next one's number.
var _cabin_count := 0


## Reads [param space]'s rooms; no sign at or over [param cut_above], the observer's
## cut-away, is shown.
func _init(space: ShipSpace, cut_above := INF) -> void:
	_space = space
	_layout = space.layout
	_cut_above = cut_above
	_engine = EngineRoom.new(space)
	_hold = CargoHold.new(space)
	_cabins = CabinDressing.new(space)
	_dining = LinerDining.new(space, _cabins)
	_public = LinerPublic.new(space, _cabins)
	_corridor = LinerCorridor.new(space, _passage)
	_service = LinerService.new(space, _cabins)
	_berths = LinerBerths.new(space, _next_cabin)
	_boiler = LinerBoiler.new(_engine)
	_bath = LinerBath.new(space, _cabins)
	_squash = LinerSquash.new(space, _cabins)
	_helm = HelmDressing.new(space)
	_lower = LowerSpaces.new(space)
	_vehicle = VehicleDeck.new(space, cut_above)
	for room: ShipRoom in _layout.rooms:
		var kind := kind_of(space, room)
		_kinds.append(kind)
		var lined := not _linings(kind).is_empty()
		_has_lining.append(1 if lined else 0)
		_lined_boxes.append(_box_of(space, room) if lined else AABB())


## [param room]'s box on [param space], from its floor to the highest of its ceiling
## over its corners and its middle.
static func _box_of(space: ShipSpace, room: ShipRoom) -> AABB:
	var area := room.area.grow(-ShipSpace.INSIDE)
	var head := room.floor_height
	var corners: Array[Vector2] = [
		area.position,
		area.end,
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.position.y)
	]
	corners.append(area.get_center())
	for at: Vector2 in corners:
		head = maxf(head, space.ceiling(room, at.x, at.y))
	var foot := Vector3(room.area.position.x, room.floor_height, room.area.position.y)
	return AABB(foot, Vector3(room.area.size.x, head - room.floor_height, room.area.size.y))


## What [param room] is, by its name, else by the machinery standing in it, else by
## its shape and where it stands on [param space].
static func kind_of(space: ShipSpace, room: ShipRoom) -> Kind:
	var size := room.area.size
	var name := String(room.name).to_lower().replace("officer", "")
	for named: Array in NAMED:
		if name.contains(named[0]):
			return named[1]
	if space.machinery_in(room):
		return Kind.ENGINE
	if minf(size.x, size.y) < CORRIDOR:
		var doorways := 0
		var runs := space.wall_runs(room)
		for side in 4:
			for gap: Vector2 in _gaps(room, side, runs):
				doorways += 1 if _beyond(space, room, side, gap) != -1 else 0
		return Kind.PASSAGE if doorways >= 2 else Kind.CUDDY
	var top_floor := -INF
	var wheelhouse := false
	for other: ShipRoom in space.layout.rooms:
		top_floor = maxf(top_floor, other.floor_height)
		wheelhouse = wheelhouse or String(other.name).to_lower().contains("wheelhouse")
	var area := size.x * size.y
	if room.floor_height >= top_floor and area < SALOON_AREA and not wheelhouse:
		return Kind.HELM
	if room.floor_height < 0.0:
		return Kind.HOLD if area >= HOLD_AREA else Kind.STEERAGE
	return Kind.SALOON if area >= SALOON_AREA else Kind.CABIN


## The room of [param space], by index, ship point [param point] stands in; -1 for
## none.
static func room_at(space: ShipSpace, point: Vector3) -> int:
	for index: int in space.rooms_near(Rect2(point.x, point.z, 0.0, 0.0)):
		if _holds(space, space.layout.rooms[index], point):
			return index
	return -1


## Whether ship point [param point] stands in [param room] of [param space]: over its
## floor, under its ceiling.
static func _holds(space: ShipSpace, room: ShipRoom, point: Vector3) -> bool:
	var area := room.area
	if point.x < area.position.x or point.x > area.end.x:
		return false
	if point.z < area.position.y or point.z > area.end.y:
		return false
	if point.y < room.floor_height - ShipSpace.INSIDE:
		return false
	return point.y <= space.ceiling(room, point.x, point.z) + ShipSpace.INSIDE


## Whether [param piece] (ship space) stands wholly over HEADROOM in the room it is
## in, where only a jumping head comes near it: it fades out near the eye
## (NEAR_FADE). The rest stands flat on a wall or in a blocker's footprint.
func overhead(piece: AABB) -> bool:
	var room := room_at(_space, piece.get_center())
	if room == -1:
		return false
	return piece.position.y >= _layout.rooms[room].floor_height + HEADROOM - ShipMesh.SLIVER


## The paint [param part] of the room ship point [param point] stands in takes, when
## that room has a lining of its own; null otherwise.
func lining(point: Vector3, part: Part) -> ShipMesh.Paint:
	for index: int in _space.rooms_near(Rect2(point.x, point.z, 0.0, 0.0)):
		if _has_lining[index] == 1 and _holds(_space, _layout.rooms[index], point):
			return _linings(_kinds[index])[part]
	return null


## Whether [param box] (ship space) reaches into a room with a lining of its own.
func lined_near(box: AABB) -> bool:
	return not _lined_in(box).is_empty()


## Where each room with a lining of its own that [param box] (ship space) reaches into
## begins and ends, per axis x, y, z — none along y — each sorted: where a face over
## the box may be cut so each piece lies in one room's lining or none (LinedFaces).
func lining_lines(box: AABB) -> Array[PackedFloat32Array]:
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for index: int in _lined_in(box):
		var area := _layout.rooms[index].area
		xs.append_array([area.position.x, area.end.x])
		zs.append_array([area.position.y, area.end.y])
	xs.sort()
	zs.sort()
	var lines: Array[PackedFloat32Array] = [xs, PackedFloat32Array(), zs]
	return lines


## The rooms, by index, with a lining of their own that [param box] (ship space)
## reaches into.
func _lined_in(box: AABB) -> PackedInt32Array:
	var found := PackedInt32Array()
	var area := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	for index: int in _space.rooms_near(area):
		if _has_lining[index] == 1 and _lined_boxes[index].intersects(box):
			found.append(index)
	return found


## What [param kind] of room lines its walls, floor, ceiling and beams with, by Part
## (null keeps the ship's own); empty when it keeps the ship's own throughout.
static func _linings(kind: Kind) -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = []
	match kind:
		Kind.ENGINE:
			paints.assign([ShipPaints.bulkhead, ShipPaints.checker_plate])
			paints.append_array([ShipPaints.steel_overhead, ShipPaints.steel_beam])
		Kind.HOLD, Kind.TANK, Kind.LOCKER:
			paints.assign([ShipPaints.hold_wall, ShipPaints.hold_floor])
			paints.append_array([ShipPaints.hold_overhead, null])
		Kind.SHAFT, Kind.STEERING:
			paints.assign([ShipPaints.bulkhead, ShipPaints.checker_plate])
			paints.append_array([ShipPaints.steel_overhead, ShipPaints.steel_beam])
		Kind.HELM:
			paints.assign([ShipPaints.panelling, null, null, null])
		Kind.DINING:
			paints = LinerDining.linings()
		Kind.PUBLIC, Kind.STAIRCASE:
			paints = LinerPublic.linings()
		Kind.FIRST_CORRIDOR:
			paints = LinerCorridor.linings()
		Kind.SERVICE:
			paints = LinerService.linings()
		Kind.BERTHS:
			paints = LinerBerths.linings()
		Kind.BOILER:
			paints = LinerBoiler.linings()
		Kind.BATH:
			paints = LinerBath.linings()
		Kind.SQUASH:
			paints = LinerSquash.linings()
		Kind.VEHICLE:
			paints = VehicleDeck.linings()
	return paints


## The lights [param room] is lit by: a pendant under the middle of its ceiling — of
## each LAMP_SPACING square of a great room's — but in an engine room (EngineRoom), a
## hold (CargoHold) or a liner's room (LinerDining…) their own, when it has any.
func lights(room: ShipRoom) -> Array[Light]:
	var found: Array[Light] = []
	var area := room.area
	var middle := area.get_center()
	match _kinds[_layout.rooms.find(room)]:
		Kind.ENGINE:
			found = _engine.lights(room)
		Kind.HOLD:
			found = _hold.lights(room)
		Kind.DINING:
			found = _dining.lights(room)
		Kind.PUBLIC, Kind.STAIRCASE:
			found = _public.lights(room)
		Kind.FIRST_CORRIDOR:
			found = _corridor.lights(room)
		Kind.SERVICE:
			found = _service.lights(room)
		Kind.BERTHS:
			found = _berths.lights(room)
		Kind.BOILER:
			found = _boiler.lights(room)
		Kind.BATH:
			found = _bath.lights(room)
		Kind.SQUASH:
			found = _squash.lights(room)
	if found.is_empty():
		# A pendant under the middle of each LAMP_SPACING square of it: one in all but a
		# liner's great rooms.
		var across := Vector2i(
			maxi(1, ceili(area.size.x / LAMP_SPACING)), maxi(1, ceili(area.size.y / LAMP_SPACING))
		)
		for i in across.x:
			for j in across.y:
				var share := Vector2((i + 0.5) / across.x, (j + 0.5) / across.y)
				var at := area.position + area.size * share
				found.append(Light.new(under_ceiling(_space, room, at), ShipLamp.Kind.PENDANT))
	return found


## Every room's furnishings, into [param mesh]; its door signs' letters under
## [param signs]. [param panes] are ShipFittings' glass, each [room, centre, normal
## into the room, whether a porthole, its half size].
func build(mesh: ShipMesh, signs: Node3D, panes: Array[Array]) -> void:
	_cabin_count = 0
	var cuddy := 0
	for index in _layout.rooms.size():
		var room := _layout.rooms[index]
		var glass: Array[Array] = []
		for pane: Array in panes:
			if pane[0] == room:
				glass.append(pane)
		match _kinds[index]:
			Kind.ENGINE:
				_engine.build(mesh, room)
			Kind.HOLD:
				_hold.build(mesh, room)
			Kind.PASSAGE:
				_passage(mesh, room)
			Kind.STEERAGE:
				_next_cabin(mesh, room, glass)
			Kind.HELM:
				_helm.build(mesh, room, glass)
			Kind.CUDDY:
				_cabins.cuddy(mesh, room, cuddy, glass)
				cuddy += 1
			Kind.SALOON:
				_cabins.saloon(mesh, room, glass)
			Kind.CABIN:
				# A small room over the main deck: its berth is ShipFittings'.
				pass
			Kind.DINING:
				_dining.build(mesh, room, glass)
			Kind.PUBLIC, Kind.STAIRCASE:
				_public.build(mesh, room, glass)
			Kind.FIRST_CORRIDOR:
				_corridor.build(mesh, room, glass)
			Kind.SERVICE:
				_service.build(mesh, room, glass)
			Kind.BERTHS:
				_berths.build(mesh, room, glass)
			Kind.BOILER:
				_boiler.build(mesh, room, glass)
			Kind.BATH:
				_bath.build(mesh, room, glass)
			Kind.SQUASH:
				_squash.build(mesh, room, glass)
			Kind.TANK, Kind.SHAFT, Kind.STEERING, Kind.LOCKER:
				_lower.build(mesh, room, _kinds[index])
			Kind.VEHICLE:
				_vehicle.build(mesh, signs, room)
		# An engine room draws its machinery, a hold its cargo, a dining saloon its
		# tables (LinerDining.tables()), a bath its pool (LinerBath.build()) and the
		# spaces in her old voids their shaft, steering engine and chain bins
		# (LowerSpaces); every other room's furniture is FurnitureDressing's.
		var own := [Kind.ENGINE, Kind.HOLD, Kind.DINING, Kind.BATH]
		if _kinds[index] not in own + [Kind.SHAFT, Kind.STEERING, Kind.LOCKER]:
			FurnitureDressing.build(mesh, room, _space.furniture(room))
		var signed := [Kind.ENGINE, Kind.BOILER, Kind.HOLD, Kind.PASSAGE, Kind.FIRST_CORRIDOR]
		if _kinds[index] in signed:
			_signs(mesh, signs, room)


## The next lower-deck cabin, [param room] with [param glass]: _cabin() numbered on
## from the last, a liner's berths (LinerBerths) counted with the rest.
func _next_cabin(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	_cabin(mesh, room, _cabin_count, glass)
	_cabin_count += 1


## [param room]'s full walls on [param space] (ShipSpace.wall_runs), each a Wall.
static func walls(space: ShipSpace, room: ShipRoom) -> Array[Wall]:
	var found: Array[Wall] = []
	for run: Array in space.wall_runs(room):
		found.append(Wall.new(space, room, run))
	return found


## Fire buckets in their rack over head height on [param wall] at [param along]
## (FIRE_BUCKETS_MODEL), turned square to the wall so their lettering reads.
static func fire_buckets(mesh: ShipMesh, wall: Wall, along: float) -> void:
	var place := Transform3D(facing(wall.normal), wall.at(along, HEADROOM))
	mesh.model(ShipModel.named(FIRE_BUCKETS_MODEL), place)


## A lower-deck cabin, the [param number]th: a berth slung overhead along one of the
## walls between it and the next, its blanket in the cabin's own colour; a washstand
## under a mirror on the other, by the hull side, and a locker by the door; curtains
## drawn back from each of [param glass]; and by turns a shelf with a suitcase over
## the door, a picture or a coat on a hook.
func _cabin(mesh: ShipMesh, room: ShipRoom, number: int, glass: Array[Array]) -> void:
	var blankets := ArtPalette.CABIN_BLANKETS
	var curtains := ArtPalette.CABIN_CURTAINS
	var finish := ShipMesh.Finish.PLAIN
	var blanket := ShipMesh.Paint.new(finish, blankets[number % blankets.size()])
	var curtain := ShipMesh.Paint.new(finish, curtains[number % curtains.size()])
	var around := walls(_space, room)
	var hull := -1
	var door := -1
	for wall: Wall in around:
		if wall.outdoors_beyond():
			hull = wall.side
	var runs := _space.wall_runs(room)
	for side in 4:
		if side == hull:
			continue
		for gap: Vector2 in _gaps(room, side, runs):
			if _beyond(_space, room, side, gap) != -1:
				door = side
	var sides: Array[Wall] = []
	for wall: Wall in around:
		if wall.side != hull and wall.side != door and wall.length() >= BERTH.x + 0.1:
			sides.append(wall)
	if hull == -1 or door == -1 or sides.size() < 2:
		return
	var berth := sides[number % 2]
	var stand := sides[(number + 1) % 2]
	var head := berth.end_by(hull)
	var way := 1.0 if is_equal_approx(head, berth.from) else -1.0
	slung_berth(mesh, _space, berth, head + way * 0.02, way, blanket)
	var wash := stand.end_by(hull)
	var by_door := stand.to - 0.4
	if wash == stand.from:
		CabinDressing.washstand(mesh, stand, wash + 0.45)
	else:
		CabinDressing.washstand(mesh, stand, wash - 0.45)
		by_door = stand.from + 0.4
	CabinDressing.locker(mesh, stand, by_door)
	for pane: Array in glass:
		CabinDressing.curtains(mesh, pane[1], pane[2], curtain)
	match number % 3:
		0:
			for wall: Wall in around:
				if wall.side == door and wall.length() >= 0.8:
					CabinDressing.luggage_shelf(mesh, wall)
					break
		1:
			var free := berth.to - 0.5 if berth.end_by(hull) == berth.from else berth.from + 0.5
			CabinDressing.picture(mesh, berth, free)
		2:
			var away := -0.7 if berth.end_by(hull) > berth.middle() else 0.7
			CabinDressing.coat(mesh, berth, berth.middle() + away, blanket)


## The room of [param space], by index, through the gap [param gap] along
## [param side] of [param room]; -1 for none.
static func _beyond(space: ShipSpace, room: ShipRoom, side: int, gap: Vector2) -> int:
	var beyond := space.on_side(room, side, (gap.x + gap.y) * 0.5, -0.3)
	return room_at(space, Vector3(beyond.x, room.floor_height + 1.0, beyond.y))


## The gaps along [param side] of [param room] between its full walls, [param runs]
## (ShipSpace.wall_runs), at least a doorway wide, as (from, to) along it.
static func _gaps(room: ShipRoom, side: int, runs: Array) -> Array[Vector2]:
	var along_x := side % 2 == 0
	var low := room.area.position.x if along_x else room.area.position.y
	var high := room.area.end.x if along_x else room.area.end.y
	var edges := PackedFloat32Array([low + 0.1])
	for run: Array in runs:
		if run[0] == side:
			edges.append_array([run[1], run[2]])
	edges.append(high - 0.1)
	edges.sort()
	var gaps: Array[Vector2] = []
	for index in range(0, edges.size() - 1, 2):
		if edges[index + 1] - edges[index] >= 0.6:
			gaps.append(Vector2(edges[index], edges[index + 1]))
	return gaps


## A berth slung overhead along [param wall] of [param space] (BERTH_MODEL), its head
## at [param head] along it and its foot BERTH.x toward [param way] (1 or -1) from it,
## over HEADROOM, its blanket in [param blanket]; a chain from each end's eye up to the
## deckhead over it.
static func slung_berth(
	mesh: ShipMesh, space: ShipSpace, wall: Wall, head: float, way: float, blanket: ShipMesh.Paint
) -> void:
	var middle := head + way * BERTH.x * 0.5
	var turn := Basis(wall.right * way, Vector3.UP, wall.normal)
	var place := Transform3D(turn, wall.at(middle, HEADROOM))
	mesh.model(ShipModel.named(BERTH_MODEL), place, {ShipPaints.blanket: blanket})
	for end: float in [-1.0, 1.0]:
		var hook := wall.at(middle + end * BERTH_EYE.x, HEADROOM + BERTH_EYE.y, BERTH_EYE.z)
		var ceiling := space.ceiling(wall.room, hook.x, hook.z) - ShipArt.PLANK
		mesh.beam(hook, Vector3(hook.x, ceiling, hook.z), Vector2.ONE * 0.016, ShipPaints.steel, 0)


## The corridor's own: a handrail along each long wall, sloping up its stairs; a
## lifebelt on its longest stretch clear of a stair, fire buckets on a shelf
## overhead across from it, clear of what stands under it (FurnitureDressing.clear_along).
func _passage(mesh: ShipMesh, room: ShipRoom) -> void:
	var along_x := room.area.size.x >= room.area.size.y
	var longest: Wall = null
	var around := walls(_space, room)
	for wall: Wall in around:
		if (wall.side % 2 == 0) != along_x or wall.length() < 0.5:
			continue
		_handrail(mesh, wall)
		if _stair_beside(wall) or (longest != null and wall.length() <= longest.length()):
			continue
		longest = wall
	if longest == null:
		return
	lifebelt(mesh, longest.at(longest.middle(), 1.35), longest.normal)
	var pieces := _space.furniture(room)
	var size := FIRE_BUCKETS.size
	for wall: Wall in around:
		if wall.side == (longest.side + 2) % 4 and wall.length() >= 1.0:
			var along := FurnitureDressing.clear_along(wall, pieces, size.x, size.z)
			if not _stair_beside(wall) and not is_nan(along):
				fire_buckets(mesh, wall, along)
				return


## The stretches of [param run] along [param wall] clear of every stair of
## [param layout] climbing within [param reach] of it, where a body on the stair would
## stand in what hangs on the wall over a floor's head height, and [param margin] past
## either end of it; none shorter than [param reach].
static func clear_of_stairs(
	layout: ShipLayout, wall: Wall, run: Vector2, reach: float, margin := 0.0
) -> Array[Vector2]:
	var runs: Array[Vector2] = [run]
	var near := wall.rect(wall.from, wall.to, 0.0, reach)
	for ramp: ShipRamp in layout.ramps:
		if not ramp.area.intersects(near):
			continue
		var cut := Vector2(ramp.area.position.x, ramp.area.end.x)
		if wall.side % 2 == 1:
			cut = Vector2(ramp.area.position.y, ramp.area.end.y)
		cut += Vector2(-margin, margin)
		var left: Array[Vector2] = []
		for stretch: Vector2 in runs:
			if cut.y <= stretch.x or cut.x >= stretch.y:
				left.append(stretch)
				continue
			if cut.x - stretch.x >= reach:
				left.append(Vector2(stretch.x, cut.x))
			if stretch.y - cut.y >= reach:
				left.append(Vector2(cut.y, stretch.y))
		runs = left
	return runs


## Whether a stair stands beside [param wall] anywhere along it.
func _stair_beside(wall: Wall) -> bool:
	var area := wall.rect(wall.from, wall.to, 0.0, 0.5)
	return over_a_ramp(_layout, area, wall.floor, wall.floor + 2.5)


## Whether [param area] reaches over any ramp of [param layout] standing between
## [param low] and [param high].
static func over_a_ramp(layout: ShipLayout, area: Rect2, low: float, high: float) -> bool:
	for ramp: ShipRamp in layout.ramps:
		var top := maxf(ramp.start_height, ramp.end_height)
		if ramp.area.intersects(area) and ramp.base() < high and top > low:
			return true
	return false


## A teak handrail on brass brackets along [param wall], at a hand's height over the
## floor or over a stair beside it — straight between where a stair begins and ends —
## stopping short of the wall's top.
func _handrail(mesh: ShipMesh, wall: Wall) -> void:
	var top := wall.floor + 2.4
	var stops := PackedFloat32Array([wall.from + 0.1, wall.to - 0.1])
	for ramp: ShipRamp in _layout.ramps:
		var span := Vector2(ramp.area.position.x, ramp.area.end.x)
		if wall.side % 2 == 1:
			span = Vector2(ramp.area.position.y, ramp.area.end.y)
		for at: float in [span.x, span.y]:
			if at > wall.from + 0.1 and at < wall.to - 0.1:
				stops.append(at)
	stops.sort()
	var rail := PackedVector3Array()
	for along: float in stops:
		rail.append(_hand_height(wall, along))
	for index in rail.size() - 1:
		var from := rail[index]
		var to := rail[index + 1]
		if from.y > top and to.y > top:
			continue
		if to.y > top:
			to = from.lerp(to, (top - from.y) / (to.y - from.y))
		elif from.y > top:
			from = to.lerp(from, (top - to.y) / (from.y - to.y))
		var pieces := ceili(from.distance_to(to) / PIECE)
		for piece in pieces:
			var start := from.lerp(to, float(piece) / pieces)
			var end := from.lerp(to, float(piece + 1) / pieces)
			mesh.beam(start, end, Vector2(0.045, 0.05), ShipPaints.teak, 0)
		var brackets := maxi(1, floori(from.distance_to(to)))
		for bracket in brackets + 1:
			var at := from.lerp(to, float(bracket) / brackets) - wall.normal * 0.045
			var box := Rect2(Vector2(at.x, at.z) - Vector2.ONE * 0.02, Vector2.ONE * 0.04)
			block(mesh, box, at.y - 0.095, at.y - 0.025, ShipPaints.brass)


## Where [param wall]'s handrail runs at [param along] it: 0.065 out from its face, a
## hand's height over the floor, or over a stair beside it.
func _hand_height(wall: Wall, along: float) -> Vector3:
	var at := wall.at(along, 0.0, 0.065)
	var foot := Vector2(at.x, at.z) + Vector2(wall.normal.x, wall.normal.z) * 0.1
	var surface := wall.floor
	for ramp: ShipRamp in _layout.ramps:
		if ramp.contains(foot.x, foot.y):
			surface = maxf(surface, ramp.height_at(foot.x, foot.y))
	return Vector3(at.x, surface + 0.92, at.z)


## A lifebelt hung flat on a wall at [param centre], facing [param normal]
## (LIFEBELT_MODEL): a red ring with four white bands and its grab line.
static func lifebelt(mesh: ShipMesh, centre: Vector3, normal: Vector3) -> void:
	mesh.model(ShipModel.named(LIFEBELT_MODEL), Transform3D(facing(normal), centre))


## A plate over every doorway of [param room] onto another room, on the doorway's
## head, naming the room beyond as the HUD names it: an enamel plate in a brass rim
## in [param mesh], its letters a Label3D under [param signs].
func _signs(mesh: ShipMesh, signs: Node3D, room: ShipRoom) -> void:
	var font := ThemeDB.fallback_font
	var runs := _space.wall_runs(room)
	for side in 4:
		for gap: Vector2 in _gaps(room, side, runs):
			var other := _beyond(_space, room, side, gap)
			if other == -1:
				continue
			var text := String(_layout.rooms[other].name).capitalize()
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT).x
			var half := Vector2(width * SIGN_PIXEL * 0.5 + 0.05, 0.075)
			var out := ShipSpace.outward(side)
			var normal := Vector3(-out.x, 0.0, -out.y)
			var right := Vector3.RIGHT if side % 2 == 0 else Vector3.BACK
			var at := _space.on_side(room, side, (gap.x + gap.y) * 0.5, 0.1)
			var centre := Vector3(at.x, room.floor_height + SIGN_HEIGHT, at.y)
			var rim := half + Vector2.ONE * 0.012
			panel(mesh, centre + normal * 0.01, right, rim, normal, ShipPaints.brass)
			panel(mesh, centre + normal * 0.014, right, half, normal, ShipPaints.enamel)
			var letters := Label3D.new()
			letters.text = text
			letters.font_size = SIGN_FONT
			letters.pixel_size = SIGN_PIXEL
			letters.modulate = ArtPalette.INK
			letters.outline_size = 0
			letters.shaded = true
			letters.double_sided = false
			letters.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			letters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Gone with its plate as a jumping eye comes near (NEAR_FADE).
			letters.visibility_range_begin = (NEAR_FADE.x + NEAR_FADE.y) * 0.5
			letters.basis = Basis.looking_at(-normal)
			letters.position = centre + normal * 0.02
			letters.visible = centre.y < _cut_above
			signs.add_child(letters)


## Ship point under [param room]'s ceiling on [param space] over [param at], at its
## deck's underside: where a lamp hangs from.
static func under_ceiling(space: ShipSpace, room: ShipRoom, at: Vector2) -> Vector3:
	return Vector3(at.x, space.ceiling(room, at.x, at.y) - ShipArt.PLANK, at.y)


## A flat panel centred on [param centre], [param half] (along [param right], up)
## from it, facing [param normal], the edges [param rims] names darkened.
static func panel(
	mesh: ShipMesh,
	centre: Vector3,
	right: Vector3,
	half: Vector2,
	normal: Vector3,
	paint: ShipMesh.Paint,
	rims := ShipMesh.RIM_ALL
) -> void:
	var x := right * half.x
	var y := Vector3.UP * half.y
	mesh.quad(centre - x - y, centre + x - y, centre + x + y, centre - x + y, normal, paint, rims)


## A box over [param area] from [param bottom] to [param top], uncut — a
## furnishing, not a wall a room's lines cross — the edges [param rims] names darkened
## on each face, none on a part too small for a bevel to show. One without rims, a
## beam or a board, is drawn in pieces no longer than PIECE, so no mesh it joins
## outgrows its chunk (ShipMesh); a rimmed one is furniture, short enough whole.
static func block(
	mesh: ShipMesh, area: Rect2, bottom: float, top: float, paint: ShipMesh.Paint, rims := 0
) -> void:
	if rims != 0:
		var centre := Vector3(area.get_center().x, (bottom + top) * 0.5, area.get_center().y)
		var size := Vector3(area.size.x, top - bottom, area.size.y)
		mesh.turned_box(Transform3D(Basis.IDENTITY, centre), size, paint, rims)
		return
	var along_x := area.size.x >= area.size.y
	var pieces := maxi(1, ceili((area.size.x if along_x else area.size.y) / PIECE))
	var cut := area.size / Vector2(pieces, 1.0) if along_x else area.size / Vector2(1.0, pieces)
	var step := Vector2(cut.x, 0.0) if along_x else Vector2(0.0, cut.y)
	var size := Vector3(cut.x, top - bottom, cut.y)
	for piece in pieces:
		var middle := Rect2(area.position + step * piece, cut).get_center()
		var centre := Vector3(middle.x, (bottom + top) * 0.5, middle.y)
		mesh.turned_box(Transform3D(Basis.IDENTITY, centre), size, paint, 0)


## Two unit vectors across [param normal]: right and up on a face turned to it.
static func across(normal: Vector3) -> Array[Vector3]:
	var right := normal.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var axes: Array[Vector3] = [right, right.cross(normal).normalized()]
	return axes


## A flat disc of [param radius] centred on [param centre] facing [param normal], in
## [param segments]; its paint's bands from [param foot].
static func disc(
	mesh: ShipMesh,
	centre: Vector3,
	normal: Vector3,
	radius: float,
	paint: ShipMesh.Paint,
	segments: int,
	foot := NAN
) -> void:
	var axes := across(normal)
	var ring := PackedVector3Array()
	for index in segments:
		var angle := TAU * index / segments
		ring.append(centre + (axes[0] * cos(angle) + axes[1] * sin(angle)) * radius)
	mesh.polygon(ring, normal, paint, centre.y - radius if is_nan(foot) else foot, NAN)


## A flat ring from [param inner] to [param outer] round [param centre], facing
## [param normal].
static func ring(
	mesh: ShipMesh,
	centre: Vector3,
	normal: Vector3,
	inner: float,
	outer: float,
	paint: ShipMesh.Paint,
	segments: int
) -> void:
	var axes := across(normal)
	for index in segments:
		var turn := TAU * index / segments
		var next := TAU * (index + 1) / segments
		var a := axes[0] * cos(turn) + axes[1] * sin(turn)
		var b := axes[0] * cos(next) + axes[1] * sin(next)
		var c := centre
		mesh.quad(c + a * inner, c + b * inner, c + b * outer, c + a * outer, normal, paint, 0)


## A gauge of [param radius] at [param centre] facing [param normal]: a white face in a
## brass case, with its needle and its stem — GAUGES' model made for that radius.
static func gauge(mesh: ShipMesh, centre: Vector3, normal: Vector3, radius: float) -> void:
	mesh.model(ShipModel.named(variant(GAUGES, radius)), Transform3D(facing(normal), centre))


## A handwheel of [param radius] round [param hub] facing [param normal], its spindle
## reaching HANDWHEEL_SPINDLE back: HANDWHEELS' model made for that radius, whose own
## are its thickness, its spokes and its paints.
static func wheel(mesh: ShipMesh, hub: Vector3, normal: Vector3, radius: float) -> void:
	mesh.model(ShipModel.named(variant(HANDWHEELS, radius)), Transform3D(facing(normal), hub))


## The model of [param variants] (a radius each is made for: its name) made for
## [param radius]: the largest made no bigger, else the smallest.
static func variant(variants: Dictionary, radius: float) -> String:
	var best := -1.0
	var smallest := INF
	for made: float in variants:
		smallest = minf(smallest, made)
		if made <= radius + ShipMesh.SLIVER and made > best:
			best = made
	return variants[best if best >= 0.0 else smallest]


## A turn that faces a model's +z along [param normal], its +y up it as across() has
## it: a gauge's face or a handwheel's hub.
static func facing(normal: Vector3) -> Basis:
	var up := across(normal)[1]
	return Basis(up.cross(normal), up, normal)


## A pipe of [param radius] from [param from] to [param to], round in PIPE_SIDES
## smooth facets, open at its ends, in pieces no longer than PIECE (block()).
static func pipe(
	mesh: ShipMesh, from: Vector3, to: Vector3, radius: float, paint := ShipPaints.steel
) -> void:
	var length := from.distance_to(to)
	if length < ShipMesh.SLIVER:
		return
	var pieces := ceili(length / PIECE)
	if pieces > 1:
		for piece in pieces:
			var start := from.lerp(to, float(piece) / pieces)
			pipe(mesh, start, from.lerp(to, float(piece + 1) / pieces), radius, paint)
		return
	var axis := (to - from) / length
	var x := axis.cross(Vector3.UP)
	if x.length_squared() < 0.01:
		x = axis.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := axis.cross(x).normalized()
	for index in PIPE_SIDES:
		var turn := TAU * index / PIPE_SIDES
		var next := TAU * (index + 1) / PIPE_SIDES
		var na := x * cos(turn) + y * sin(turn)
		var nb := x * cos(next) + y * sin(next)
		var corners := [from + na * radius, from + nb * radius, to + nb * radius, to + na * radius]
		mesh.smooth_quad(PackedVector3Array(corners), PackedVector3Array([na, nb, nb, na]), paint)


## A pipe's flange at [param at] across [param axis]: a short, wider brass collar.
static func flange(mesh: ShipMesh, at: Vector3, axis: Vector3, radius: float) -> void:
	pipe(mesh, at - axis * 0.025, at + axis * 0.025, radius + 0.025, ShipPaints.brass)
