extends SceneTree
## `make crew-capture`: every move a brawler is drawn in, side by side, saved as one
## PNG, so a change to the crew's rig, body or clips is seen at a glance. Each body
## is posed by Brawler.show_state from a snapshot entry of a fresh match, edited to
## stand in its move (D5), on a plain deck under a sun; nothing is played.
##
##   godot --path . -s res://tools/crew_gallery.gd -- --capture=PATH [--view=crew|arms|hats]
##
## crew: every move on one deck, seen from ahead and to the side, a seat's hat and
## coat apiece. arms: a seat's own arms (FirstPersonArms) through a first-person
## lens, one frame per move, laid out in a grid with the crosshair marked. hats: every
## hat close up on the head it seats on, from ahead and from behind, in a grid.

const RunMatch := preload("res://tools/run_match.gd")
const SEED := 1701
const SEATS := 8
## The seat whose arms the arms view shows.
const EYE_SEAT := 4
## How long each move is held before it is drawn, in seconds: a stride under way, a
## wind-up drawn back, a stagger's flinch landed.
const SETTLE := 0.5
const SPACING := 0.95
## The band of each frame kept in the crew's sheet, top to bottom, as shares of it.
const ROW_FROM := 0.12
const ROW_TO := 0.9
const PER_ROW := 7
const SKY := Color(0.55, 0.7, 0.85)
const DECK := Color(0.62, 0.5, 0.36)
## The arms view: each frame shrunk to this size in a grid this many across.
const CELL := Vector2i(576, 324)
const CELLS_ACROSS := 4
## The hats view: each head seen from HAT_DISTANCE metres, HAT_TURN radians off ahead
## and off behind, looking down from HAT_RISE over the crown, kept HAT_CELL square.
const HAT_DISTANCE := 1.0
const HAT_TURN := 0.6
const HAT_RISE := 0.25
const HAT_CELL := 480

var _path := ""
var _view := "crew"
var _rules: BrawlRules
var _entry: Dictionary
var _moves: Array = BrawlerAnimation.Move.values()
var _bodies: Array[Brawler] = []
var _arms: FirstPersonArms
var _camera: Camera3D
var _label: Label
var _move := 0
var _held := 0.0
var _sheet: Image
var _waiting := false
var _done := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--view="):
			_view = argument.trim_prefix("--view=")
	if _path.is_empty() or _view not in ["crew", "arms", "hats"]:
		push_error("crew_gallery: --capture=PATH and --view=crew|arms|hats")
		quit(1)
		return
	var config: MatchConfig = RunMatch.default_config(SEED, SEATS)
	_rules = config.rules
	_entry = MatchSim.create(config).snapshot()["seats"][0]
	_stage()
	if _view == "crew":
		_stage_crew()
	elif _view == "hats":
		_stage_hats()
	else:
		_stage_arms()


func _process(delta: float) -> bool:
	if _done or _waiting:
		return _done
	_held += delta
	if _view == "crew":
		for index in _bodies.size():
			if _bodies[index].visible:
				var entry := _as(_moves[index])
				_bodies[index].show_state(entry, entry, 1.0)
		if _held >= SETTLE:
			_snap()
	elif _view == "hats":
		var entry := _as(BrawlerAnimation.Move.IDLE)
		for body: Brawler in _bodies:
			body.show_state(entry, entry, 1.0)
		if _held >= SETTLE:
			_snap()
	else:
		var entry := _as(_moves[_move])
		_arms.show_seat(EYE_SEAT, entry, entry, 1.0)
		_label.text = BrawlerAnimation.Move.keys()[_moves[_move]].to_lower()
		if _held >= SETTLE:
			_snap()
	return false


## Saves the frame once it is drawn into the sheet: a row of the crew under the
## last, or one move's arms into the grid.
func _snap() -> void:
	_waiting = true
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if _view == "crew":
		_snap_row(image)
		return
	if _view == "hats":
		_snap_hat(image)
		return
	image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	if _sheet == null:
		var rows := ceili(float(_moves.size()) / CELLS_ACROSS)
		_sheet = Image.create(CELL.x * CELLS_ACROSS, CELL.y * rows, false, image.get_format())
		_sheet.fill(Color.BLACK)
	var at := Vector2i(_move % CELLS_ACROSS, _move / CELLS_ACROSS) * CELL
	_sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), at)
	_move += 1
	_held = 0.0
	_waiting = false
	if _move >= _moves.size():
		_save(_sheet)


func _snap_row(image: Image) -> void:
	var rows := ceili(float(_moves.size()) / PER_ROW)
	var size := image.get_size()
	var band := Rect2i(0, int(size.y * ROW_FROM), size.x, int(size.y * (ROW_TO - ROW_FROM)))
	if _sheet == null:
		_sheet = Image.create(band.size.x, band.size.y * rows, false, image.get_format())
	_sheet.blit_rect(image, band, Vector2i(0, band.size.y * _move))
	for index in _bodies.size():
		_bodies[index].visible = index / PER_ROW == _move + 1
	_move += 1
	_held = 0.0
	_waiting = false
	if _move >= rows:
		_save(_sheet)


