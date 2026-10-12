# The window lock's file, one answer for tools/window_lock.sh, which takes it,
# and tools/fps.sh, which trusts a held lock only when it is this same file:
# $WINDOW_LOCK, /tmp/sinking_ship_window.flock by default. Paths are compared
# resolved — absolute, through any symlinked directory — so two spellings of one
# file (/tmp and /private/tmp on a Mac, a relative path) are the same lock.

# The absolute physical path of the file $1, which need not exist yet: its
# directory resolved, its own name kept. A directory that cannot be entered
# leaves the path as it was given.
window_lock_resolve() {
	local dir
	dir=$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P) || {
		printf '%s\n' "$1"
		return
	}
	printf '%s/%s\n' "${dir%/}" "$(basename -- "$1")"
}

# Whether this process runs under a holder of this same lock file.
window_lock_held() {
	[[ -n "${WINDOW_LOCK_HELD-}" ]] &&
		[[ "$(window_lock_resolve "$WINDOW_LOCK_HELD")" == "$WINDOW_LOCK_FILE" ]]
}

WINDOW_LOCK_FILE=$(window_lock_resolve "${WINDOW_LOCK:-/tmp/sinking_ship_window.flock}")
