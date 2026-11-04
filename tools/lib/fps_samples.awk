# The once-a-second frame rates of a `make fps` run (the engine's --print-fps) that
# count, one per line: only those printed after the game's "first match frame" line
# (--match-seconds), less the first `skip` of them — the match's, never the menu's or
# a held ship's dressing, however long she takes to dress. A log without that line,
# a run whose match never started, keeps none and exits 1.
#
# Usage:  awk -v skip=8 -f tools/lib/fps_samples.awk LOG

/^first match frame / { started = 1; next }
started && /Project FPS: [0-9]+/ {
	if (++seen > skip) {
		match($0, /Project FPS: [0-9]+/)
		print substr($0, RSTART + 13, RLENGTH - 13)
	}
}
END {
	if (!started) {
		print "fps: the match never started: no first match frame in the log" > "/dev/stderr"
		exit 1
	}
}
