#!/usr/bin/env bash
#
# Installs Debian packages on a CI runner without letting a stuck mirror hold the job
# until GitHub cancels it (#459: one shard sat 40 minutes in `apt-get update`, a
# native build 20 in its install). Each `apt-get update` and `apt-get install` runs
# under its own `timeout`, with apt's own retries and a short network timeout, and
# the pair is tried up to three times: a hung mirror ends an attempt in minutes and
# the next one usually gets through. Worst case, about 12 minutes and a red step.
#
# Usage:  tools/ci_apt_install.sh PACKAGE...

set -uo pipefail

if [ $# -eq 0 ]; then
	echo "usage: $0 PACKAGE..." >&2
	exit 2
fi

attempts=3
update_seconds=60
install_seconds=150
apt_opts=(-o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30)

for attempt in $(seq 1 "$attempts"); do
	if timeout --kill-after=10 "$update_seconds" sudo apt-get "${apt_opts[@]}" update -qq &&
		timeout --kill-after=10 "$install_seconds" sudo apt-get "${apt_opts[@]}" install -y --no-install-recommends "$@"; then
		exit 0
	fi
	echo "ci_apt_install: attempt $attempt/$attempts failed or timed out" >&2
	if [ "$attempt" -lt "$attempts" ]; then
		# An install cut short can leave dpkg half-configured; settle it before the retry.
		sudo dpkg --configure -a || true
		sleep 10
	fi
done
echo "ci_apt_install: giving up after $attempts attempts" >&2
exit 1
