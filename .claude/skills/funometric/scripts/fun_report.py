#!/usr/bin/env python3
"""The funometric's judging half: fun_scan.gd logs in, a Markdown verdict out.

    python3 fun_report.py LOG [LOG ...] [--journal JOURNAL.tsv ...] [--human-only]

Each LOG is one fun_scan.gd run (bots-only, or a replay with human seats). Every axis
below gets a value, a verdict (fun / meh / unfun) and the reason, across all the logs
given; seats a person played get their own lines. A JOURNAL is what the player wrote
while playing (see SKILL.md): its moments are listed beside the scan's beats around
them, so a feeling and what the sim says happened can be read together.

The bands are heuristics for a short, physical party brawl on a sinking ship — the
starting point for calibration, not truths. When a played journal keeps disagreeing
with a band, change the band here and say why in the commit.
"""

import argparse
import statistics
import sys
from pathlib import Path

# (axis, low, high, what low means, what in-band means, what high means, which side is bad)
# A value below `low` reads as the first text, between as the second, above as the third.
BANDS = {
    "first_contact": (3, 15, "brawl from the first second: no build-up, no choosing where to go",
                      "a few seconds to look round, then the first meeting",
                      "a slow start: seats wander before anyone meets"),
    "first_out": (30, 75, "someone's match is over before it began",
                  "the first loss comes once everyone has had a go",
                  "a long opening with nobody lost"),
    "near_pct": (25, 80, "lonely: seats spend most of their life with nobody near",
                 "contact with room to breathe: approach, fight, break off",
                 "a constant scrum: no positioning, no escape, no space to read the ship"),
    "lull": (12, 35, "never a breath: one thing straight after another",
             "quiet stretches short enough to stay tense",
             "dead air: a long stretch where nothing happens to a seat"),
    "shoved_share": (35, 85, "the sea decides: players rarely put each other out",
                     "players and the sinking both decide who goes",
                     "the sinking is backdrop: nearly every out is a shove"),
    "spectate_share": (0, 50, "", "out seats watch for a bearable part of the match",
                       "the out seats spend most of the match watching"),
    "close_calls": (0.5, 99, "no comebacks: nobody climbs out of the sea and lives",
                    "comebacks happen: a seat climbs back and survives", ""),
    "spectacle_gap": (0, 45, "", "the ship keeps doing something to look at",
                      "the ship goes quiet for long stretches"),
    "beats_per_min": (8, 40, "a seat's life is thin: few things happen to it",
                      "a steady run of things happening",
                      "frantic: more than a beat every two seconds"),
}
# Which side of each band is bad: "low", "high" or "both".
BAD_SIDE = {
    "first_contact": "both", "first_out": "low", "near_pct": "both", "lull": "high",
    "shoved_share": "both", "spectate_share": "high", "close_calls": "low",
    "spectacle_gap": "high", "beats_per_min": "both",
}


def verdict(axis, value):
    low, high, below, inside, above = BANDS[axis]
    bad = BAD_SIDE[axis]
    # Just outside the band (within a quarter of its edge) is meh, not unfun.
    if value < low:
        if bad not in ("low", "both"):
            return "fun", inside
        return ("meh" if value >= low * 0.75 else "unfun"), below
    if value > high:
        if bad not in ("high", "both"):
            return "fun", inside
        return ("meh" if value <= high * 1.25 else "unfun"), above
    return "fun", inside


def num(text):
    try:
        return float(text)
    except ValueError:
        return None


def read_log(path):
    match = {"path": path, "seats": [], "windows": [], "beats": [], "head": None, "end": None}
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        f = line.split("|")
        if f[0] == "H" and len(f) >= 8:
            match["head"] = dict(ship=f[1], seed=f[2], seats=int(f[3]), mode=f[4], source=f[5],
                                 humans=int(f[6]), live_from=float(f[7]))
        elif f[0] == "P" and len(f) >= 26:
            keys = ["seat", "human", "place", "cause", "credit", "alive_s", "first_contact_s",
                    "near_pct", "median_gap_m", "shoves_given", "shoves_taken", "kos", "water_in",
                    "climbed_out", "back_in", "bonuses", "grabs", "falls", "swim_s", "idle_pct",
                    "lull_s", "lull_from_s", "close_calls", "spectate_s", "beats_per_min"]
            row = dict(zip(keys, f[1:]))
            for k in keys:
                if k != "cause":
                    v = num(row[k])
                    row[k] = v if v is not None else row[k]
            match["seats"].append(row)
        elif f[0] == "T" and len(f) >= 8:
            match["windows"].append([float(x) for x in f[1:8]])
        elif f[0] == "E" and len(f) >= 5:
            match["beats"].append((float(f[1]), f[2], int(f[3]), int(f[4]), f[5] if len(f) > 5 else ""))
        elif f[0] == "M" and len(f) >= 11:
            match["end"] = dict(ticks=int(f[1]), live_s=float(f[2]), winner=int(f[3]),
                                first_out=num(f[4]), gaps=[float(x) for x in f[5].split(",") if x],
                                duel_s=num(f[6]), duel_shoves=int(f[7]), spectacle=int(f[8]),
                                last_cause=f[9], ending=f[10])
    if match["head"] is None or match["end"] is None:
        sys.exit(f"{path}: not a finished fun_scan log (no H or M line)")
    return match


