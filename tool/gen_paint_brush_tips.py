"""Generate the tip images of the painting brushes (original, procedural).

Writes 128x128 alpha masks to assets/brushes/:

- flat_bristle_tip.png: a flat bristle brush seen from its flat side. The
  image's x axis runs along the stroke and its y axis across it; the
  bristle ends at the front and back are uneven, so a stroke starts and
  ends in a fringe.
- filbert_bristle_tip.png: a filbert (oval) bristle brush with an uneven
  rim of bristle ends.
- palette_knife_tip.png: the flat edge of a painting knife: a thin blade
  with clean straight sides and slightly eased corners.

The streaks along the stroke come from the drawing engine
(lib/engine/bristle_marks.dart), not from these images.

Usage: python3 tool/gen_paint_brush_tips.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image

SIZE = 128
SUPER = 4
OUT = Path(__file__).resolve().parent.parent / "assets" / "brushes"


def smooth_noise(seed: int, count: int) -> list[float]:
    """Values in [-1, 1] at `count` knots, read with `sample` below."""
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(count + 2)]


def sample(knots: list[float], t: float) -> float:
    """Smoothly interpolated knot value at t in [0, 1]."""
    x = t * (len(knots) - 2)
    i = math.floor(x)
    i = max(0, min(i, len(knots) - 2))
    f = x - i
    f = f * f * (3 - 2 * f)
    return knots[i] + (knots[i + 1] - knots[i]) * f


def render(inside) -> Image.Image:
    """Antialiased mask of `inside(u, v)` (u, v in [-1, 1])."""
    big = SIZE * SUPER
    hits = [0] * (SIZE * SIZE)
    for by in range(big):
        v = (by + 0.5) / big * 2 - 1
        row = (by // SUPER) * SIZE
        for bx in range(big):
            u = (bx + 0.5) / big * 2 - 1
            if inside(u, v):
                hits[row + bx // SUPER] += 1
    alpha = bytes(min(255, round(h * 255 / (SUPER * SUPER))) for h in hits)
    mask = Image.frombytes("L", (SIZE, SIZE), alpha)
    white = Image.new("L", (SIZE, SIZE), 255)
    return Image.merge("LA", (white, mask))


def flat_bristle(u: float, v: float) -> bool:
    if abs(v) > 0.96:
        return False
    t = (v + 0.96) / 1.92
    front = 0.2 + 0.05 * sample(FRONT, t) + 0.03 * sample(FRONT_FINE, t)
    back = 0.2 + 0.06 * sample(BACK, t) + 0.035 * sample(BACK_FINE, t)
    # The corners of the ferrule-shaped brush are eased.
    ease = max(0.0, (abs(v) - 0.78) / 0.18)
    width_scale = math.sqrt(max(0.0, 1 - ease * ease))
    if u >= 0:
        return u <= front * width_scale
    return -u <= back * width_scale


def filbert(u: float, v: float) -> bool:
    angle = math.atan2(v, u)
    t = (angle + math.pi) / (2 * math.pi)
    rim = 1 + 0.035 * sample(RIM, t) + 0.025 * sample(RIM_FINE, t)
    a = 0.55 * rim
    b = 0.95 * rim
    return (u / a) ** 2 + (v / b) ** 2 <= 1


def palette_knife(u: float, v: float) -> bool:
    if abs(u) > 0.11 or abs(v) > 0.97:
        return False
    # Slightly eased corners.
    cu = abs(u) - 0.06
    cv = abs(v) - 0.92
    if cu > 0 and cv > 0:
        return cu * cu + cv * cv <= 0.05 * 0.05
    return True


FRONT = smooth_noise(11, 9)
FRONT_FINE = smooth_noise(12, 31)
BACK = smooth_noise(21, 9)
BACK_FINE = smooth_noise(22, 37)
RIM = smooth_noise(31, 13)
RIM_FINE = smooth_noise(32, 47)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, shape in (
        ("flat_bristle_tip.png", flat_bristle),
        ("filbert_bristle_tip.png", filbert),
        ("palette_knife_tip.png", palette_knife),
    ):
        image = render(shape)
        image.save(OUT / name, optimize=True)
        print(name, (OUT / name).stat().st_size, "bytes")


if __name__ == "__main__":
    main()
