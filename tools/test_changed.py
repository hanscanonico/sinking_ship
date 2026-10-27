#!/usr/bin/env python3
"""Which test scripts a branch's changes can reach: `make test-changed`.

The change set is the branch plus its uncommitted and untracked edits, against its
merge-base with origin/main. A graph is built from the code itself: a script that
names a class_name depends on the script declaring it, and a file holding a literal
res:// path — a preload, a load, an ext_resource, a shader #include, a FileAccess
read — depends on what that path names: one file, every file under a directory, or
every file a %s pattern can fill. Every test script that reaches a changed file,
directly or through others, is selected, and printed with the chain that pulled it
in. Over-selecting is fine; missing is not, and CI's full suite on every PR is the
net under it.

Classes are read from the sources' own class_name lines rather than the engine's
.godot/global_script_class_cache.cfg, so the selector needs no import and sees a
class a branch adds, renames or deletes the moment it is written.

Ships are data, and the graph follows them there. A ship's files — her layout
data/ships/NAME.tres, her scenarios data/sinking/NAME_*.tres, her test-only hulls
tests/fixtures/ships/NAME_*.tres and her authoring scene's authoring/NAME/ — stand on
what writes them: tools/gen_NAME.py writes her data and, by the Makefile's TEST_HULLS,
her test hulls, and her authoring scene bakes to her data (make bake-check). A ship
loaded by name — through the Fleet (core/fleet.gd), whose own path literals are not
edges, a res:// %s pattern only ships' files fill, or a site listed as @ship — is
whichever ship her name, at runtime, says; and
every such name started as text the process holds: a string in a script or a
resource, one of her own files, a listing of the fleet (Fleet.names()), or the
environment (the command line a test runs under is the runner's, and names none). So
a test that reaches a by-name load depends on the ships whose names are words in the
strings of the files it reaches, the ships whose files it reaches, and every ship
when one of them lists the fleet or reads the environment — never a ship nothing it
reaches can name.

Nothing runs when no GDScript, resource or scene changed. The full suite runs, and
the report says why, when a change touches project settings, addons/, the test
runner or its config, a file the graph cannot place, or a file under data/ or
authoring/ that no edge reaches.

A load whose path is built at runtime hides its target from the literals, so every
such call — load, ResourceLoader, FileAccess and DirAccess with an argument that is
not a string literal or a constant holding one — is a known site in
tools/load_sites.tsv, each with the files it may reach (globs, - for user://
only, @ship for a ship by her name); the graph takes those as edges too.
--check-sites fails on a site the list does not hold, or a listed one the code no
longer has (`make guard-check`).

Usage:  tools/test_changed.py                    # the report, against origin/main
        tools/test_changed.py --list FILE        # the report, and the selection to FILE:
                                                 #   one script per line, empty for
                                                 #   none, the one line ALL for the suite
        tools/test_changed.py --base REF         # against REF's merge-base instead
        tools/test_changed.py --changed PATH...  # this change set, not git's
        tools/test_changed.py --check-sites      # the runtime load sites are all listed
        tools/test_changed.py --root DIR ...     # a tree other than this repo's
"""

import fnmatch
import os
import re
import subprocess
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITES = "tools/load_sites.tsv"
TEST_DIR = "tests/unit/"

# Never part of the project: version control, the engine's cache, a vendored engine,
# nested agent checkouts, exports and captures.
SKIP_DIRS = {".git", ".godot", "bin", ".claude", "build", "captures"}
# Files the graph reads references out of.
SOURCES = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}
# Files the engine loads as they are; any other it loads only once imported, and an
# imported file has a NAME.import beside it.
RESOURCES = SOURCES | {".res"}