def med(values):
    values = [v for v in values if isinstance(v, (int, float))]
    return statistics.median(values) if values else None


def spectacle_gap(m):
    times = [0.0] + sorted(b[0] for b in m["beats"] if b[2] == -1) + [m["end"]["live_s"]]
    return max(b - a for a, b in zip(times, times[1:]))


def axes_of(matches, seat_filter):
    seats = [s for m in matches for s in m["seats"] if seat_filter(s)]
    outs = [s for s in seats if s["cause"] != "in"]
    values = {
        "first_contact": med([s["first_contact_s"] for s in seats]),
        "first_out": med([m["end"]["first_out"] for m in matches]),
        "near_pct": med([s["near_pct"] for s in seats]),
        "lull": med([s["lull_s"] for s in seats]),
        "shoved_share": 100.0 * sum(1 for s in outs if s["cause"] == "shoved") / len(outs) if outs else None,
        "spectate_share": med([100.0 * s["spectate_s"] / m["end"]["live_s"]
                               for m in matches for s in m["seats"]
                               if seat_filter(s) and s["cause"] != "in" and m["end"]["live_s"] > 0]),
        "close_calls": statistics.mean([sum(s["close_calls"] for s in m["seats"] if seat_filter(s))
                                        for m in matches]),
        "spectacle_gap": med([spectacle_gap(m) for m in matches]),
        "beats_per_min": med([s["beats_per_min"] for s in seats]),
    }
    return values


UNITS = {"first_contact": "s", "first_out": "s", "near_pct": "%", "lull": "s", "shoved_share": "%",
         "spectate_share": "%", "close_calls": "/match", "spectacle_gap": "s", "beats_per_min": "/min"}
NAMES = {"first_contact": "Opening — first contact", "first_out": "First loss",
         "near_pct": "Interaction — time near an opponent", "lull": "Dead air — longest lull",
         "shoved_share": "Agency — outs that were shoves", "spectate_share": "Spectating — share watched",
         "close_calls": "Comebacks — survived climbs", "spectacle_gap": "Spectacle — longest quiet ship",
         "beats_per_min": "Density — beats a minute"}
MARK = {"fun": "✅ fun", "meh": "➖ meh", "unfun": "❌ unfun"}


def axis_table(values):
    out = ["| Axis | Value | Verdict | Why |", "|---|---|---|---|"]
    for axis, value in values.items():
        if value is None:
            out.append(f"| {NAMES[axis]} | – | – | not measured |")
            continue
        v, why = verdict(axis, value)
        out.append(f"| {NAMES[axis]} | {value:.1f} {UNITS[axis]} | {MARK[v]} | {why} |")
    return out


def finale(m):
    e = m["end"]
    if e["duel_s"] is None:
        return "no final two (everyone left at once or the match did not end)"
    if e["duel_shoves"] == 0:
        return f"final two for {e['duel_s']:.0f} s and **not one shove** between them — the sea picked the winner ({e['last_cause']})"
    if e["duel_s"] > 90 and e["duel_shoves"] < 4:
        return f"final two for {e['duel_s']:.0f} s with {e['duel_shoves']} shoves — a stand-off"
    return f"final two for {e['duel_s']:.0f} s, {e['duel_shoves']} shoves, decided by {e['last_cause']}"


