#!/usr/bin/env bash
#
# Installs Debian packages on a CI runner without letting a stuck mirror hold the job
# until GitHub cancels it (#459: one shard sat 40 minutes in `apt-get update`, a
# native build 20 in its install). Each `apt-get update` and `apt-get install` runs
# under its own `timeout`, with apt's own retries and a short network timeout, and
# the pair is tried up to three times: a hung mirror ends an attempt in minutes and
# the next one usually gets through. Worst case, about 12 minutes and a red step.
#
# With CI_APT_DEBS set to a directory (an actions/cache path), the mirror is skipped
# when that directory holds the packages' .debs: they are installed with `dpkg -i`,
# each one only when the runner does not already have that version or newer. A miss,
# or a local install that fails, takes the mirror as above, and its downloaded .debs
# then replace the directory's for the cache to save. For a package too big for a
# slow mirror to serve in the install limit (#465: 133 MB of mingw-w64 at 50 KB/s).
#
# Usage:  [CI_APT_DEBS=DIR] tools/ci_apt_install.sh PACKAGE...

set -uo pipefail

if [ $# -eq 0 ]; then
	echo "usage: $0 PACKAGE..." >&2
	exit 2
fi

attempts=3
update_seconds=60
install_seconds=150
apt_opts=(-o Acquire::Retries=3 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30)
debs_dir=${CI_APT_DEBS:-}
archives=/var/cache/apt/archives

# Every package asked for is installed.
all_installed() {
	local pkg
	for pkg in "$@"; do
		[ "$(dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null)" = installed ] || return 1
	done
}

# Installs the packages from $debs_dir's .debs alone; fails when there are none or
# dpkg does, and the mirror then takes over.
install_local() {
	local debs=() todo=() deb name version have
	shopt -s nullglob
	debs=("$debs_dir"/*.deb)
	shopt -u nullglob
	if [ ${#debs[@]} -eq 0 ]; then
		echo "ci_apt_install: no cached .debs in $debs_dir" >&2
		return 1
	fi
	for deb in "${debs[@]}"; do
		name=$(dpkg-deb -f "$deb" Package) || return 1
		version=$(dpkg-deb -f "$deb" Version) || return 1
		have=$(dpkg-query -W -f='${db:Status-Status} ${Version}' "$name" 2>/dev/null)
		# Never downgrade what the runner image already carries.
		if [ "${have%% *}" = installed ] && dpkg --compare-versions "${have#* }" ge "$version"; then
			continue
		fi
		todo+=("$deb")
	done
	echo "ci_apt_install: installing ${#todo[@]} of ${#debs[@]} cached .debs from $debs_dir"
	if [ ${#todo[@]} -gt 0 ]; then
		sudo dpkg -i "${todo[@]}" || return 1
	fi
	all_installed "$@"
}

# The .debs this run downloaded, for the cache to save in place of the old ones.
keep_debs() {
	mkdir -p "$debs_dir" &&
		rm -f "$debs_dir"/*.deb &&
		find "$archives" -maxdepth 1 -name '*.deb' -exec cp -t "$debs_dir" {} + &&
		echo "ci_apt_install: kept $(find "$debs_dir" -maxdepth 1 -name '*.deb' | wc -l) .debs in $debs_dir"
}

fix=()
if [ -n "$debs_dir" ]; then
	if install_local "$@"; then
		exit 0
	fi
	echo "ci_apt_install: cached .debs did not install; going to the mirror" >&2
	# A dpkg -i cut short leaves dependencies unmet; let apt settle them.
	sudo dpkg --configure -a || true
	fix=(--fix-broken)
	apt_opts+=(-o APT::Keep-Downloaded-Packages=true)
fi

for attempt in $(seq 1 "$attempts"); do
	if timeout --kill-after=10 "$update_seconds" sudo apt-get "${apt_opts[@]}" update -qq &&
		timeout --kill-after=10 "$install_seconds" sudo apt-get "${apt_opts[@]}" install -y --no-install-recommends "${fix[@]}" "$@"; then
		if [ -n "$debs_dir" ]; then
			keep_debs || echo "ci_apt_install: could not keep the .debs; the cache stays as it was" >&2
		fi
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