# A change here can move any test's outcome, so the whole suite runs.
FULL_SUITE_FILES = {
    "project.godot": "project settings",
    "default_bus_layout.tres": "project settings: the bus layout every engine loads",
    ".gutconfig.json": "the test runner's config",
    "tests/durations.tsv": "the test runner's config: the shard weights",
    "Makefile": "the test runner: the test targets",
    "tools/run_tests.sh": "the test runner",
    "tools/test_shards.py": "the test runner: the shard split",
    "tools/test_slot.sh": "the test runner: its engine slots",
    "tools/lib/free_memory.sh": "the test runner: its engine slots' memory floor",
    "tools/engine_guard.sh": "the test runner: its error guard",
    "tools/lib/require_godot.sh": "the test runner: its engine lookup",
    "tools/test_changed.py": "the test selector itself",
    SITES: "the test selector's runtime load sites",
}
FULL_SUITE_DIRS = {
    "addons/": "addons/: GUT and the plugins every engine loads",
}
# Data a test reaches only through an edge: one no edge reaches is unplaced, not unused.
PLACED_DIRS = ("data/", "authoring/")

# Ships: her layout, her scenarios, her test-only hulls, her authoring scene.
SHIP_DIR = "data/ships/"
SHIP_FILES = ("data/sinking/", "tests/fixtures/ships/")
AUTHORING_DIR = "authoring/"
# The door ships are loaded through by name: its path literals are patterns over every
# ship, and which one it loads is its caller's name.
FLEET = "core/fleet.gd"
# A listed site's reach for a ship loaded by name.
BY_NAME = "@ship"
# The test hulls the generators write, as the Makefile lists them: SHIP:FIXTURE:FLAG.
TEST_HULLS = re.compile(r"^TEST_HULLS\s*:?=((?:[^\n]*\\\n)*[^\n]*)", re.M)
WORD = re.compile(r"[a-z0-9_]+")
QUOTED = re.compile(r'"((?:[^"\\\n]|\\.)*)"')

# Never loaded by the engine and never read by a test unless a literal path says so:
# a change to one of these, when nothing refers to it, reaches no test.
NO_TEST_DIRS = ("docs/", ".lavish/", ".github/", ".claude/", "deploy/")
NO_TEST_SUFFIXES = {
    ".md", ".sh", ".py", ".yml", ".yaml", ".txt", ".html", ".js", ".css", ".json",
    ".blend", ".blend1", ".cfg", ".conf", ".example", ".tsv",
}
NO_TEST_NAMES = {".gitignore", ".dockerignore", ".gdignore", "gdlintrc", "LICENSE"}

# GDScript as tokens: strings (kept whole), comments (dropped), identifiers.
GD_TOKEN = re.compile(
    r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\''
    r"|#[^\n]*|[A-Za-z_]\w*|\S"
)
CLASS_NAME = re.compile(r"^(?:@\w+\s+)*class_name\s+([A-Za-z_]\w*)", re.M)
QUOTED_PATH = re.compile(r'"((?:res|uid)://[^"]*)"')
SHADER_INCLUDE = re.compile(r'#include\s+"([^"]+)"')
SCRIPT_CLASS = re.compile(r'script_class="(\w+)"')
UID_LINE = re.compile(r'\buid="(uid://\w+)"')
AUTOLOAD = re.compile(r'^(\w+)="\*?res://([^"]+)"', re.M)
FORMAT = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[sdifxXvc]")

# The calls a runtime-built path hides a load behind.
LOAD_CALL = re.compile(
    r"(?<![\w.])((?:ResourceLoader|FileAccess|DirAccess)\.\w+|preload|load)\("
)
FILE_CALLS = {
    "ResourceLoader.load", "ResourceLoader.exists", "ResourceLoader.load_threaded_request",
    "FileAccess.open", "FileAccess.file_exists", "FileAccess.get_file_as_string",
    "FileAccess.get_file_as_bytes", "DirAccess.open", "DirAccess.get_files_at",
    "DirAccess.get_directories_at", "DirAccess.dir_exists_absolute",
}
STRING_CONST = re.compile(
    r'^(?:static\s+)?const\s+([A-Z_][A-Z0-9_]*)\s*(?::\s*\w+\s*)?:?=\s*"[^"]*"\s*(?:#.*)?$',
    re.M,
)


def posix(path: str) -> str:
    """[path] normalised, with / between its parts on every platform: git and the
    tables name files that way, and Windows would otherwise answer with backslashes."""
    return os.path.normpath(path).replace(os.sep, "/")