## Keeps the middle of the frame, square, as the next head in the grid: every hat
## from ahead along the top row, from behind along the bottom.
func _snap_hat(image: Image) -> void:
	var size := image.get_size()
	var square := image.get_region(Rect2i((size.x - size.y) / 2, 0, size.y, size.y))
	square.resize(HAT_CELL, HAT_CELL, Image.INTERPOLATE_LANCZOS)
	var across := _bodies.size()
	if _sheet == null:
		_sheet = Image.create(HAT_CELL * across, HAT_CELL * 2, false, square.get_format())
	_sheet.blit_rect(
		square,
		Rect2i(0, 0, HAT_CELL, HAT_CELL),
		Vector2i(_move % across, _move / across) * HAT_CELL
	)
	_move += 1
	_held = 0.0
	_waiting = false
	if _move >= across * 2:
		_save(_sheet)
		return
	_aim_at_hat()


func _save(image: Image) -> void:
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var error := image.save_png(_path)
	if error != OK:
		push_error("crew_gallery: could not save %s" % _path)
	print("crew_gallery: saved %s" % _path)
	_done = true
	quit(0 if error == OK else 1)


## A sky, a sun and a deck.
func _stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = DECK
	plane.material = paint
	deck.mesh = plane
	root.add_child(deck)


## Every move on the deck, a row of them at a time, each turned three quarters to
## the eye.
func _stage_crew() -> void:
	for index in _moves.size():
		var body := Brawler.new()
		root.add_child(body)
		body.setup(index % SEATS, _rules, false)
		var column := index % PER_ROW
		body.position = Vector3((column - (PER_ROW - 1) * 0.5) * SPACING, 0.0, 0.0)
		body.rotation.y = -PI * 0.5 + 0.5
		body.visible = index < PER_ROW
		_bodies.append(body)
		var name := Label3D.new()
		name.text = BrawlerAnimation.Move.keys()[_moves[index]].to_lower()
		name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name.font_size = 40
		name.outline_size = 12
		name.position = Vector3(0.0, 2.1, 0.0)
		body.add_child(name)
	var camera := Camera3D.new()
	camera.fov = 30.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.9, 7.2), Vector3(0.0, 1.0, 0.0))


## Every hat on the head of the first seat that wears it, one head on the deck at a
## time.
func _stage_hats() -> void:
	for hat: Brawler.Hat in Brawler.Hat.values():
		var body := Brawler.new()
		root.add_child(body)
		body.setup(Brawler.HATS.find(hat), _rules, false)
		body.rotation.y = -PI * 0.5
		_bodies.append(body)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	root.add_child(_camera)
	_aim_at_hat()


## Shows the head the next frame is of and turns the eye on it: ahead of it, then
## behind it.
func _aim_at_hat() -> void:
	var across := _bodies.size()
	for index in across:
		_bodies[index].visible = index == _move % across
	var seat := _bodies[_move % across].seat
	var top := Brawler.headgear(seat, _rules)
	var head := Vector3(0.0, (_rules.body_height + top) * 0.5 - 0.1, 0.0)
	var turn := HAT_TURN if _move < across else PI - HAT_TURN
	var eye := head + Vector3(sin(turn), 0.0, cos(turn)) * HAT_DISTANCE + Vector3.UP * HAT_RISE
	_camera.look_at_from_position(eye, head)


## A first-person eye at a body's height, its own arms under it, the crosshair marked.
func _stage_arms() -> void:
	var camera := FirstPersonCamera.new()
	camera.setup(ViewSettings.new())
	root.add_child(camera)
	camera.position = Vector3(0.0, FirstPersonCamera.EYE_HEIGHT, 0.0)
	_arms = FirstPersonArms.new()
	camera.add_child(_arms)
	_arms.setup(_rules)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 40)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(cross)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 56)
	_label.add_theme_constant_override("outline_size", 12)
	_label.position = Vector2(24.0, 16.0)
	layer.add_child(_label)


## The fresh match's entry, standing still in [param move].
func _as(move: BrawlerAnimation.Move) -> Dictionary:
	var entry := _entry.duplicate()
	match move:
		BrawlerAnimation.Move.WALK:
			entry["vel"] = Vector3(1.2, 0.0, 0.0)
		BrawlerAnimation.Move.RUN:
			entry["vel"] = Vector3(4.5, 0.0, 0.0)
		BrawlerAnimation.Move.WINDUP:
			entry["action"] = PlayerState.Action.WINDUP
		BrawlerAnimation.Move.SHOVE:
			entry["action"] = PlayerState.Action.ACTIVE
		BrawlerAnimation.Move.RECOVER:
			entry["action"] = PlayerState.Action.RECOVERY
		BrawlerAnimation.Move.CHARGE:
			entry["action"] = PlayerState.Action.CHARGE
			entry["charge"] = Ticks.from_seconds(_rules.charge_full)
		BrawlerAnimation.Move.BRACE:
			entry["bracing"] = true
		BrawlerAnimation.Move.STAGGER:
			entry["stagger"] = 10
		BrawlerAnimation.Move.SWIM:
			entry["state"] = PlayerState.Body.SWIMMING
		BrawlerAnimation.Move.CLIMB:
			entry["state"] = PlayerState.Body.SWIMMING
			entry["climb"] = 10
		BrawlerAnimation.Move.FALL:
			entry["state"] = PlayerState.Body.AIRBORNE
		BrawlerAnimation.Move.JUMP:
			entry["state"] = PlayerState.Body.AIRBORNE
			entry["jumped"] = true
			entry["vel"] = Vector3(0.0, 3.0, 0.0)
	return entry
