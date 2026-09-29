"""Synthesises MoveWise's board sounds into assets/sounds/*.wav.

A wooden piece set down on a wooden board, by modal synthesis: a short,
felt-softened contact burst rings two sets of resonators, the piece's own
(bright, short) and the board's (low, a little longer: the "thud" that makes
it sound physical). A separate glide is the felt base sliding over the board
while the piece travels. Each sound comes in a few slightly different takes,
picked at random in the app, so repeated moves don't sound mechanical.

Made here rather than taken from a sound pack, so the project owns them
outright. Standard library only:

    python3 tool/make_sounds.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44_100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
TAKES = 3

# Resonances as (frequency Hz, decay s, gain). Boxwood pieces ring high and
# briefly, with inharmonic overtones; the board answers low.
PIECE = [(1150, 0.014, 1.0), (1790, 0.010, 0.6), (2640, 0.007, 0.35), (3900, 0.004, 0.2)]
BOARD = [(150, 0.035, 0.7), (320, 0.024, 0.5), (540, 0.016, 0.3)]
# Two pieces clacking together, for captures: brighter and shorter.
CLACK = [(2300, 0.006, 1.0), (3400, 0.004, 0.6), (5100, 0.003, 0.3)]


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def burst(rng, seconds):
    """A contact: a smooth pulse, shorter for a harder hit (a longer one is
    softer, like felt), with a little noise so each take differs."""
    n = max(2, int(RATE * seconds))
    return [
        (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1))) * (1 + 0.3 * rng.uniform(-1, 1))
        for i in range(n)
    ]


def ring(excitation, modes, length, rng, detune=0.04):
    """Rings two-pole resonators with [excitation]; each take detunes a bit."""
    out = silence(length)
    for freq, decay, gain in modes:
        f = freq * (1 + rng.uniform(-detune, detune))
        d = decay * (1 + rng.uniform(-0.1, 0.1))
        g = gain * (1 + rng.uniform(-0.1, 0.1))
        r = math.exp(-1 / (d * RATE))
        c1, c2 = 2 * r * math.cos(2 * math.pi * f / RATE), -r * r
        # Scaled by the resonator's peak gain, so [gain] alone sets loudness.
        norm = (1 - r) * 2 * math.sin(2 * math.pi * f / RATE)
        y1 = y2 = 0.0
        for i in range(len(out)):
            x = excitation[i] if i < len(excitation) else 0.0
            y = norm * x + c1 * y1 + c2 * y2
            y2, y1 = y1, y
            out[i] += g * y
    return out


def knock(rng, *, force=1.0, contact=0.0008, piece=PIECE, board=BOARD, board_gain=0.6, length=0.14):
    """One piece set down: [force] scales how hard, [contact] how long the
    felt base takes to meet the board (shorter is harder and brighter)."""
    pulse = [force * s for s in burst(rng, contact)]
    body = ring(pulse, piece, length, rng)
    thud = ring(pulse, board, length, rng)
    return [b + board_gain * t for b, t in zip(body, thud)]


def glide(rng, length=0.18):
    """Felt sliding over wood: soft band-limited noise that swells and fades."""
    out = silence(length)
    # A band-pass around 1.6kHz (two one-pole sections), plus a little rumble.
    a_hi = math.exp(-2 * math.pi * 900 / RATE)
    a_lo = math.exp(-2 * math.pi * 2600 / RATE)
    a_rumble = math.exp(-2 * math.pi * 250 / RATE)
    high = low = previous = rumble = 0.0
    wobble = rng.uniform(0, math.tau)
    for i in range(len(out)):
        t = i / RATE
        x = rng.uniform(-1, 1)
        low = (1 - a_lo) * x + a_lo * low
        high = a_hi * (high + low - previous)
        previous = low
        rumble = (1 - a_rumble) * x + a_rumble * rumble
        # Rise over 40ms, fall away by the end; a slow wobble for texture.
        env = min(1, t / 0.04) * max(0, 1 - t / length) ** 1.5
        env *= 1 + 0.25 * math.sin(2 * math.pi * 22 * t + wobble)
        out[i] = env * (high + 1.5 * rumble)
    return out


def ping(rng, length=0.26):
    """A soft, bell-like tone for check: noticeable without alarm."""
    out = silence(length)
    f = 1320 * (1 + rng.uniform(-0.01, 0.01))
    for i in range(len(out)):
        t = i / RATE
        out[i] = (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * 2 * f * t)) * (
            math.exp(-t / 0.07) * min(1, t / 0.002)
        )
    return out


def at(samples, seconds):
    return silence(seconds) + samples


def mix(*layers):
    length = max(len(layer) for layer in layers)
    return [sum(layer[i] for layer in layers if i < len(layer)) for i in range(length)]


def scaled(samples, gain):
    return [gain * s for s in samples]


def write(name, samples, peak):
    # Normalise, then fade the last 5ms so nothing clicks at the cut.
    top = max(abs(s) for s in samples) or 1
    fade = int(RATE * 0.005)
    out = []
    for i, s in enumerate(samples):
        level = s / top * peak
        if i >= len(samples) - fade:
            level *= (len(samples) - i) / fade
        out.append(int(max(-1, min(1, level)) * 32767))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(struct.pack(f"<{len(out)}h", *out))
    print(f"{name}.wav  {len(out) / RATE * 1000:.0f}ms")


# Levels sit well below full scale: these play on every move, under whatever
# else the phone is doing. The glide is quieter still, a hint of travel.
for take in range(1, TAKES + 1):
    rng = random.Random(take)

    write(f"glide_{take}", glide(rng), peak=0.07)

    # A piece set down.
    write(f"move_{take}", knock(rng), peak=0.32)

    # Set down harder, with the clack of the pieces touching just before.
    write(
        f"capture_{take}",
        mix(
            scaled(knock(rng, contact=0.0004, piece=CLACK, board_gain=0.2, length=0.06), 0.7),
            at(knock(rng, force=1.3, contact=0.0006, board_gain=0.8), 0.012),
        ),
        peak=0.4,
    )

    # King, then rook a moment later: two lighter knocks, the second softer.
    write(
        f"castle_{take}",
        mix(knock(rng, force=0.9), at(scaled(knock(rng, force=0.8), 0.8), 0.075)),
        peak=0.3,
    )

    # A move with the soft ping on top.
    write(f"check_{take}", mix(knock(rng), scaled(ping(rng), 0.35)), peak=0.38)

for old in ("move", "capture", "castle", "check"):
    (OUT / f"{old}.wav").unlink(missing_ok=True)
