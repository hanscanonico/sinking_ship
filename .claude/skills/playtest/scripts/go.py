"""go.py X Z ["extra cmds"] : one walking leg in a `make play` session.

Run from the checkout the session plays in. Reads the last turn's answer for the
ghost's (else the seat's) position and facing, turns toward ship-space (X, Z) and
walks there at walk speed, then prints the new answer without the screen's words.
A rail, a door post or a stair foot stops a leg: read the `me:` / `ghost:` line.
"""
import glob
import math
import re
import subprocess
import sys

WALK = 4.8  # m/s
x, z = float(sys.argv[1]), float(sys.argv[2])
after = sys.argv[3] if len(sys.argv) > 3 else ""
last = sorted(glob.glob("captures/play/out/*.txt"))[-1]
text = open(last, encoding="utf-8").read()
pat = r"%s: \w+ at \(([-\d.]+), ([-\d.]+), ([-\d.]+)\).*facing ([-\d.]+)"
m = re.search(pat % "ghost", text) or re.search(pat % "me", text)
if not m:
    sys.exit("go: no me: or ghost: line in " + last)
mx, _my, mz, facing = map(float, m.groups())
turn = (math.degrees(math.atan2(z - mz, x - mx)) - facing + 180) % 360 - 180
frames = max(1, round(math.hypot(x - mx, z - mz) / WALK * 30))
cmd = f"turn {turn:.0f}; hold move_up; wait {frames}; release all; wait 4"
if after:
    cmd += "; " + after
print("go:", cmd)
out = subprocess.run(
    ["bash", "tools/play.sh", cmd], capture_output=True, text=True, encoding="utf-8"
).stdout
skip = r'  ("|button|tick|choice|hslider|field|seat)'
print("\n".join([l for l in out.splitlines() if not re.match(skip, l)][:26]))
