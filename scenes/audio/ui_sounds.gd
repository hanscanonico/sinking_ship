class_name UiSounds
extends Node
## A tick when a control is pointed at or reached with the keys or the pad, and a
## click when it is pressed — for every button, toggle and slider in the game,
## whichever screen adds it, on the Effects bus.

const SELECT := "res://assets/audio/ui/select.wav"
const CLICK := "res://assets/audio/ui/click.wav"
const LEVEL_DB := -10.0

var _select: AudioStreamPlayer
var _click: AudioStreamPlayer


func _ready() -> void:
	if not SoundBank.audible():
		return
	_select = _voice(SELECT)
	_click = _voice(CLICK)
	get_tree().node_added.connect(_hook)
	for control: Node in get_tree().root.find_children("*", "Control", true, false):
		_hook(control)


func _hook(node: Node) -> void:
	if not (node is BaseButton or node is Slider):
		return
	var control := node as Control
	if control.focus_entered.is_connected(_select.play):
		return
	control.focus_entered.connect(_select.play)
	control.mouse_entered.connect(_select.play)
	if control is BaseButton:
		(control as BaseButton).pressed.connect(_click.play)
	else:
		(control as Slider).drag_ended.connect(func(_changed: bool) -> void: _click.play())


func _voice(path: String) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.stream = load(path)
	voice.bus = &"Effects"
	voice.volume_db = LEVEL_DB
	add_child(voice)
	return voice
