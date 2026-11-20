class_name OnlinePause
extends CanvasLayer
## Esc in a match on a server (SH12): resume, the settings, or leave the match — the
## server hands the seat to a bot. Nothing online pauses, so the match goes on under it,
## and it says so. A watcher's lists the controls they have (InputPrompts). Esc, Start
## or ui_cancel resumes.

signal resume_requested
signal settings_requested
signal leave_requested

@onready var _resume: Button = %Resume
@onready var _title: Label = %Title
@onready var _controls: Label = %Controls


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_resume.pressed.connect(resume_requested.emit)
	%Settings.pressed.connect(settings_requested.emit)
	%LeaveMatch.pressed.connect(leave_requested.emit)


## Opens over the match: a watcher's, with [param watch_prompts]' watching controls
## listed; a player's without them.
func open(watch_prompts: InputPrompts = null) -> void:
	_title.text = "Still watching" if watch_prompts != null else "Still playing"
	_controls.visible = watch_prompts != null
	if watch_prompts != null:
		_controls.text = watch_prompts.pause_controls(false, true)
	show()
	_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
