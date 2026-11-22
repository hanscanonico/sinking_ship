import glob, collections, sys, os
"""scan_totals.py OUT [-e] : add up the sim_scan logs in OUT (-e lists how each match ended)."""
files = sorted(glob.glob(os.path.join(sys.argv[1], "*.log")))
tot = collections.Counter(); matches = collections.defaultdict(set); ticks = 0; n = 0
byship = collections.defaultdict(collections.Counter)
ends = []
for f in files:
    name = os.path.basename(f)[:-4]
    for line in open(f, encoding="utf-8", errors="replace"):
        if line.startswith("S|"):
            p = line.rstrip("\n").split("|")
            n += 1; ticks += int(p[5].split("=")[1])
            ends.append((name, p[5], p[6], p[7], p[8]))
            if len(p) > 11 and p[11]:
                for kv in p[11].split(","):
                    k, v = kv.split("="); tot[k] += int(v); matches[k].add(name); byship[p[1]][k] += int(v)
print("matches", n, "of", len(files), "ticks", ticks)
for k, v in tot.most_common():
    print("%-20s hits %6d  matches %3d  %s" % (k, v, len(matches[k]), " ".join("%s:%d" % (s, byship[s][k]) for s in sorted(byship) if byship[s][k])))
if "-e" in sys.argv:
    for e in ends: print(*e)