def is_test(path: str) -> bool:
    return (
        path.startswith(TEST_DIR)
        and path.endswith(".gd")
        and os.path.basename(path).startswith("test_")
    )


class Tree:
    """Every file of the project under root, and the references between them."""

    def __init__(self, root: Path, extra: set[str] = frozenset()):
        self.root = root
        self.files = self._walk()
        # Paths a pattern may name though they are gone: a deleted file's dependents
        # still reach it.
        self.known = self.files | set(extra)
        self.classes: dict[str, str] = {}
        self.texts: dict[str, str] = {}
        for path in sorted(self.files):
            if Path(path).suffix in SOURCES:
                self.texts[path] = (root / path).read_text(errors="replace")
        for path, text in self.texts.items():
            if path.endswith(".gd"):
                for name in CLASS_NAME.findall(text):
                    self.classes[name] = path
        self.autoloads: list[str] = []
        project = root / "project.godot"
        if project.is_file():
            for name, target in AUTOLOAD.findall(project.read_text()):
                self.autoloads.append(target)
                self.classes.setdefault(name, target)
        self.uids = self._uids()
        self.edges: dict[str, set[str]] = {}
        self.why: dict[tuple[str, str], str] = {}
        # The ships, by name, each to her files.
        self.ships: dict[str, set[str]] = {}
        for path in self.known:
            if os.path.dirname(path) + "/" == SHIP_DIR and path.endswith(".tres"):
                self.ships[Path(path).stem] = set()
        for path in self.known:
            ship = self.ship_of(path)
            if ship:
                self.ships[ship].add(path)
        # Files that load a ship by name, each to the load that does.
        self.by_name: dict[str, str] = {}
        # Files that may name any ship, each to why: a listing of the fleet's names, or
        # text the graph cannot read (the environment).
        self.any_ship: dict[str, str] = {}

    def _walk(self) -> set[str]:
        found = set()
        for here, dirs, names in os.walk(self.root):
            rel = os.path.relpath(here, self.root)
            if ".gdignore" in names and rel != ".":
                dirs[:] = []
                continue
            dirs[:] = [d for d in dirs if not (rel == "." and d in SKIP_DIRS)]
            for name in names:
                found.add(posix(os.path.join(rel, name)))
        return found

    def _uids(self) -> dict[str, str]:
        uids = {}
        for path in self.files:
            if path.endswith(".uid"):
                uids[(self.root / path).read_text().strip()] = path[: -len(".uid")]
            elif path.endswith(".import"):
                match = UID_LINE.search((self.root / path).read_text(errors="replace"))
                if match:
                    uids[match.group(1)] = path[: -len(".import")]
        for path, text in self.texts.items():
            if path.endswith((".tscn", ".tres")):
                match = UID_LINE.search(text.split("\n", 1)[0])
                if match:
                    uids[match.group(1)] = path
        return uids

    def ship_of(self, path: str) -> str | None:
        """The ship whose file path is, or None: her name is its stem, or its stem's front."""
        if path.startswith(AUTHORING_DIR):
            parts = path.split("/")
            return parts[1] if len(parts) > 2 and parts[1] in self.ships else None
        if os.path.dirname(path) + "/" == SHIP_DIR:
            return Path(path).stem if Path(path).stem in self.ships else None
        if path.startswith(SHIP_FILES) and path.endswith(".tres"):
            return self.ship_named(Path(path).stem)
        return None

    def ship_named(self, word: str) -> str | None:
        """The ship word names — hers, or one of her scenarios' or hulls' (steamer_coast)."""
        if word in self.ships:
            return word
        best = None
        for ship in self.ships:
            if word.startswith(ship + "_") and (best is None or len(ship) > len(best)):
                best = ship
        return best

    def is_resource(self, path: str) -> bool:
        return Path(path).suffix in RESOURCES or path + ".import" in self.known

    def add(self, source: str, target: str, why: str) -> None:
        if target != source:
            self.edges.setdefault(source, set()).add(target)
            self.why.setdefault((source, target), why)

    def add_path(self, source: str, literal: str) -> None:
        """Edges for a path as written in source: res://, uid:// or relative."""
        if literal.startswith("uid://"):
            if literal in self.uids:
                self.add(source, self.uids[literal], literal)
            return
        if literal.startswith("res://"):
            path = literal[len("res://") :]
        else:
            path = posix(os.path.join(os.path.dirname(source), literal))
        if not path.strip("/"):
            return  # res:// alone is a prefix test, not a load
        if FORMAT.search(path):
            pattern = FORMAT.sub("*", path)
            targets = fnmatch.filter(self.known, pattern)
            if targets and all(self.ship_of(t) for t in targets):
                # A ship's file by her name: whichever ship the name says (_ship_names).
                self.by_name.setdefault(source, literal)
                return
            for target in targets:
                self.add(source, target, literal)
        elif path in self.known:
            self.add(source, path, literal)
        else:
            # A directory, or the front of a path finished at runtime.
            for target in self.known:
                if target.startswith(path):
                    self.add(source, target, literal)

    def build(self, sites: list[tuple[str, str, list[str]]]) -> None:
        for path, text in self.texts.items():
            suffix = Path(path).suffix
            if suffix == ".gd":
                self._scan_gd(path, text)
            elif suffix in (".gdshader", ".gdshaderinc"):
                for literal in SHADER_INCLUDE.findall(text):
                    self.add_path(path, literal)
            else:
                for literal in QUOTED_PATH.findall(text):
                    self.add_path(path, literal)
                for name in SCRIPT_CLASS.findall(text):
                    if name in self.classes:
                        self.add(path, self.classes[name], name)
        for path in self.files:
            # A sidecar belongs to its file; changing either is changing it.
            for sidecar in (".uid", ".import"):
                if path.endswith(sidecar):
                    self.add(path[: -len(sidecar)], path, "its " + sidecar)
        if FLEET in self.files:
            self.by_name[FLEET] = "the Fleet"
        for path, call, reaches in sites:
            for pattern in reaches:
                if pattern == BY_NAME:
                    self.by_name.setdefault(path, call)
                for target in fnmatch.filter(self.known, pattern):
                    self.add(path, target, call)
        self._ship_sources()
        self._ship_names()

    def _ship_sources(self) -> None:
        """A ship's files on what writes them: her generator, her authoring scene."""
        hulls = []
        makefile = self.root / "Makefile"
        if makefile.is_file():
            for listed in TEST_HULLS.findall(makefile.read_text()):
                hulls += [h.split(":", 2) for h in listed.replace("\\\n", " ").split()]
        for ship in self.ships:
            generator = f"tools/gen_{ship}.py"
            data = f"{SHIP_DIR}{ship}.tres"
            if generator in self.known:
                self.add(data, generator, f"written by {generator} (make ship)")
            for path in self.ships[ship]:
                if path.startswith(AUTHORING_DIR):
                    self.add(data, path, f"baked from {AUTHORING_DIR}{ship}/ (make bake-check)")
        for hull in hulls:
            if len(hull) == 3:
                generator = f"tools/gen_{hull[0]}.py"
                fixture = f"tests/fixtures/ships/{hull[1]}.tres"
                if generator in self.known:
                    self.add(fixture, generator, f"written by {generator} {hull[2]} (make ship)")

    def _ship_names(self) -> None:
        """Each test that reaches a by-name load, to the files of every ship it can name."""
        words: dict[str, set[str]] = {}
        named = {}
        for test in sorted(self.files):
            if not is_test(test):
                continue
            reached = self.reach_in_order(test)
            loader = next((p for p in reached if p in self.by_name), None)
            if loader is None:
                continue
            ships: dict[str, str] = {}
            for path in reached:
                ship = self.ship_of(path)
                if ship:
                    ships.setdefault(ship, f"her file {path}")
                if path in self.any_ship:
                    for ship in self.ships:
                        ships.setdefault(ship, f"{path} {self.any_ship[path]}")
                if path not in words:
                    words[path] = self._words(path)
                for word in words[path]:
                    ship = self.ship_named(word)
                    if ship:
                        ships.setdefault(ship, f"{path} names {word}")
            how = f"{self.by_name[loader]} in {loader}"
            named[test] = {ship: f"{why}; {how} loads her by name" for ship, why in ships.items()}
        for test, ships in named.items():
            for ship, why in ships.items():
                for path in sorted(self.ships[ship]):
                    # Her authoring scene is not loaded, but baked to her data.
                    if not path.startswith(AUTHORING_DIR):
                        self.add(test, path, why)

    def _words(self, path: str) -> set[str]:
        """The words of the strings path holds, every one a ship's name it may spell."""
        text = self.texts.get(path)
        if text is None or path == FLEET:
            return set()
        if path.endswith(".gd"):
            strings = [t for t in GD_TOKEN.findall(text) if t[0] in "\"'"]
        else:
            strings = QUOTED.findall(text)
        return {w for string in strings for w in WORD.findall(string)}

    def _scan_gd(self, path: str, text: str) -> None:
        tokens = [t for t in GD_TOKEN.findall(text) if t[0] != "#"]
        for i, token in enumerate(tokens):
            if path == FLEET:
                if token in self.classes:
                    self.add(path, self.classes[token], token)
                continue
            listed = tokens[i : i + 5] == ["Fleet", ".", "names", "(", ")"]
            if listed and not _only_shown(tokens, i):
                self.any_ship.setdefault(path, "lists the fleet")
            if tokens[i : i + 4] == ["OS", ".", "get_environment", "("]:
                self.any_ship.setdefault(path, "reads a name from the environment")
            if token[0] in "\"'":
                literal = token.strip("\"'")
                # A load's own argument may be relative to the script.
                loaded = i >= 2 and tokens[i - 1] == "(" and tokens[i - 2] in ("load", "preload")
                if literal.startswith(("res://", "uid://")) or (loaded and literal):
                    self.add_path(path, literal)
            elif token in self.classes:
                self.add(path, self.classes[token], token)

    def reverse(self) -> dict[str, set[str]]:
        back: dict[str, set[str]] = {}
        for source, targets in self.edges.items():
            for target in targets:
                back.setdefault(target, set()).add(source)
        return back

    def reach_in_order(self, start: str) -> list[str]:
        """Every file start reaches, itself first, the nearest before the farther."""
        order, seen, queue = [start], {start}, deque([start])
        while queue:
            for target in sorted(self.edges.get(queue.popleft(), ())):
                if target not in seen:
                    seen.add(target)
                    order.append(target)
                    queue.append(target)
        return order

    def reach(self, starts: list[str]) -> set[str]:
        seen, queue = set(starts), deque(starts)
        while queue:
            for target in self.edges.get(queue.popleft(), ()):
                if target not in seen:
                    seen.add(target)
                    queue.append(target)
        return seen


