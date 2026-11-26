"""hunt.py [guard] [SEAT] ["extra cmds"] : one go at a rival in a `make play` session.

Run from the checkout the session plays in. Reads the last turn's answer for the rivals'
distance and bearing ("seat 3 GROUNDED 4.1 m, -72° right, …") and turns toward SEAT (the
nearest grounded one when not given). Hunting, it runs to arm's length and shoves.
`guard` holds its ground instead: braced and facing them, shoving only one in reach —
the cautious player's turn. Then it prints the new answer without the screen's words.
It aims; it does not steer round a deckhouse: when a leg ends no closer, walk round with
playtest's go.py and hunt again.
"""
import glob
import re
import subprocess
import sys

RUN = 4.8  # m/s, walk speed
REACH = 1.3  # m, where the shove is thrown from
args = sys.argv[1:]
guard = bool(args) and args[0] == "guard"
if guard:
    args = args[1:]
want = int(args[0]) if args and args[0].isdigit() else None
after = args[-1] if args and not args[-1].isdigit() else ""
last = sorted(glob.glob("captures/play/out/*.txt"))[-1]
text = open(last, encoding="utf-8").read()
# Only rivals on this level: one a deck above or below is out of reach however near.
rivals = [(int(s), float(d), float(b)) for s, d, b, up in
          re.findall(r"seat (\d+) GROUNDED ([\d.]+) m, ([-\d.]+)° right, ([-\d.]+) m up", text)
          if abs(float(up)) <= 1.0]
if want is not None:
    rivals = [r for r in rivals if r[0] == want]
if not rivals:
    sys.exit("hunt: no grounded rival on this level in " + last)
seat, dist, bearing = min(rivals, key=lambda r: r[1])
if guard:
    act = "tap shove; wait 12" if dist <= REACH + 0.4 else "hold brace; wait 20; release all"
    cmds = f"turn {bearing:.0f}; wait 2; {act}; shot guard{seat}"
else:
    frames = max(0, round((dist - REACH) / RUN * 30))
    cmds = f"turn {bearing:.0f}; wait 2; hold move_up; wait {frames}; tap shove; wait 12; release all; shot hunt{seat}"
if after:
    cmds += "; " + after
print(f"{'guard' if guard else 'hunt'}: seat {seat}, {dist} m at {bearing}°")
out = subprocess.run(["bash", "-c", "timeout 580 tools/play.sh \"$0\"", cmds], capture_output=True,
                     text=True, encoding="utf-8", errors="replace").stdout
print("\n".join(line for line in out.splitlines() if not line.startswith('  "')
                and not line.startswith("  button") and not line.startswith("  choice")))
