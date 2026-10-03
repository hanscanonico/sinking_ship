class_name PauseMenu
extends CanvasLayer
## The offline pause: resume, the settings, leave for the menu, or quit. Only what
## it shows — Game is what stops the match's SimDriver.

signal resume_requested
signal settings_requested
signal menu_requested
signal quit_requested

@onready var _resume: Button = %Resume


func _ready() -> void:
	hide()
	_resume.pressed.connect(resume_requested.emit)
	%PauseSettings.pressed.connect(settings_requested.emit)
	%LeaveMatch.pressed.connect(menu_requested.emit)
	%QuitFromPause.pressed.connect(quit_requested.emit)


func open() -> void:
	show()
	_resume.grab_focus()
