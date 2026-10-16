#!/usr/bin/env bash
#
# `make guard-check`, its ninth part: tools/test_changed.py selects every test
# script a change can reach and no other — through a class_name, a literal path, a
# .tres, a uid, a %s pattern, a listed runtime load, a ship's generator and
# authoring scene, a ship loaded by a name its test can spell — prints the chain that
# pulled each in, selects nothing for docs and shell, falls back to the whole suite
# naming why, reads the change set off git against the merge-base with origin/main, and
# --check-sites fails on a runtime load the list does not hold. Against a small
# fixture project written here into a scratch git repo rather than committed under
# tests/: its scripts would join the real project's, and its class_names with them.
# No engine runs.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SELECT="$PWD/tools/test_changed.py"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
TREE="$WORK/tree"

fails=0
fail() {
	echo "test-changed-check: $1" >&2
	fails=1
}

# Writes the file $1 under the fixture, its content on stdin.
put() {
	mkdir -p "$(dirname "$TREE/$1")"
	cat >"$TREE/$1"
}

put project.godot <<'EOF'
config_version=5
[application]
run/main_scene="res://scenes/hud.tscn"
[autoload]
Prefs="*res://scenes/prefs.gd"
EOF
put scenes/prefs.gd <<'EOF'
extends Node
var store := PrefsStore.new()
EOF
put core/prefs_store.gd <<'EOF'
class_name PrefsStore
EOF
put core/ticks.gd <<'EOF'
class_name Ticks
const RATE := 30
EOF
put core/hub.gd <<'EOF'
class_name Hub
## The hub every layer stands on.
const RULES := preload("res://data/rules.tres")
var rate := Ticks.RATE
EOF
put data/rules.tres <<'EOF'
[gd_resource type="Resource" format=3]
EOF
put core/fleet.gd <<'EOF'
class_name Fleet
const SHIPS := "res://data/ships/%s.tres"


static func layout(ship_name: StringName) -> Resource:
	return load(SHIPS % ship_name)


static func names() -> PackedStringArray:
	return ResourceLoader.list_directory("res://data/ships")
EOF
for ship in data/ships/brig data/ships/sloop data/sinking/brig_open_sea \
	tests/fixtures/ships/brig_weak tests/fixtures/ships/sloop_lean; do
	echo '[gd_resource type="Resource" format=3]' | put "$ship.tres"
done
echo "print(1)" | put tools/gen_brig.py
echo "print(2)" | put tools/gen_sloop.py
put authoring/brig/brig.tscn <<'EOF'
[gd_scene format=3]
EOF
put core/sink.gd <<'EOF'
class_name Sink
# Unlike Hud, this never draws: a comment names no dependency.
var hub := Hub.new()
var said := "Hud"
EOF
put scenes/hud.gd <<'EOF'
class_name Hud
extends Node
const THEME := preload("res://scenes/hud_theme.tres")
var hub: Hub
EOF
put scenes/hud_style.gd <<'EOF'
extends Resource
var size := 12
EOF
put scenes/hud_theme.tres <<'EOF'
[gd_resource type="Resource" format=3]

[ext_resource type="Script" path="res://scenes/hud_style.gd" id="1"]

[resource]
script = ExtResource("1")
EOF
put scenes/badge.gd <<'EOF'
extends Node
EOF
echo "uid://badge0001" | put scenes/badge.gd.uid
put scenes/hud.tscn <<'EOF'
[gd_scene format=3 uid="uid://hud00001"]

[ext_resource type="Script" path="res://scenes/hud.gd" id="1"]
[ext_resource type="Script" uid="uid://badge0001" id="2"]

[node name="Hud" type="Node"]
script = ExtResource("1")
EOF
put scenes/screens.gd <<'EOF'
class_name Screens


static func open(path: String) -> PackedScene:
	return load(path)
EOF
put scenes/screens/pause.tscn <<'EOF'
[gd_scene format=3]

