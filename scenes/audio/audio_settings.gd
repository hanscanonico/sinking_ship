class_name AudioSettings
extends Resource
## How loud the game is, overall and for the music and the effects (the ship, the
## brawl, the sea and the menus), each 0…1 on its bus. The settings screen saves
## them at PATH; Game applies them as it boots.

const PATH := "user://audio_settings.tres"
## The buses the three volumes drive, in the default bus layout.
const MASTER := &"Master"
const MUSIC := &"Music"
const EFFECTS := &"Effects"

## The one instance the game applies and the settings screen edits while either
## holds it. Weak, as ViewSettings' is.
static var _shared: WeakRef

@export_range(0.0, 1.0) var master: float = 0.8:
	set(value):
		master = clampf(value, 0.0, 1.0)
@export_range(0.0, 1.0) var music: float = 0.6:
	set(value):
		music = clampf(value, 0.0, 1.0)
@export_range(0.0, 1.0) var effects: float = 1.0:
	set(value):
		effects = clampf(value, 0.0, 1.0)


## The saved settings, or the defaults when none are saved.
static func local() -> AudioSettings:
	var shared: AudioSettings = _shared.get_ref() if _shared != null else null
	if shared == null:
		shared = read(PATH)
		_shared = weakref(shared)
	return shared


## The settings saved at [param path], or the defaults when there are none.
static func read(path: String) -> AudioSettings:
	if ResourceLoader.exists(path):
		var saved := (
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioSettings
		)
		if saved != null:
			return saved
	return AudioSettings.new()


func save(path: String = PATH) -> Error:
	return ResourceSaver.save(self, path)


## Sets each bus to its volume; silent is muted rather than very quiet.
func apply() -> void:
	var volumes := {MASTER: master, MUSIC: music, EFFECTS: effects}
	for bus: StringName in volumes:
		var index := AudioServer.get_bus_index(bus)
		if index == -1:
			continue
		var volume: float = volumes[bus]
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
