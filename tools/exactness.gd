extends SceneTree
## `make exactness`, one side of it: a bots-only match the command line chooses, built
## as `make match` builds it and served by the local host, stepped --ticks ticks, with
## one line per tick written to --out — the tick, and the SHA-256 of that tick's
## snapshot as bytes (var_to_bytes). Two builds that write the same file simulated the
## same match bit for bit: the match digest quantizes, and once hid a reordered float
## sum (#303).
##
##   godot --headless --path . -s res://tools/exactness.gd -- --seed=1701 \
##       --ship=steamer --ticks=1200 --out=/tmp/branch.hashes
##
## tools/exactness.sh runs this very file against the base's checkout too (--path
## there, -s here), so it calls only what both sides have. --native=0 runs the GDScript
## whatever library is loaded; the first line printed says which ran. It exits non-zero,
## saying why, when the match cannot be built, ends before --ticks, or --out cannot
## be written.

const RunMatch := preload("res://tools/run_match.gd")


func _initialize() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(user_args: PackedStringArray) -> int:
	var ticks := 0
	var out := ""
	var native := true
	var match_args := PackedStringArray()
	for arg: String in user_args:
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--ticks":
				ticks = value.to_int()
			"--out":
				out = value
			"--native":
				native = value != "0"
			_:
				match_args.append(arg)
	if ticks < 1 or out.is_empty():
		printerr("exactness: --ticks=N of 1 or more and --out=FILE are required")
		return 1
	if not native:
		# What no library carries: every loader asks NativeVersion and gets no. A base
		# from before #709 holds a number there, one since holds a digest.
		var version: Script = NativeVersion
		version.set(&"expected", -1 if version.get(&"expected") is int else "off")
	print("exactness: %s" % _extension(native))
	var config := RunMatch.chosen_config(MatchArgs.parse(match_args))
	if config == null:
		return 1
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("exactness: cannot write %s" % out)
		return 1
	var host := RunMatch.served(config)
	for step in ticks:
		if host.is_over():
			printerr(
				(
					"exactness: the match ended at tick %d: ask for that many ticks or fewer"
					% host.tick()
				)
			)
			return 1
		host.step()
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(var_to_bytes(host.runner.sim.snapshot()))
		file.store_string("%d %s\n" % [host.tick(), hashing.finish().hex_encode()])
	file.close()
	return 0


## Which code answered: the game's extension (native/), or the GDScript. Asked without
## naming what only one side of #709 has: a version number before it, a digest since.
static func _extension(native: bool) -> String:
	if not native:
		return "the GDScript ran, the extension off (--native=0)"
	var version: Script = NativeVersion
	var built: Variant = version.call(&"built")
	if (built is int and built == 0) or (built is String and built == ""):
		return "the GDScript ran, no extension loaded"
	var wanted: Variant = (
		version.call(&"wanted")
		if version.has_method(&"wanted")
		else version.get_script_constant_map().get(&"VERSION")
	)
	if wanted is String and wanted == "any":
		wanted = built
	if built != wanted:
		return "the GDScript ran, the extension stale (built from %s, wanted %s)" % [built, wanted]
	return "the extension ran (%s)" % built