def pacing(m):
    w = m["windows"]
    if len(w) < 3:
        return "too short to read a curve"
    third = max(1, len(w) // 3)
    heat = [x[2] + x[3] + 2 * x[4] + 3 * x[6] for x in w]  # encounters, shoves, water, outs
    first, last = sum(heat[:third]), sum(heat[-third:])
    shape = "builds to the end" if last > first * 1.2 else ("front-loaded: the carnage is early" if first > last * 1.5 else "flat")
    strip = "".join(" ▁▂▃▄▅▆▇█"[min(8, int(8 * h / max(heat)))] if max(heat) else " " for h in heat)
    return f"`{strip}` ({shape}; 15 s a column, heat = meetings + shoves + falls in + outs)"


def journal_section(paths, matches):
    rows = []
    for path in paths:
        for line in Path(path).read_text(encoding="utf-8").splitlines():
            if not line.strip() or line.startswith("#") or line.startswith("t_s"):
                continue
            f = line.split("\t")
            if len(f) >= 5:
                rows.append(dict(t=num(f[0]), feel=num(f[1]) or 0, axis=f[2], moment=f[3], why=f[4],
                                 shot=f[5] if len(f) > 5 else "", src=Path(path).name))
    if not rows:
        return []
    out = ["", "## What it felt like (journal)", ""]
    feels = [r["feel"] for r in rows]
    out.append(f"{len(rows)} moments, mean feel {statistics.mean(feels):+.2f} on −2…+2.")
    by_axis = {}
    for r in rows:
        by_axis.setdefault(r["axis"], []).append(r["feel"])
    out += ["", "| Axis | Moments | Mean feel |", "|---|---|---|"]
    for axis, fs in sorted(by_axis.items(), key=lambda kv: statistics.mean(kv[1])):
        out.append(f"| {axis} | {len(fs)} | {statistics.mean(fs):+.2f} |")
    human_beats = [b for m in matches if m["head"]["humans"] for b in m["beats"]
                   if b[2] < m["head"]["humans"] or b[3] in range(m["head"]["humans"]) or b[2] == -1]
    for title, pick in (("Best moments", sorted(rows, key=lambda r: -r["feel"])[:5]),
                        ("Worst moments", sorted(rows, key=lambda r: r["feel"])[:5])):
        out += ["", f"### {title}", ""]
        for r in pick:
            near = ""
            if r["t"] is not None and human_beats:
                close = [b for b in human_beats if abs(b[0] - r["t"]) <= 3]
                if close:
                    near = " — sim: " + ", ".join(f"{b[0]:.0f}s {b[1].lower()}" for b in close[:4])
            shot = f" ({r['shot']})" if r["shot"] else ""
            t = f"{r['t']:.0f} s" if r["t"] is not None else "–"
            out.append(f"- **{r['feel']:+.0f}** at {t}, *{r['axis']}*: {r['moment']} — {r['why']}{near}{shot}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--journal", action="append", default=[])
    args = ap.parse_args()
    matches = [read_log(p) for p in args.logs]
    out = ["# Funometric report", ""]
    out.append("| Match | Ship | Seed | Mode | Source | Live | Winner | First out | Finale |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for m in matches:
        h, e = m["head"], m["end"]
        fo = f"{e['first_out']:.0f} s" if e["first_out"] is not None else "–"
        out.append(f"| {Path(m['path']).stem} | {h['ship']} | {h['seed']} | {h['mode']} | {h['source']} "
                   f"| {e['live_s']:.0f} s | {e['winner']} | {fo} | {finale(m)} |")
    out += ["", "## Every seat (bots stand in for players, D10)", ""]
    out += axis_table(axes_of(matches, lambda s: True))
    if any(m["head"]["humans"] for m in matches):
        out += ["", "## The seats a person played", ""]
        out += axis_table(axes_of(matches, lambda s: s["human"] == 1))
        out += ["", "| Match | Seat | Place | Out by | Alive | Shoves given/taken | Water in / out | Longest lull (from) |",
                "|---|---|---|---|---|---|---|---|"]
        for m in matches:
            for s in m["seats"]:
                if s["human"] == 1:
                    out.append(f"| {Path(m['path']).stem} | {s['seat']:.0f} | {s['place']:.0f} | {s['cause']} "
                               f"| {s['alive_s']:.0f} s | {s['shoves_given']:.0f}/{s['shoves_taken']:.0f} "
                               f"| {s['water_in']:.0f}/{s['climbed_out']:.0f} | {s['lull_s']:.0f} s ({s['lull_from_s']:.0f} s) |")
    out += ["", "## Pacing", ""]
    for m in matches:
        out.append(f"- {Path(m['path']).stem}: {pacing(m)}")
    out += journal_section(args.journal, matches)
    print("\n".join(out))


if __name__ == "__main__":
    main()
