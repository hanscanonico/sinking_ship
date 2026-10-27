# The memory the system can still hand a new engine, for tools/test_slot.sh's floor, one
# answer for every system the game is made on: MemAvailable where /proc/meminfo has it
# (Linux), MemFree where it does not (Git Bash, whose MemFree is what Windows calls
# available physical memory — the standby cache counted in, as MemAvailable counts it),
# and on macOS vm_stat's free, inactive, speculative and purgeable pages.
#
# free_memory_mb prints that in MB, and total_memory_mb the machine's whole memory;
# each prints nothing where no source answers. FREE_MEMORY_FILE, a file holding a count
# of MB, stands in for the system's answer (the checks), read afresh on every call.

free_memory_mb() {
	if [[ -n "${FREE_MEMORY_FILE-}" ]]; then
		tr -dc '0-9' <"$FREE_MEMORY_FILE" 2>/dev/null
		return 0
	fi
	if [[ -r /proc/meminfo ]]; then
		awk '/^MemAvailable:/ { a = $2 } /^MemFree:/ { f = $2 }
			END { k = a ? a : f; if (k) print int(k / 1024) }' /proc/meminfo
	elif command -v vm_stat >/dev/null; then
		vm_stat | awk '/page size of/ { size = $8 }
			/^Pages (free|inactive|speculative|purgeable):/ { gsub(/\./, "", $NF); pages += $NF }
			END { if (size && pages) print int(pages * size / 1048576) }'
	fi
}

total_memory_mb() {
	if [[ -r /proc/meminfo ]]; then
		awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo
	else
		local bytes
		bytes=$(sysctl -n hw.memsize 2>/dev/null) && [[ -n "$bytes" ]] && echo $((bytes / 1048576))
	fi
}
