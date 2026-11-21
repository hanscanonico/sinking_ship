#!/usr/bin/env bash
#
# `make guard-check`: tools/native_ensure.sh, against a throwaway tree with a stand-in
# build and a stand-in engine. A library carrying native/src's digest is left alone and
# nothing is said; a missing one and a stale one are built, and the extension imported
# once when .godot does not list it; a machine with no scons says so and goes on; a
# failed build fails; NATIVE_ENSURE=0 does nothing. The digest is held to
# native/SConstruct's own, worked out by Python as SCons works it out.

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() {
	echo "native-ensure-check: $*" >&2
	exit 1
}

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) platform=windows ;;
Darwin) platform=macos ;;
*) platform=linux ;;
esac

tree="$WORK/tree"
mkdir -p "$tree/tools/lib" "$tree/native/src" "$tree/.godot" "$WORK/bin"
cp "$here/native_ensure.sh" "$tree/tools/"
cp "$here/lib/require_godot.sh" "$tree/tools/lib/"
printf 'int b;\n' >"$tree/native/src/b.cpp"
printf 'int a;\n' >"$tree/native/src/a.h"
printf 'int Z;\n' >"$tree/native/src/Z.cpp"
printf 'not a source\n' >"$tree/native/src/notes.txt"

# What native/SConstruct builds into the library (source_digest).
cat >"$WORK/digest.py" <<'EOF'
import hashlib
import os
import sys

folder = sys.argv[1]
digest = hashlib.sha256()
for name in sorted(n for n in os.listdir(folder) if n.endswith((".cpp", ".h"))):
    with open(os.path.join(folder, name), "rb") as source:
        data = source.read()
    digest.update("{}\n{}\n".format(name, len(data)).encode("utf-8"))
    digest.update(data)
print(digest.hexdigest())
EOF
digest="$(python3 "$WORK/digest.py" "$tree/native/src" | tr -d '\r')"
[[ ${#digest} == 64 ]] || fail "no digest of the stand-in sources"

# The stand-in build writes a library carrying DIGEST_BUILT and counts its runs; the
# stand-in engine counts its imports; the stand-in scons is only there to be found.
library="$tree/native/lib/libsinking_native.$platform.x86_64.so"
cat >"$tree/tools/native_build.sh" <<EOF
#!/usr/bin/env bash
echo build >>"$WORK/builds"
[[ -z "\${BUILD_FAILS-}" ]] || { echo "stand-in: no compiler today" >&2; exit 1; }
mkdir -p "$tree/native/lib"
printf 'ELF\0%s\0' "\$DIGEST_BUILT" >"$library"
: >"$tree/native/lib/sinking_native.gdextension"
EOF
printf '#!/usr/bin/env bash\necho import >>"%s/imports"\n' "$WORK" >"$WORK/bin/godot"
printf '#!/usr/bin/env bash\nexit 0\n' >"$WORK/bin/scons"
chmod +x "$tree/tools/native_build.sh" "$WORK/bin/godot" "$WORK/bin/scons"

count() {
	[[ -e "$WORK/$1" ]] && grep -c . "$WORK/$1" || echo 0
}
ensure() {
	GODOT="$WORK/bin/godot" SCONS="$WORK/bin/scons" LLVM_MINGW="$WORK" DIGEST_BUILT="$digest" \
		"$tree/tools/native_ensure.sh" "$@" 2>&1
}

# No library: built, and imported, as .godot lists no extension.
said="$(ensure)" || fail "a missing library's build failed: $said"
[[ "$(count builds)" == 1 ]] || fail "a missing library was built $(count builds) times, not once: $said"
[[ "$(count imports)" == 1 ]] || fail "a new extension was imported $(count imports) times, not once"
grep -q 'has no library' <<<"$said" || fail "a missing library was not named: $said"

# Built from these sources: nothing run, nothing said.
said="$(ensure)" || fail "a fresh library failed: $said"
[[ -z "$said" ]] || fail "a fresh library was not left in silence: $said"
[[ "$(count builds)" == 1 ]] || fail "a fresh library was built again"

# A source changed: stale, built again; the extension is listed now, so no import.
echo 'res://native/lib/sinking_native.gdextension' >"$tree/.godot/extension_list.cfg"
printf 'int a2;\n' >>"$tree/native/src/a.h"
digest="$(python3 "$WORK/digest.py" "$tree/native/src" | tr -d '\r')"
said="$(ensure)" || fail "a stale library's build failed: $said"
[[ "$(count builds)" == 2 ]] || fail "a stale library was not built again: $said"
[[ "$(count imports)" == 1 ]] || fail "a listed extension was imported again"
grep -q 'other sources' <<<"$said" || fail "a stale library was not named: $said"
said="$(ensure)" && [[ -z "$said" ]] || fail "the rebuilt library is not fresh — the digests differ: $said"

# --no-import builds and leaves the import to its caller.
rm -f "$library" "$tree/.godot/extension_list.cfg"
said="$(ensure --no-import)" || fail "--no-import failed: $said"
[[ "$(count builds)" == 3 && "$(count imports)" == 1 ]] || fail "--no-import imported, or did not build"

# No scons: said in a line, nothing built, and the run goes on.
rm -f "$library"
said="$(GODOT="$WORK/bin/godot" SCONS="$WORK/bin/no-such-scons" LLVM_MINGW="$WORK" \
	"$tree/tools/native_ensure.sh" 2>&1)" || fail "a machine with no scons failed the run: $said"
grep -q 'no scons' <<<"$said" || fail "a machine with no scons was not told: $said"
[[ "$(count builds)" == 3 ]] || fail "a build ran with no scons"

# NATIVE_ENSURE=0: nothing at all.
said="$(NATIVE_ENSURE=0 ensure)" && [[ -z "$said" ]] || fail "NATIVE_ENSURE=0 did something: $said"
[[ "$(count builds)" == 3 ]] || fail "NATIVE_ENSURE=0 built"

# A build that fails fails, with what it said.
said="$(BUILD_FAILS=1 ensure)" && fail "a failed build passed"
grep -q 'no compiler today' <<<"$said" || fail "a failed build's output was not shown: $said"

echo "native-ensure-check: ok"
