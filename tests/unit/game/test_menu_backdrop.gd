extends GutTest
## The ship behind the menus (MenuBackdrop): a screen hands its panel in each time it
## shows, a panel freed with its screen — a room left, an online match over — leaves
## her framing by itself, and she stands right of the widest panel still there. At the
## default window and the larger ones, beside the main menu's, the Online screen's or a
## room's panel and at every moment of her drift, her bow and her stern stay in the
## width right of the panel with a clear margin either side, and her masthead clear of
## the wordmark.

const MATCH_DATA := "res://data/match/default.tres"
const SETTINGS_PATH := "user://test_backdrop_online_settings.json"
## The windows she is framed in, and the canvas the UI scales to (canvas_items, expand).
const WINDOWS: Array[Vector2] = [Vector2(1152, 648), Vector2(1440, 900), Vector2(1920, 1080)]
const BASE := Vector2(1152, 648)
## The main menu's panel and its wordmark at the base canvas, as game.tscn lays them out
## (measured on a capture of the menu): the panel from x 64 to 520, the wordmark's
## title, livery and tagline inside this box.
const MAIN_PANEL := Vector2(64.0, 456.0)
const WORDMARK := Rect2(64.0, 40.0, 563.0, 160.0)
## The least share of the window's width kept clear either side of her.
const CLEAR := 0.03
## Moments of the drift looked at, end to end: finer than the backdrop frames her by.
const SWAYS := 65

var _backdrop: MenuBackdrop
## Her bow, her stern and her masthead: the drawn points furthest forward, aft and up.
var _ends := PackedVector3Array()


func before_all() -> void:
	_backdrop = MenuBackdrop.new()
	# As game.tscn has it: sized by its anchors, never by its render.
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_backdrop)
	_backdrop.size = BASE
	_backdrop.show_ship(load(MATCH_DATA))
	_backdrop.run(true)
	_ends = _drawn_ends()


func after_all() -> void:
	_backdrop.free()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


## The drawn points of her art furthest forward, aft and up, posed: every vertex of
## every mesh looked at.
func _drawn_ends() -> PackedVector3Array:
	var ship: Node3D = _backdrop.find_child("Ship", true, false)
	var into_ship := ship.global_transform.affine_inverse()
	var ends := PackedVector3Array([Vector3.INF * -1.0, Vector3.INF, Vector3.INF * -1.0])
	for node: Node in ship.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var place := into_ship * part.global_transform
		for corner: Vector3 in part.mesh.get_faces():
			var at := place * corner
			if at.x > ends[0].x:
				ends[0] = at
			if at.x < ends[1].x:
				ends[1] = at
			if at.y > ends[2].y:
				ends[2] = at
	for index in ends.size():
		ends[index] = ship.transform * ends[index]
	return ends


## A bare panel from [param from] across the canvas, [param width] wide, at its foot.
func _panel(from: float, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(from, 300.0)
	panel.custom_minimum_size = Vector2(width, 200.0)
	add_child_autofree(panel)
	return panel


func test_a_panel_handed_in_twice_is_framed_once() -> void:
	var panel := _panel(64.0, 456.0)
	_backdrop.frame_beside(panel)
	_backdrop.frame_beside(panel)
	assert_eq(_backdrop._beside.count(panel), 1)


func test_a_freed_panel_leaves_her_framing_and_she_drifts_on() -> void:
	var narrow := _panel(64.0, 456.0)
	var wide := _panel(64.0, 660.0)
	_backdrop.frame_beside(narrow)
	_backdrop._process(0.0)
	var beside_narrow := _backdrop._camera.transform
	_backdrop.frame_beside(wide)
	_backdrop._process(0.0)
	assert_ne(_backdrop._camera.transform, beside_narrow, "framed beside the wider panel")
	wide.free()
	assert_eq(_backdrop._beside.size(), 1, "the freed panel is gone")
	_backdrop._process(0.0)
	var now := _backdrop._camera.transform
	assert_almost_eq(now.origin, beside_narrow.origin, Vector3.ONE * 0.001, "beside the narrow one")
	_backdrop._process(5.0)
	assert_ne(_backdrop._camera.transform, now, "and the camera still drifts")


## Every window, beside each screen's panel as the screens come — the main menu's, the
## Online screen's, then a room's, each wider — through the drift: her bow and stern
## stand in the width right of the panel, CLEAR of it and of the window's right edge,
## and none of her near the wordmark.
func test_she_stands_whole_beside_every_screen_at_every_size() -> void:
	var viewport: SubViewport = _backdrop.get_child(0)
	for window: Vector2 in WINDOWS:
		var canvas := window / minf(window.x / BASE.x, window.y / BASE.y)
		_backdrop.size = canvas
		viewport.size = Vector2i(window)
		var online: OnlineMenu = load("res://scenes/online/online_menu.tscn").instantiate()
		online.settings_path = SETTINGS_PATH
		add_child(online)
		online.open()
		var room: RoomScreen = load("res://scenes/online/room_screen.tscn").instantiate()
		room.seats = 8
		add_child(room)
		room.show_room(_roster())
		await wait_frames(2)
		var main := _panel(MAIN_PANEL.x, MAIN_PANEL.y)
		var screens := {"the main menu": main, "Online": online.panel(), "a room": room.panel()}
		for screen: String in screens:
			var panel: Control = screens[screen]
			_backdrop.frame_beside(panel)
			var free_from := panel.get_global_rect().end.x / canvas.x
			var where := "beside %s at %s" % [screen, window]
			_check_drift(viewport, canvas, free_from, where)
		main.free()
		online.free()
		room.free()
		assert_eq(_backdrop._beside.size(), 0, "every panel gone with its screen")


func _check_drift(viewport: SubViewport, canvas: Vector2, free_from: float, where: String) -> void:
	var camera := _backdrop._camera
	var least := INF
	var most := -INF
	var on_wordmark := 0
	for index in SWAYS:
		camera.transform = _backdrop.view_at(lerpf(-1.0, 1.0, float(index) / (SWAYS - 1)))
		var seen := Rect2(camera.unproject_position(_ends[0]), Vector2.ZERO)
		for end in range(1, _ends.size()):
			seen = seen.expand(camera.unproject_position(_ends[end]))
		least = minf(least, seen.position.x / viewport.size.x)
		most = maxf(most, seen.end.x / viewport.size.x)
		var scale := canvas.x / viewport.size.x
		if Rect2(seen.position * scale, seen.size * scale).intersects(WORDMARK):
			on_wordmark += 1
	assert_gt(least, free_from + CLEAR, "%s: clear of the panel" % where)
	assert_lt(most, 1.0 - CLEAR, "%s: clear of the window's right edge" % where)
	assert_eq(on_wordmark, 0, "%s: moments she reaches the wordmark" % where)


static func _roster() -> RoomRoster:
	var roster := RoomRoster.new()
	roster.code = "KXRT"
	roster.you = 1
	for player: String in ["Ada", "Bea", "Bartholomew Fitz"]:
		roster.players.append(RoomRoster.Player.new(player, player == "Ada", false))
	return roster
