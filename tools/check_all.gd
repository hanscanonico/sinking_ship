extends SceneTree
## `make check`'s first pass (tools/check_scripts.sh): every project script loaded in
## this one engine, which runs the same parser, analyser and compiler on each that
## `--check-only -s FILE` does in an engine of its own — 768 boots took CI's runner
## close to eight minutes, this one well under one. It only finds suspects: before
## each script it prints "check-file: K", its place in the queue from 0, and
## "check-bad: K" for one that did not load, and the engine's own diagnostics land
## between those lines. The shell checks each suspect alone, as it always did, and
## reports what that says. "check-done: N" closes a pass that got through its queue.
##
## Usage:  godot --headless --path . -s res://tools/check_all.gd -- --queue=FILE
## FILE holds the scripts' project-relative paths, each ended by a NUL byte.


func _init() -> void:
	var queue := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--queue="):
			queue = arg.trim_prefix("--queue=")
	var bytes := FileAccess.get_file_as_bytes(queue)
	var count := 0
	var from := 0
	for at: int in bytes.size():
		if bytes[at] != 0:
			continue
		var path := bytes.slice(from, at).get_string_from_utf8().trim_prefix("./")
		from = at + 1
		print("check-file: %d" % count)
		var script := ResourceLoader.load("res://" + path) as GDScript
		if script == null or not script.can_instantiate():
			print("check-bad: %d" % count)
		count += 1
	print("check-done: %d" % count)
	quit(0)