def _only_shown(tokens: list[str], i: int) -> bool:
    """Whether the Fleet.names() at tokens[i] is only asked of or joined into words —
    never a name to load."""
    after = tokens[i + 5 : i + 8]
    before = tokens[max(i - 3, 0) : i]
    return after[:3] == [".", "has", "("] or before[-3:] == [".", "join", "("]


def read_sites(root: Path) -> list[tuple[str, str, list[str]]]:
    """tools/load_sites.tsv: FILE, CALL, then the globs it may reach (- for none)."""
    sites = []
    listed = root / SITES
    if not listed.exists():
        return sites
    for line in listed.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3 or not fields[2].strip():
            sys.exit(f"test-changed: {SITES}: {line!r} is not FILE<tab>CALL<tab>REACHES")
        reaches = [g for g in fields[2].split() if g != "-"]
        sites.append((fields[0], fields[1], reaches))
    return sites


def runtime_sites(tree: Tree) -> list[tuple[str, str]]:
    """Every call in the project's GDScript that loads or reads a runtime-built path."""
    consts = {p: set(STRING_CONST.findall(t)) for p, t in tree.texts.items() if p.endswith(".gd")}
    found = []
    for path, text in sorted(tree.texts.items()):
        if not path.endswith(".gd") or path.startswith("addons/"):
            continue
        code = GD_TOKEN.sub(lambda m: "" if m.group(0)[0] == "#" else m.group(0), text)
        for match in LOAD_CALL.finditer(code):
            name = match.group(1)
            if "." in name and name not in FILE_CALLS:
                continue
            arg = _spaced(_first_argument(code, match.end()))
            if _constant(arg, path, consts, tree.classes):
                continue
            found.append((path, f"{name}({arg})"))
    return sorted(set(found))


