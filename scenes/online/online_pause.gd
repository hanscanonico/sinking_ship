class_name OnlinePause
extends CanvasLayer
## Esc in a match on a server (SH12): resume, the settings, or leave the match — the
## server hands the seat to a bot. Nothing online pauses, so the match goes on under it,
## and it says so. Esc, Start or ui_cancel resumes.

signal resume_requested
signal settings_requested
signal leave_requested

@onready var _resume: Button = %Resume


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_resume.pressed.connect(resume_requested.emit)
	%Settings.pressed.connect(settings_requested.emit)
	%LeaveMatch.pressed.connect(leave_requested.emit)


func open() -> void:
	show()
	_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
