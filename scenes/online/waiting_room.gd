class_name WaitingRoom
extends CanvasLayer
## What an online player looks at outside a match (SH12), plain until the Online menu
## replaces it: what is going on — connecting, a link that cannot be played, a refusal,
## a lost connection — or the room: its code, who is in it, and "press Enter to start"
## for its host, "waiting for the host" for everyone else. Enter (ui_accept) asks for
## the start, and only the host's does — once, until the room is shown again: by the
## server's answer, a refusal or the room changed.

signal start_requested

## The room shown; null while a status is.
var _roster: RoomRoster
## Whether the start has been asked for since the room was shown.
var _asked := false

@onready var _text: Label = $Text


## Shows [param status] alone.
func show_status(status: String) -> void:
	_roster = null
	_asked = false
	_text.text = status
	show()


## Shows [param roster]'s room, and [param note] — a refusal, say — under it.
func show_room(roster: RoomRoster, note: String = "") -> void:
	_roster = roster
	_asked = false
	var lines := PackedStringArray(["Room %s" % roster.code, ""])
	for index in roster.players.size():
		var player := roster.players[index]
		(
			lines
			. append(
				(
					"%s%s%s"
					% [
						player.name,
						" (host)" if player.host else "",
						" — you" if index == roster.you else "",
					]
				)
			)
		)
	lines.append("")
	if roster.playing:
		lines.append("A match is on")
	elif roster.you_host():
		lines.append("Host: press Enter to start · bots take the empty seats")
	else:
		lines.append("Waiting for the host to start")
	if not note.is_empty():
		lines.append_array(["", note])
	_text.text = "\n".join(lines)
	show()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _roster == null or _roster.playing or not _roster.you_host() or _asked:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_asked = true
		start_requested.emit()
