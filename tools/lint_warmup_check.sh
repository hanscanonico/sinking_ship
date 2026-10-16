#!/usr/bin/env bash
#
# `make guard-check`, its eighth part: `make lint`, `make format-check` and `make
# format` run their tool once on a single file before fanning out through xargs,
# so gdtoolkit's parser cache directory exists before parallel workers race to
# makedirs it (the losers print "File exists" and fail). The warm-up's file is not
# handed to the workers again. Read off `make -n`, so no gdtoolkit runs.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
# Whether `make -n TARGET` warms TOOL up on one file, chained with && so its
# failure fails the target, before the xargs fan-out runs the same TOOL.
warms_up() {
	local target=$1 tool=$2 line first
	line=$(make -n "$target" | grep -F 'xargs')
	case $line in
	"$tool "*" && printf "*"| xargs -0 -P "*" -n 60 $tool") ;;
	*)
		echo "lint-warmup-check: make $target has no single-file $tool warm-up before xargs" >&2
		return 1
		;;
	esac
	first=${line#"$tool "}
	first=${first%% *}
	case $first in
	*.gd) ;;
	*)
		echo "lint-warmup-check: make $target warms up on '$first', not one .gd file" >&2
		return 1
		;;
	esac
	case " ${line#*printf } " in
	*" $first "*)
		echo "lint-warmup-check: make $target hands $first to the workers again" >&2
		return 1
		;;
	esac
}

warms_up lint gdlint || fails=1
warms_up format-check "gdformat --check" || fails=1
warms_up format gdformat || fails=1
exit "$fails"
