#!/usr/bin/env bash
#
# `make guard-check`, its fourth part: `make fps` hands tools/fps.sh --split only
# when SPLIT is set to something other than 0 — SPLIT=1 splits, SPLIT=0 and no
# SPLIT do not. Read off `make -n`, so no engine runs.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
# Whether `make fps` with the arguments given would pass --split.
splits() {
	make -n fps GODOT=godot "$@" | grep -q -- '--split'
}

splits SPLIT=1 || {
	echo "fps-split-check: SPLIT=1 does not split" >&2
	fails=1
}
for off in SPLIT=0 SPLIT=; do
	splits "$off" && {
		echo "fps-split-check: $off splits" >&2
		fails=1
	}
done
splits && {
	echo "fps-split-check: no SPLIT splits" >&2
	fails=1
}
exit "$fails"
