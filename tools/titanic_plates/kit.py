#!/usr/bin/env python3
"""The tracing kit for the Titanic's plates (#360): fetch a plate, look at it, draft a
deck from it, and draw a traced deck back over it.

A dev tool, as `make models` is: it needs numpy, OpenCV and Pillow
(tools/titanic_plates/requirements.txt), and nothing in `make verify` runs it. What it
helps write — each deck's file beside it (boat.py, …) — is plain data that deck.py reads
without them, so the generator and CI never need the kit.

The plates are fetched into a cache outside the repo, never committed:
$XDG_CACHE_HOME/sinking_ship/plates (~/.cache when unset), each checked against
plates.tsv's SHA-256.

Usage, from the repo's root, with the requirements installed:

    tools/titanic_plates/kit.py fetch [PLATE ...]       # the plates (all when none named)
    tools/titanic_plates/kit.py look PLATE X0 Y0 X1 Y1 OUT.png [--scale S] [--grid N]
        # a crop of the plate in its own pixels, gridded every N px (100) and labelled,
        # to read a piece's pixels off by eye
    tools/titanic_plates/kit.py draft DECK [--run N]     # the straight lines of a deck's
        # view (its file's CROP), along her and across her: a bulkhead's or a wall's pixels
    tools/titanic_plates/kit.py rooms DECK [--out O.png] [--crop X0 Y0 X1 Y1]   # the
        # spaces its lines close round, proposed as ROOMS, numbered over the view
    tools/titanic_plates/kit.py overlay DECK OUT.png [--scale S] [--crop X0 Y0 X1 Y1]
        # the deck's file drawn over its view: the walls deck.py derives red (steel
        # thick), its doors green, rooms blue, solids grey, raised floors green
        # outlines, stairs gold (a dot at the high end), calibration magenta
"""
import argparse
import hashlib
import importlib.util
import os
import sys
import urllib.request
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "sinking_ship" / "plates"


def plates():
    """plates.tsv by plate: (leaf, url, width, height, sha256)."""
    rows = {}
    lines = (HERE / "plates.tsv").read_text().splitlines()
    for line in lines[1:]:
        plate, leaf, url, width, height, sha = line.split("\t")
        rows[plate] = (leaf, url, int(width), int(height), sha)
    return rows


def _sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch(plate):
    """The plate's scan in the cache, downloaded when missing or not the one plates.tsv
    names."""
    _leaf, url, _w, _h, sha = plates()[plate]
    path = CACHE / ("%s.jpg" % plate)
    if path.exists() and _sha(path) == sha:
        return path
    CACHE.mkdir(parents=True, exist_ok=True)
    part = path.with_suffix(".part")
    print("fetching plate %s from %s" % (plate, url), file=sys.stderr)
    urllib.request.urlretrieve(url, part)
    got = _sha(part)
    if got != sha:
        part.unlink()
        sys.exit("plate %s: got sha256 %s, plates.tsv says %s" % (plate, got, sha))
    part.replace(path)
    return path


def load(plate):
    """The plate in grey, its own pixels."""
    image = cv2.imread(str(fetch(plate)), cv2.IMREAD_GRAYSCALE)
    _leaf, _url, width, height, _sha = plates()[plate]
    assert image.shape == (height, width), (plate, image.shape)
    return image


