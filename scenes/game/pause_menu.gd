class_name PauseMenu
extends CanvasLayer
## The offline pause: every control of play, then resume, the settings, leave for the
## menu, or quit. Only what it shows — Game is what stops the match's SimDriver.

signal resume_requested
signal settings_requested
signal menu_requested
signal quit_requested

@onready var _resume: Button = %Resume
@onready var _controls: Label = %PauseControls


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_resume.pressed.connect(resume_requested.emit)
	%PauseSettings.pressed.connect(settings_requested.emit)
	%LeaveMatch.pressed.connect(menu_requested.emit)
	%QuitFromPause.pressed.connect(quit_requested.emit)


## Shows the pause with [param prompts]' controls on the device last used — what
## switches the view too when [param spectating] — or none without prompts.
func open(prompts: InputPrompts = null, spectating := false) -> void:
	_controls.visible = prompts != null
	if prompts != null:
		_controls.text = prompts.pause_controls(spectating)
	show()
	_resume.grab_focus()
