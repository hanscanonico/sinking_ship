extends GutTest
## ship_bake.gd's arguments: a project-relative path is read under res://, and an
## absolute one — a POSIX path, or a Windows drive path such as bake-check's Blender
## export into the temp folder — is read as it stands.

const ShipBake := preload("res://tools/ship_bake.gd")


func test_a_relative_path_is_read_under_the_project() -> void:
	assert_eq(ShipBake._res("authoring/steamer/steamer.tscn"), "res://authoring/steamer/steamer.tscn")


func test_a_project_path_stands() -> void:
	assert_eq(ShipBake._res("res://data/ships/steamer.tres"), "res://data/ships/steamer.tres")


func test_a_posix_absolute_path_stands() -> void:
	assert_eq(ShipBake._res("/tmp/tmp.x/steamer.glb"), "/tmp/tmp.x/steamer.glb")


func test_a_windows_drive_path_stands() -> void:
	var path := "C:/Users/me/AppData/Local/Temp/tmp.x/steamer.glb"
	assert_eq(ShipBake._res(path), path)


func test_nothing_stays_nothing() -> void:
	assert_eq(ShipBake._res(""), "")