def deck_file(name):
    """The deck's file beside this one, as a module."""
    spec = importlib.util.spec_from_file_location("deck_" + name, HERE / ("%s.py" % name))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _gridded(crop, x0, y0, step, scale):
    """The crop in colour, scaled, with a labelled line every step plate pixels."""
    colour = cv2.cvtColor(crop, cv2.COLOR_GRAY2BGR)
    if scale != 1.0:
        colour = cv2.resize(colour, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    if step <= 0:
        return colour
    h, w = colour.shape[:2]
    for px in range((x0 // step + 1) * step, x0 + int(w / scale), step):
        at = int((px - x0) * scale)
        cv2.line(colour, (at, 0), (at, h), (255, 160, 0), 1)
        cv2.putText(colour, str(px), (at + 2, 12), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 90, 0), 1)
    for py in range((y0 // step + 1) * step, y0 + int(h / scale), step):
        at = int((py - y0) * scale)
        cv2.line(colour, (0, at), (w, at), (255, 160, 0), 1)
        cv2.putText(colour, str(py), (2, at - 2), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 90, 0), 1)
    return colour


def look(plate, x0, y0, x1, y1, out, scale=1.0, grid=100):
    crop = load(plate)[y0:y1, x0:x1]
    cv2.imwrite(out, _gridded(crop, x0, y0, grid, scale))


def ink_of(crop):
    """Ink: darker than the paper about it; the scans' paper is uneven."""
    return cv2.adaptiveThreshold(crop, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY_INV, 51, 25)


def runs(ink, along, run):
    """The ink's straight runs at least run px long along x ('h') or y ('v'): each
    (at, from, to, thickness) in the crop's pixels, at its middle across."""
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (run, 1) if along == "h" else (1, run))
    lines = cv2.morphologyEx(ink, cv2.MORPH_OPEN, kernel)
    count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(lines, 8)
    found = []
    for x, y, w, h, _area in stats[1:]:
        if along == "h":
            found.append((y + (h - 1) / 2.0, x, x + w - 1, h))
        else:
            found.append((x + (w - 1) / 2.0, y, y + h - 1, w))
    return found


def merged(found, slack=2.5, gap=8):
    """Runs on one line (their middles within slack px) joined across gaps up to gap px."""
    found = sorted(found)
    lines = []
    for at, a, b, thick in found:
        for line in lines:
            if abs(line[0] - at) <= slack and a <= line[2] + gap and b >= line[1] - gap:
                weight = line[2] - line[1] + 1, b - a + 1
                line[0] = (line[0] * weight[0] + at * weight[1]) / (weight[0] + weight[1])
                line[1], line[2] = min(line[1], a), max(line[2], b)
                line[3] = max(line[3], thick)
                break
        else:
            lines.append([at, a, b, thick])
    return lines


def snap(plate, along, near, low, high, reach=25, run=25):
    """The middle of the straight line nearest near (a plate x for a line across her,
    'v'; a plate y for one along her, 'h') within reach px, read over the band from low
    to high on the other axis; None when there is none."""
    image = load(plate)
    if along == "v":
        crop = image[low:high, max(near - reach - run, 0):near + reach + run]
        origin = max(near - reach - run, 0)
    else:
        crop = image[max(near - reach - run, 0):near + reach + run, low:high].T
        origin = max(near - reach - run, 0)
    found = runs(ink_of(np.ascontiguousarray(crop)), "v", run)
    best = None
    for at, a, b, _thick in found:
        if abs(at + origin - near) <= reach and (best is None or b - a > best[1]):
            best = (at + origin, b - a)
    return None if best is None else round(best[0], 1)


def draft(name, run=25, least=40):
    """The straight lines of a deck's view at least `least` px long, along her and across
    her, each where it stands on the plate: what to read a room's edges and a bulkhead's
    place off."""
    module = deck_file(name)
    x0, y0, x1, y1 = module.CROP
    crop = load(module.PLATE)[y0:y1, x0:x1]
    ink = ink_of(crop)
    for along, title in [("h", "H_WALLS"), ("v", "V_WALLS")]:
        lines = merged(runs(ink, along, run))
        print("%s = [  # drafted: (%s, from, to, kind)" % (title, "plate y" if along == "h" else "plate x"))
        for at, a, b, thick in sorted(lines, key=lambda line: (line[0], line[1])):
            if b - a + 1 < least:
                continue
            offset = (y0, x0) if along == "h" else (x0, y0)
            kind = "steel" if thick >= 7 else "partition"
            print("    (%d, %d, %d, %r),  # %d px thick" % (
                round(at + offset[0]), a + offset[1], b + offset[1], kind, thick))
        print("]")


def regions(name, out=None, run=25, close=5, least=1500, crop_box=None):
    """The deck's enclosed spaces proposed from its view: the paper the walls close
    round, each (x0, y0, x1, y1) in plate pixels — its bounding box to its walls'
    middles — with how much of that box it fills. Printed in ROOMS' shape; out, when
    given, numbers them over the view."""
    module = deck_file(name)
    x0, y0, x1, y1 = crop_box or module.CROP
    crop = load(module.PLATE)[y0:y1, x0:x1]
    ink = ink_of(crop)
    walls = np.zeros_like(ink)
    for along in ("h", "v"):
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (run, 1) if along == "h" else (1, run))
        walls |= cv2.morphologyEx(ink, cv2.MORPH_OPEN, kernel)
    walls = cv2.dilate(walls, cv2.getStructuringElement(cv2.MORPH_RECT, (close, close)))
    count, labels, stats, _centroids = cv2.connectedComponentsWithStats(cv2.bitwise_not(walls), 4)
    found = []
    for k in range(1, count):
        x, y, w, h, area = stats[k]
        if area < least or x == 0 or y == 0 or x + w >= walls.shape[1] or y + h >= walls.shape[0]:
            continue
        # To the walls' middles: the dilation and half a wall's ink took ~close px off.
        grow = (close + 3) // 2
        found.append((x + x0 - grow, y + y0 - grow, x + w - 1 + x0 + grow, y + h - 1 + y0 + grow, area / float(w * h)))
    found.sort(key=lambda r: (r[0], r[1]))
    print("ROOMS = [  # drafted: (name, x0, y0, x1, y1)")
    for k, (a, b, c, d, fill) in enumerate(found):
        print("    (%r, %d, %d, %d, %d),  # %d: fills %.0f%% of its box" % ("?", a, b, c, d, k, fill * 100))
    print("]")
    if out:
        image = _gridded(crop, x0, y0, 0, 1.0)
        image = (image * 0.6 + 100).astype(np.uint8)
        for k, (a, b, c, d, fill) in enumerate(found):
            colour = (220, 120, 0) if fill > 0.9 else (0, 120, 230)
            cv2.rectangle(image, (a - x0, b - y0), (c - x0, d - y0), colour, 2)
            cv2.putText(image, str(k), (a - x0 + 4, b - y0 + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.6, colour, 2)
        cv2.imwrite(out, image)


def overlay(name, out, scale=1.0, crop_box=None):
    """The deck's file drawn over its view."""
    module = deck_file(name)
    x0, y0, x1, y1 = crop_box or module.CROP
    image = _gridded(load(module.PLATE)[y0:y1, x0:x1], x0, y0, 0, 1.0)
    image = (image * 0.55 + 110).astype(np.uint8)

    def p(x, y):
        return int(round(x - x0)), int(round(y - y0))

    for _what, x_a, y_a, x_b, y_b, _top in getattr(module, "SOLIDS", []):
        cv2.rectangle(image, p(x_a, y_a), p(x_b, y_b), (150, 150, 150), -1)
    for what, x_a, y_a, x_b, y_b in getattr(module, "ROOMS", []):
        cv2.rectangle(image, p(x_a + 3, y_a + 3), p(x_b - 3, y_b - 3), (220, 120, 0), 1)
        cv2.putText(image, what[:16], (p(x_a, y_a)[0] + 4, p(x_a, y_a)[1] + 14),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.38, (160, 60, 0), 1)
    for _name, x_a, y_a, x_b, y_b, rises, _lower, _upper in getattr(module, "STAIRS", []):
        cv2.rectangle(image, p(x_a, y_a), p(x_b, y_b), (0, 180, 230), 3)
        high = {"fore": (x_b, (y_a + y_b) / 2), "aft": (x_a, (y_a + y_b) / 2),
                "port": ((x_a + x_b) / 2, y_a), "starboard": ((x_a + x_b) / 2, y_b)}[rises]
        cv2.circle(image, p(*high), 6, (0, 140, 200), -1)
    for _what, x_a, y_a, x_b, y_b, _h in getattr(module, "RAISED", []):
        cv2.rectangle(image, p(x_a, y_a), p(x_b, y_b), (0, 150, 90), 2)
    # The walls deck.py derives, drawn back on the plate through the view's inverse; for a
    # part of a deck drawn in several views (deck.py's PARTS), the whole deck's, joined.
    sys.path.insert(0, str(HERE))
    import deck as deck_module  # noqa: E402

    whole = next((f.stem for f in sorted(HERE.glob("*.py")) if f.stem not in ("deck", "kit", "deck_check", "__init__")
                  and name in getattr(deck_file(f.stem), "PARTS", [])), None)
    traced = deck_module.load(whole or name)
    view = deck_module.View(module.X, module.Z)
    for axis, at, a, b, kind, doors in traced.walls:
        if axis == 0:
            px = view.px(at)
            ends = [(px, view.py(px, a)), (px, view.py(px, b))]
        else:
            ends = [(view.px(a), view.py(view.px(a), at)), (view.px(b), view.py(view.px(b), at))]
        cv2.line(image, p(*ends[0]), p(*ends[1]), (0, 0, 230), 5 if kind == "steel" else 2)
        for along in doors:
            if axis == 0:
                at_px = (view.px(at), view.py(view.px(at), along))
            else:
                at_px = (view.px(along), view.py(view.px(along), at))
            cv2.circle(image, p(*at_px), 9, (0, 200, 0), -1)
    for px, _metres, _what in getattr(module, "X", []):
        cv2.line(image, p(px, y0), p(px, y1), (200, 0, 200), 1)
    if scale != 1.0:
        image = cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA)
    cv2.imwrite(out, image)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("plates", nargs="*")
    lk = sub.add_parser("look")
    lk.add_argument("plate")
    for edge in ("x0", "y0", "x1", "y1"):
        lk.add_argument(edge, type=int)
    lk.add_argument("out")
    lk.add_argument("--scale", type=float, default=1.0)
    lk.add_argument("--grid", type=int, default=100)
    d = sub.add_parser("draft")
    d.add_argument("deck")
    d.add_argument("--run", type=int, default=25)
    d.add_argument("--least", type=int, default=40)
    r = sub.add_parser("rooms")
    r.add_argument("deck")
    r.add_argument("--out")
    r.add_argument("--least", type=int, default=1500)
    r.add_argument("--crop", type=int, nargs=4)
    o = sub.add_parser("overlay")
    o.add_argument("deck")
    o.add_argument("out")
    o.add_argument("--scale", type=float, default=1.0)
    o.add_argument("--crop", type=int, nargs=4)
    args = parser.parse_args()
    if args.command == "fetch":
        for plate in args.plates or sorted(plates()):
            print(fetch(plate))
    elif args.command == "look":
        look(args.plate, args.x0, args.y0, args.x1, args.y1, args.out, args.scale, args.grid)
    elif args.command == "draft":
        draft(args.deck, args.run, args.least)
    elif args.command == "rooms":
        regions(args.deck, args.out, least=args.least, crop_box=args.crop)
    else:
        overlay(args.deck, args.out, args.scale, args.crop)


if __name__ == "__main__":
    main()
