class_name Goldens
extends RefCounted
## The goldens (R6): text a test works out — a match's transcript, a run of digests —
## held to tests/golden/NAME.<os>-<arch>.txt. Recorded per platform: a build agrees
## with itself on one platform (D4), not across them.
##
## Whenever this platform has no golden, or the text is not its golden, the text is
## printed whole for `make goldens` (tools/goldens.py) to write: base64 between two
## marker lines that name the file and give its size and SHA-256 —
##   golden NAME.PLATFORM.txt begin BYTES SHA256
##   …base64, LINE characters a line…
##   golden NAME.PLATFORM.txt end
## so a CI run's log carries CI's goldens (`make goldens RUN=ID`), and a local run
## this machine's (`make goldens`).

const DIR := "res://tests/golden"
## The base64's characters a line, as MIME has them.
const LINE := 76


## This platform as the goldens' file names spell it: linux-x86_64, macos-arm64, …
static func platform() -> String:
	return "%s-%s" % [OS.get_name().to_lower(), Engine.get_architecture_name()]


## The file [param golden]'s text is recorded in for this platform.
static func file_of(golden: String) -> String:
	return "%s.%s.txt" % [golden, platform()]


## Holds [param text] to [param golden]'s file for this platform on [param test]:
## equal when recorded, pending when this platform has none ([param what] names it in
## the message). Short of equal, it prints the text for `make goldens`. True when
## there was a golden to compare with.
static func check(test: GutTest, golden: String, text: String, what: String) -> bool:
	var file := file_of(golden)
	var path := "%s/%s" % [DIR, file]
	if not FileAccess.file_exists(path):
		show(file, text)
		test.pending("no %s recorded for %s: make goldens writes it" % [what, platform()])
		return false
	var recorded := FileAccess.get_file_as_string(path)
	if text != recorded:
		show(file, text)
	test.assert_eq(text, recorded, "%s: make goldens records it again" % file)
	return true


## Prints [param text] between the markers that name [param file].
static func show(file: String, text: String) -> void:
	var encoded := Marshalls.utf8_to_base64(text)
	print("golden %s begin %d %s" % [file, text.to_utf8_buffer().size(), text.sha256_text()])
	for at in range(0, encoded.length(), LINE):
		print(encoded.substr(at, LINE))
	print("golden %s end" % file)
