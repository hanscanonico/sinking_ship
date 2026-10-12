# The window lock's file, one answer for tools/window_lock.sh, which takes it,
# and tools/fps.sh, which trusts a held lock only when it is this same file:
# $WINDOW_LOCK, /tmp/sinking_ship_window.flock by default.

WINDOW_LOCK_FILE="${WINDOW_LOCK:-/tmp/sinking_ship_window.flock}"
