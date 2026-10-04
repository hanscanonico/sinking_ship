class_name OnlineSettings
extends RefCounted
## What the Online screen remembers between runs (SH12), beside the view and audio
## settings under user://: the display name last played under and, natively, the server
## last played on. The file is the player's to edit, and so read as plain JSON — never
## as a resource, which can carry a script — of at most MAX_BYTES, each value kept only
## when it is one the screen could have saved: a name the server takes, a server
## OnlineLink reaches. Both are checked again before any use (OnlineLink).

const PATH := "user://online_settings.json"
const MAX_BYTES := 4096

## "" until a name has been played under.
var player_name := ""
## "" until a server has been played on: the Online screen offers its default then.
var server_url := ""


## The settings saved at [param path], or blank ones where there are none to keep.
static func read(path: String = PATH) -> OnlineSettings:
	var settings := OnlineSettings.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return settings
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return settings
	var saved: Dictionary = json.data
	var saved_name: Variant = saved.get("player_name")
	if saved_name is String and ServerRules.load_default().clean_name(saved_name) == saved_name:
		settings.player_name = saved_name
	var saved_server: Variant = saved.get("server_url")
	if saved_server is String and OnlineLink.is_server_url(saved_server):
		settings.server_url = saved_server
	return settings


func save(path: String = PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"player_name": player_name, "server_url": server_url}))
	return file.get_error()