def _first_argument(code: str, start: int) -> str:
    depth, i = 0, start
    for token in GD_TOKEN.finditer(code, start):
        text = token.group(0)
        if text in "([{":
            depth += 1
        elif text in ")]}":
            if depth == 0:
                return code[start : token.start()]
            depth -= 1
        elif text == "," and depth == 0:
            return code[start : token.start()]
        i = token.end()
    return code[start:i]


def _spaced(code: str) -> str:
    """code on one line, as a site in the list spells it."""
    code = " ".join(code.split())
    code = re.sub(r"([(\[{]) ", r"\1", code)
    return re.sub(r",? ([)\]}])", r"\1", code).rstrip(",")


def _constant(arg: str, path: str, consts: dict, classes: dict) -> bool:
    """Whether arg is a string literal, or a constant holding one, here or on a class."""
    if re.fullmatch(r'"[^"]*"', arg):
        return True
    if arg in consts.get(path, ()):
        return True
    qualified = re.fullmatch(r"(\w+)\.([A-Z_][A-Z0-9_]*)", arg)
    return bool(qualified) and qualified.group(2) in consts.get(classes.get(qualified.group(1)), ())


def check_sites(root: Path) -> int:
    tree = Tree(root)
    listed = {(p, c) for p, c, _ in read_sites(root)}
    found = set(runtime_sites(tree))
    fails = 0
    for path, call in sorted(found - listed):
        print(
            f"test-changed: {path}: {call} builds its path at runtime and is not in {SITES}"
            " — list it with the files it may load",
            file=sys.stderr,
        )
        fails = 1
    for path, call in sorted(listed - found):
        print(f"test-changed: {SITES} lists {path}: {call}, which the code no longer has", file=sys.stderr)
        fails = 1
    if not fails:
        print(f"test-changed: {len(found)} runtime load sites, every one listed")
    return fails


