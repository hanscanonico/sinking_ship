"""The bonuses' own sounds (#313), synthesised here: nothing recorded goes into them.

Run from the repo's root:

    python3 tools/gen_bonus_sounds.py

It writes, as every sound of assets/audio/ is kept (assets/LICENSES.md) — mono 44.1 kHz
16-bit WAV, peak-normalised to -1 dBFS — and the same bytes on every run:

    assets/audio/bonus/hum.wav          the hum of a bonus aboard (CuePlanner.hums): a soft
                                        chord whose two lowest voices, half a hertz apart,
                                        beat slowly; a seamless loop — every voice whole
                                        cycles of its length — marked as one in a `smpl`
                                        chunk, which Godot's import reads as it is
    assets/audio/bonus/double_life.wav  a Double life spent: four notes rising, each struck
                                        as a small bell is, the last ringing longest
"""
import math
import os
import struct

RATE = 44100
PEAK = 10.0 ** (-1.0 / 20.0)
OUT = "assets/audio/bonus"

# The hum: LOOP seconds long, each voice its frequency in hertz and its share of the
# loudest; every frequency a whole number of cycles in LOOP, so the loop has no seam.
LOOP = 4.0
HUM_VOICES = [(220.0, 1.0), (220.5, 0.7), (330.0, 0.35), (440.25, 0.22), (660.0, 0.08)]

# Double life spent: the notes, each its frequency and when it is struck in seconds; the
# bell's partials, each its share of the note's frequency, its loudness and the seconds
# it takes to die to 1/e; how long a strike takes to sound fully, how much longer the
# last note rings, how long the whole is and the fade closing it.
NOTES = [(440.0, 0.0), (554.37, 0.09), (659.26, 0.18), (880.0, 0.27)]
PARTIALS = [(1.0, 1.0, 0.6), (2.0, 0.35, 0.3), (3.0, 0.12, 0.2), (4.16, 0.06, 0.12)]
ATTACK = 0.004
LAST_RINGS = 1.6
LENGTH = 1.6
FADE = 0.06


def hum():
    """The hum's samples, LOOP seconds of them and one more, the first again: the loop's
    last sample, where its end turns back to its start whether a player takes that end
    as played (the RIFF spec) or not (Godot)."""
    count = int(LOOP * RATE) + 1
    return [
        sum(share * math.sin(2.0 * math.pi * freq * i / RATE) for freq, share in HUM_VOICES)
        for i in range(count)
    ]


def double_life():
    """Double life spent's samples."""
    count = int(LENGTH * RATE)
    samples = [0.0] * count
    for index, (freq, at) in enumerate(NOTES):
        rings = LAST_RINGS if index == len(NOTES) - 1 else 1.0
        start = int(at * RATE)
        for i in range(start, count):
            t = (i - start) / RATE
            swell = min(t / ATTACK, 1.0)
            samples[i] += swell * sum(
                loud * math.exp(-t / (decay * rings)) * math.sin(2.0 * math.pi * freq * ratio * t)
                for ratio, loud, decay in PARTIALS
            )
    fade = int(FADE * RATE)
    for i in range(count - fade, count):
        samples[i] *= (count - 1 - i) / (fade - 1)
    return samples


def pcm(samples):
    """[samples] peak-normalised to PEAK, as 16-bit little-endian PCM."""
    top = max(abs(s) for s in samples)
    return b"".join(struct.pack("<h", round(s / top * PEAK * 32767)) for s in samples)


def write(name, samples, loop=False):
    """Writes [samples] to OUT/name as a WAV; [loop] marks the whole of it as a loop."""
    data = pcm(samples)
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    chunks = [b"fmt ", fmt, b"data", data]
    if loop:
        # smpl: maker, product, sample period (ns), MIDI unity note and pitch fraction,
        # SMPTE format and offset, one loop, no sampler data; then the loop: its cue id,
        # forward, from the first sample to the last, played on and on.
        period = round(1e9 / RATE)
        smpl = struct.pack("<9I", 0, 0, period, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += [b"smpl", smpl]
    body = b"WAVE"
    for at in range(0, len(chunks), 2):
        body += chunks[at] + struct.pack("<I", len(chunks[at + 1])) + chunks[at + 1]
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)


if __name__ == "__main__":
    write("hum.wav", hum(), loop=True)
    write("double_life.wav", double_life())
