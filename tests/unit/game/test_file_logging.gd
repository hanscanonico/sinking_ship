extends GutTest
## No engine run from the editor binary — a gate, a test shard, a tool or capture script —
## writes the shared user://logs/godot.log: engines started side by side each rotate that
## one file under the others, which keep writing at their old offsets, and the gap fills
## with NUL bytes, gigabytes of them. project.godot turns file logging off for the editor
## binary (the `editor` feature); `make run` and `make replay` name their log with
## --log-file, and an exported game keeps the default rotated log.


func test_the_editor_binary_writes_no_shared_log() -> void:
	assert_true(OS.has_feature("editor"), "the suite runs on the editor binary")
	assert_false(
		ProjectSettings.get_setting("debug/file_logging/enable_file_logging"),
		"file logging is off wherever the editor binary runs the project"
	)