[node name="Pause" type="Node"]
EOF
put scenes/unused.gd <<'EOF'
extends Node
EOF
put tools/load_sites.tsv <<'EOF'
# The fixture's runtime-built loads.
scenes/screens.gd	load(path)	scenes/screens/*.tscn
core/fleet.gd	load(SHIPS % ship_name)	@ship
tests/unit/test_deck.gd	load("res://data/ships/%s.tres" % ship)	@ship
tests/unit/test_golden.gd	FileAccess.file_exists(GOLDEN % OS.get_name())	tests/golden/run.*.txt
EOF
put tests/unit/helpers.gd <<'EOF'
class_name Helpers
static var hub := Hub.new()
EOF
put tests/unit/test_hud.gd <<'EOF'
extends GutTest
const SCENE := "res://scenes/hud.tscn"


func test_hud() -> void:
	assert_not_null(Hud.new())
EOF
put tests/unit/test_sink.gd <<'EOF'
extends GutTest


func test_sink() -> void:
	assert_not_null(Sink.new())
EOF
put tests/unit/test_ticks.gd <<'EOF'
extends GutTest


func test_rate() -> void:
	assert_eq(Ticks.RATE, 30)
EOF
put tests/unit/test_screens.gd <<'EOF'
extends GutTest


func test_pause() -> void:
	assert_not_null(Screens.open(OS.get_environment("SCREEN")))
EOF
put tests/unit/test_golden.gd <<'EOF'
extends GutTest
const GOLDEN := "res://tests/golden/run.%s.txt"


func test_golden() -> void:
	assert_true(FileAccess.file_exists(GOLDEN % OS.get_name()))
EOF
put tests/unit/test_brig.gd <<'EOF'
extends GutTest


func test_brig() -> void:
	assert_not_null(Fleet.layout(&"brig"))
EOF
put tests/unit/test_sloop.gd <<'EOF'
extends GutTest
const SHIP := "sloop"


func test_sloop() -> void:
	assert_not_null(Fleet.layout(SHIP))
EOF
put tests/unit/test_deck.gd <<'EOF'
extends GutTest


func test_deck() -> void:
	for ship in ["sloop"]:
		assert_not_null(load("res://data/ships/%s.tres" % ship))
EOF
put tests/unit/test_fleet.gd <<'EOF'
extends GutTest


func test_every_ship() -> void:
	for ship in Fleet.names():
		assert_not_null(Fleet.layout(ship))
EOF
put tests/unit/test_env.gd <<'EOF'
extends GutTest


func test_the_ship_asked_for() -> void:
	assert_not_null(Fleet.layout(OS.get_environment("SHIP")))
EOF
put tests/unit/test_lean.gd <<'EOF'
extends GutTest
const HULL := preload("res://tests/fixtures/ships/sloop_lean.tres")
EOF
put tests/unit/test_words.gd <<'EOF'
extends GutTest
## Names the brig, but loads no ship by name.
var said := "brig"
EOF
echo "the transcript" | put tests/golden/run.macos.txt
echo "tick 1" | put tests/unit/notes.txt
put data/match.tres <<'EOF'
[gd_resource type="Resource" format=3]
EOF
put authoring/ship/ship.tscn <<'EOF'
[gd_scene format=3]
EOF
put addons/gut/gut.gd <<'EOF'
extends Node
EOF
echo "{}" | put .gutconfig.json
printf 'all:\nTEST_HULLS = brig:brig_weak:--weak \\\n\tsloop:sloop_lean:--lean\n' | put Makefile
echo "# Notes" | put docs/notes.md
echo "echo hi" | put tools/build.sh
echo "binary" | put assets/odd.xyz

g() {
	git -C "$TREE" -c user.name=check -c user.email=check@example.com "$@"
}
g init -q -b main
g add -A
g commit -q -m fixture
g update-ref refs/remotes/origin/main HEAD
BASE=$(g rev-parse HEAD)

# Runs the selector on change set $2… (files, or "git" for the repo's own) into
# results named $1: $WORK/$1.out its report, $WORK/$1.list its selection.
run() {
	local name="$1"
	shift
	if [[ "$1" == git ]]; then
		python3 "$SELECT" --root "$TREE" --list "$WORK/$name.list" >"$WORK/$name.out" 2>&1
	else
		python3 "$SELECT" --root "$TREE" --list "$WORK/$name.list" --changed "$@" >"$WORK/$name.out" 2>&1
	fi || fail "$name: the selector failed: $(cat "$WORK/$name.out")"
}

# The selection under results $1, on one line.
picked() {
	sort "$WORK/$1.list" | paste -sd' ' -
}

# Holds the selection under results $1 to the scripts $2…, as one sorted line.
expect() {
	local name="$1"
	shift
	local wanted
	wanted="$(printf '%s\n' "$@" | sed '/^$/d' | sort | paste -sd' ' -)"
	[[ "$(picked "$name")" == "$wanted" ]] || fail "$name: selected [$(picked "$name")], wanted [$wanted]"
}

# Holds the report under results $1 to contain the fixed line $2.
says() {
	grep -qF -- "$2" "$WORK/$1.out" || fail "$1: the report does not say '$2': $(cat "$WORK/$1.out")"
}

HUD=tests/unit/test_hud.gd
SINK=tests/unit/test_sink.gd
TICKS=tests/unit/test_ticks.gd
SCREENS=tests/unit/test_screens.gd
GOLDEN=tests/unit/test_golden.gd

# Docs and shell reach no test, and the report says nothing loads them.
run docs docs/notes.md tools/build.sh tests/unit/notes.txt
expect docs
says docs "no GDScript, resource or scene changed — no tests to run"

# A display script selects the display test only — a comment or a string naming
# its class is no dependency — with the chain that pulled it in.
run hud scenes/hud.gd
expect hud "$HUD"
says hud "    $HUD"
says hud "        -> scenes/hud.gd  (Hud)"

# A script a .tres names, through the .tres and the preload holding it.
run style scenes/hud_style.gd
expect style "$HUD"
says style "        -> scenes/hud_theme.tres  (res://scenes/hud_theme.tres)"
says style "        -> scenes/hud_style.gd  (res://scenes/hud_style.gd)"

# A script a scene names by uid alone, and its .uid file standing for it.
run badge scenes/badge.gd.uid
expect badge "$HUD"
says badge "        -> scenes/hud.tscn  (res://scenes/hud.tscn)"

# The hub reaches everything that stands on it, through a helper too.
run hub core/hub.gd
expect hub "$HUD" "$SINK"
says hub "        -> core/sink.gd  (Sink)"

# Deeper still: everything but what never touches it.
run ticks core/ticks.gd
expect ticks "$HUD" "$SINK" "$TICKS"

# A test script selects itself, and a new one too.
run self "$TICKS"
expect self "$TICKS"
run fresh tests/unit/test_new.gd
expect fresh
echo 'extends GutTest' >"$TREE/tests/unit/test_new.gd"
run fresh tests/unit/test_new.gd
expect fresh tests/unit/test_new.gd
rm "$TREE/tests/unit/test_new.gd"

# A listed runtime-built load, and a %s pattern, are edges to what they reach.
run pause scenes/screens/pause.tscn
expect pause "$SCREENS"
says pause "        -> scenes/screens/pause.tscn  (load(path))"
run golden tests/golden/run.macos.txt
expect golden "$GOLDEN"
says golden "        -> tests/golden/run.macos.txt  (res://tests/golden/run.%s.txt)"

# A ship's data selects the tests that can load her, and not another ship's: by a
# name a literal or a constant spells, by every name a listing of the fleet or the
# environment can give — and not by a name no by-name load reaches. Her scenarios
# and hulls are hers too.
BRIG=tests/unit/test_brig.gd
SLOOP=tests/unit/test_sloop.gd
DECK=tests/unit/test_deck.gd
FLEET=tests/unit/test_fleet.gd
ENV=tests/unit/test_env.gd
LEAN=tests/unit/test_lean.gd
BY_FLEET="the Fleet in core/fleet.gd loads her by name"
run brig data/ships/brig.tres
expect brig "$BRIG" "$FLEET" "$ENV"
says brig "        -> data/ships/brig.tres  ($BRIG names brig; $BY_FLEET)"
says brig "        -> data/ships/brig.tres  ($FLEET lists the fleet; $BY_FLEET)"
says brig "        -> data/ships/brig.tres  ($ENV reads a name from the environment; $BY_FLEET)"
run sloop data/ships/sloop.tres
expect sloop "$SLOOP" "$DECK" "$FLEET" "$ENV"
says sloop "        -> data/ships/sloop.tres  ($SLOOP names sloop; $BY_FLEET)"
says sloop "        -> data/ships/sloop.tres  ($DECK names sloop; res://data/ships/%s.tres in $DECK loads her by name)"
run scenario data/sinking/brig_open_sea.tres
expect scenario "$BRIG" "$FLEET" "$ENV"
run hull tests/fixtures/ships/brig_weak.tres
expect hull "$BRIG" "$FLEET" "$ENV"

# A ship's generator selects what her data and her test hulls (the Makefile's
# TEST_HULLS, continued lines too) select; her authoring scene, what her data does.
run genbrig tools/gen_brig.py
expect genbrig "$BRIG" "$FLEET" "$ENV"
says genbrig "        -> tools/gen_brig.py  (written by tools/gen_brig.py (make ship))"
run gensloop tools/gen_sloop.py
expect gensloop "$SLOOP" "$DECK" "$FLEET" "$ENV" "$LEAN"
says gensloop "        -> tools/gen_sloop.py  (written by tools/gen_sloop.py --lean (make ship))"
run authoring authoring/brig/brig.tscn
expect authoring "$BRIG" "$FLEET" "$ENV"
says authoring "        -> authoring/brig/brig.tscn  (baked from authoring/brig/ (make bake-check))"

# Shared data selects every test that reads it, through every reader.
run rules data/rules.tres
expect rules "$HUD" "$SINK"
says rules "        -> data/rules.tres  (res://data/rules.tres)"

# An unused script reaches no test, and nothing runs.
run unused scenes/unused.gd
expect unused
says unused "no test script reaches the changes — no tests to run"

# Each fallback to the whole suite says why, alongside a change that selects.
for changed in \
	"project.godot:project settings" \
	"addons/gut/gut.gd:addons/" \
	".gutconfig.json:the test runner's config" \
	"Makefile:the test runner" \
	"data/match.tres:a data file no edge reaches — the graph cannot place it" \
	"authoring/ship/ship.tscn:a data file no edge reaches — the graph cannot place it" \
	"tools/load_sites.tsv:the test selector's runtime load sites" \
	"assets/odd.xyz:a file the graph cannot place" \
	"core/prefs_store.gd:an autoload every engine runs reaches it"; do
	file="${changed%%:*}"
	run fallback "$file" scenes/hud.gd
	[[ "$(cat "$WORK/fallback.list")" == ALL ]] || fail "$file: did not fall back to the whole suite"
	says fallback "the full suite runs —"
	says fallback "    $file: ${changed#*:}"
done

# From git: the branch's commits, staged, unstaged and untracked edits against the
# merge-base — not what main gained since.
g checkout -q -b branch
echo "# More" >>"$TREE/docs/notes.md"
g commit -q -am "docs"
run gitdocs git
expect gitdocs
says gitdocs "against origin/main (merge-base ${BASE:0:10})"
g checkout -q main
echo "const MORE := 1" >>"$TREE/core/ticks.gd"
g commit -q -am "main moves on"
g update-ref refs/remotes/origin/main HEAD
g checkout -q branch
run gitmain git
expect gitmain
echo "var more := 1" >>"$TREE/scenes/hud.gd"
run gitunstaged git
expect gitunstaged "$HUD"
g add scenes/hud.gd
run gitstaged git
expect gitstaged "$HUD"
echo 'extends GutTest' >"$TREE/tests/unit/test_untracked.gd"
run gituntracked git
expect gituntracked "$HUD" tests/unit/test_untracked.gd
rm "$TREE/tests/unit/test_untracked.gd"
g reset -q --hard

# A deleted script still selects the tests that named its class.
g rm -q core/sink.gd
run gitdeleted git
expect gitdeleted "$SINK"
g reset -q --hard

# The runtime load sites: all listed passes; an unlisted one fails, naming itself;
# a listed one the code lost fails too.
python3 "$SELECT" --root "$TREE" --check-sites >"$WORK/sites.out" 2>&1 ||
	fail "the listed sites failed: $(cat "$WORK/sites.out")"
cat >>"$TREE/scenes/hud.gd" <<'EOF'


func skin(name: String) -> Resource:
	return load("res://scenes/skins/%s.tres" % name)
EOF
python3 "$SELECT" --root "$TREE" --check-sites >"$WORK/unlisted.out" 2>&1 &&
	fail "an unlisted runtime load passed"
grep -qF 'scenes/hud.gd: load("res://scenes/skins/%s.tres" % name) builds its path at runtime' \
	"$WORK/unlisted.out" || fail "the unlisted load was not named: $(cat "$WORK/unlisted.out")"
g checkout -q -- scenes/hud.gd
sed -i.bak 's/return load(path)/return null/' "$TREE/scenes/screens.gd"
python3 "$SELECT" --root "$TREE" --check-sites >"$WORK/stale.out" 2>&1 &&
	fail "a listed site the code lost passed"
grep -qF 'lists scenes/screens.gd: load(path), which the code no longer has' "$WORK/stale.out" ||
	fail "the lost site was not named: $(cat "$WORK/stale.out")"

((fails == 0)) && echo "test-changed-check: ok"
exit "$fails"