def git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(root), *args], check=True, capture_output=True, text=True
    ).stdout


def change_set(root: Path, base: str) -> tuple[list[str], str]:
    merge_base = git(root, "merge-base", "HEAD", base).strip()
    changed = set(git(root, "diff", "--name-only", "--no-renames", merge_base).split("\n"))
    changed |= set(git(root, "ls-files", "--others", "--exclude-standard").split("\n"))
    changed.discard("")
    return sorted(changed), merge_base


def old_classes(root: Path, merge_base: str | None, path: str) -> list[str]:
    """The class_names a deleted script declared at the merge-base."""
    if merge_base is None or not path.endswith(".gd"):
        return []
    try:
        return CLASS_NAME.findall(git(root, "show", f"{merge_base}:{path}"))
    except subprocess.CalledProcessError:
        return []


def full_suite_reason(path: str) -> str | None:
    if path in FULL_SUITE_FILES:
        return FULL_SUITE_FILES[path]
    for prefix, reason in FULL_SUITE_DIRS.items():
        if path.startswith(prefix):
            return reason
    return None


def no_test_file(path: str) -> bool:
    return (
        path.startswith(NO_TEST_DIRS)
        or Path(path).suffix in NO_TEST_SUFFIXES
        or os.path.basename(path) in NO_TEST_NAMES
        or os.path.basename(path).startswith("LICENSE")
    )


