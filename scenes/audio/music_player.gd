class_name MusicPlayer
extends Node
## The menu's tune and the match's, each looping on the Music bus, crossfading as
## Game moves between them. Not adaptive: a match sounds the same from first tick
## to last, and the sea and the ship carry the drama.

const MENU := "res://assets/audio/music/sailors_chant.ogg"
const MATCH := "res://assets/audio/music/iridescent_deep.ogg"
## The match's tune sits under the sea and the brawl; the menu's has the room.
const MENU_DB := -8.0
const MATCH_DB := -16.0
const FADE_SECONDS := 1.5

var _players: Array[AudioStreamPlayer] = []
## Which of the two players carries the tune now.
var _current := 0


func _ready() -> void:
	for _player in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_players.append(player)


func play_menu() -> void:
	_play(MENU, MENU_DB)


func play_match() -> void:
	_play(MATCH, MATCH_DB)


func _play(path: String, level_db: float) -> void:
	if not SoundBank.audible():
		return
	var playing := _players[_current]
	if playing.playing and playing.stream.resource_path == path:
		return
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	_current = 1 - _current
	var next := _players[_current]
	next.stream = stream
	next.volume_db = AmbienceMix.SILENT_DB
	next.play()
	var fade := create_tween().set_parallel()
	fade.tween_property(next, "volume_db", level_db, FADE_SECONDS)
	if playing.playing:
		fade.tween_property(playing, "volume_db", AmbienceMix.SILENT_DB, FADE_SECONDS)
		fade.chain().tween_callback(playing.stop)
