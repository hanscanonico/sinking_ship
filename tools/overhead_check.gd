class_name OverheadCheck
extends RefCounted
## `make art-lint`'s check of what hangs over the crew, in the match scene: through a
## seat's eyes no brawler draws anything wholly above its crown — the local seat's
## marker overhead is the observer camera's alone, as the first-person HUD names every
## seat there — and from the observer camera the local seat's marker stands over it.

const RunMatch := preload("res://tools/run_match.gd")
const MATCH_SCENE := "res://scenes/match/match.tscn"
## The seat whose eyes the first view looks through: any but the local seat, so the
## local seat is in the view.
const EYE_SEAT := 7
## Frames each view is watched for.
const FRAMES := 20


## The opening of the match of [param match_seed] with [param seats] seats, seen
## through EYE_SEAT's eyes and then from the observer camera: [problems found,
## checks made].
static func check(root: Window, match_seed: int, seats: int) -> Array:
	var problems := PackedStringArray()
	var checks := 0
	for observer: bool in [false, true]:
		var scene: MatchScene = (load(MATCH_SCENE) as PackedScene).instantiate()
		root.add_child(scene)
		scene.start(RunMatch.default_config(match_seed, seats), true, observer, EYE_SEAT)
		var driver: SimDriver = scene.get_node("SimDriver")
		var crown := driver.client.config.rules.body_height
		var view := "the observer camera" if observer else "seat %d's eyes" % EYE_SEAT
		# Per seat, the frames something of it stood over its crown, of those it was drawn.
		var over := {}
		var drawn := {}
		for _frame in FRAMES:
			await root.get_tree().process_frame
			for child: Node in scene.get_node("MatchView/Ship").get_children():
				var brawler := child as Brawler
				if brawler == null or not brawler.is_visible_in_tree():
					continue
				drawn[brawler.seat] = drawn.get(brawler.seat, 0) + 1
				if _over_crown(brawler, crown):
					over[brawler.seat] = over.get(brawler.seat, 0) + 1
		for seat: int in drawn:
			checks += 1
			var marked: bool = observer and seat == MatchScene.LOCAL_SEAT
			if marked and over.get(seat, 0) < drawn[seat]:
				problems.append("art-lint: no marker over the local seat from %s" % view)
			elif not marked and over.has(seat):
				problems.append(
					"art-lint: seat %d draws something over its head from %s" % [seat, view]
				)
		checks += 1
		if not drawn.has(MatchScene.LOCAL_SEAT):
			problems.append("art-lint: the local seat is not drawn from %s" % view)
		scene.queue_free()
		await root.get_tree().process_frame
	return [problems, checks]


## Whether anything [param brawler] draws stands wholly above [param crown], its
## body's height over its feet.
static func _over_crown(brawler: Brawler, crown: float) -> bool:
	var to_feet := brawler.global_transform.affine_inverse()
	for node: Node in brawler.find_children("*", "GeometryInstance3D", true, false):
		var drawn := node as GeometryInstance3D
		if drawn.is_visible_in_tree():
			var box := to_feet * (drawn.global_transform * drawn.get_aabb())
			if box.position.y > crown:
				return true
	return false