def select(root: Path, changed: list[str], merge_base: str | None = None) -> dict:
    """The selection: {"all": [reasons]} or {"tests": {test: chain}, "notes": [...]}."""
    reasons, notes = [], []
    for path in changed:
        reason = full_suite_reason(path)
        if reason:
            reasons.append(f"{path}: {reason}")
    tree = Tree(root, extra=set(changed))
    sites = read_sites(root)
    for path in changed:
        if path not in tree.files:
            for name in old_classes(root, merge_base, path):
                tree.classes.setdefault(name, path)
    tree.build(sites)
    back = tree.reverse()
    engine_wide = tree.reach(tree.autoloads)
    starts = []
    for path in changed:
        if full_suite_reason(path):
            continue
        if path in engine_wide:
            reasons.append(f"{path}: an autoload every engine runs reaches it")
            continue
        placed = (
            path in back
            or path in tree.edges
            or tree.is_resource(path)
            or path.endswith((".uid", ".import"))
        )
        if path in back:
            starts.append(path)
        elif path.startswith(PLACED_DIRS) and not no_test_file(path):
            reasons.append(f"{path}: a data file no edge reaches — the graph cannot place it")
        elif placed:
            starts.append(path)
        elif no_test_file(path):
            notes.append(f"{path}: no test loads it")
        else:
            reasons.append(f"{path}: a file the graph cannot place")
    if reasons:
        return {"all": reasons}
    parent: dict[str, str | None] = {p: None for p in starts}
    queue = deque(starts)
    while queue:
        here = queue.popleft()
        for source in sorted(back.get(here, ())):
            if source not in parent:
                parent[source] = here
                queue.append(source)
    tests = {}
    for path in sorted(parent):
        if is_test(path) and path in tree.files:
            chain, step = [path], parent[path]
            while step is not None:
                chain.append(step)
                step = parent[step]
            tests[path] = [
                (step, tree.why[(chain[i - 1], step)] if i else "changed")
                for i, step in enumerate(chain)
            ]
    godot = [p for p in starts if tree.is_resource(p) or p.endswith((".uid", ".import"))]
    return {"tests": tests, "notes": notes, "godot": godot}


def _count(count: int, noun: str) -> str:
    return f"{count} {noun}" + ("" if count == 1 else "s")


def report(selection: dict, changed: list[str], against: str) -> None:
    print(f"test-changed: {_count(len(changed), 'file')} changed {against}")
    for path in changed:
        print(f"    {path}")
    if "all" in selection:
        print("test-changed: the full suite runs —")
        for reason in selection["all"]:
            print(f"    {reason}")
        return
    tests = selection["tests"]
    for note in selection["notes"]:
        print(f"    {note}")
    if not tests:
        if not selection["godot"]:
            print("test-changed: no GDScript, resource or scene changed — no tests to run")
        else:
            print("test-changed: no test script reaches the changes — no tests to run")
        return
    verb = "reaches" if len(tests) == 1 else "reach"
    print(f"test-changed: {_count(len(tests), 'test script')} {verb} them")
    for test, chain in tests.items():
        print(f"    {test}" + "".join(f"\n        -> {step}  ({why})" for step, why in chain[1:]))


def main(argv: list[str]) -> int:
    root, base, changed, out = ROOT, "origin/main", None, None
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg == "--root" and args:
            root = Path(args.pop(0)).resolve()
        elif arg == "--base" and args:
            base = args.pop(0)
        elif arg == "--list" and args:
            out = Path(args.pop(0))
        elif arg == "--changed":
            changed, args = args, []
        elif arg == "--check-sites":
            return check_sites(root)
        else:
            print(__doc__, file=sys.stderr)
            return 2
    merge_base = None
    if changed is None:
        try:
            changed, merge_base = change_set(root, base)
        except subprocess.CalledProcessError as error:
            print(f"test-changed: git: {error.stderr.strip()}", file=sys.stderr)
            print(f"test-changed: no merge-base with {base} — fetch it, or pass --base", file=sys.stderr)
            return 1
        against = f"against {base} (merge-base {merge_base[:10]})"
    else:
        changed = sorted({posix(p).removeprefix("./") for p in changed})
        against = "as given"
    selection = select(root, changed, merge_base)
    report(selection, changed, against)
    if out is not None:
        # Read back line by line by bash: LF only, whatever the platform's own ending.
        if "all" in selection:
            out.write_text("ALL\n", newline="\n")
        else:
            out.write_text("".join(f"{t}\n" for t in selection["tests"]), newline="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
