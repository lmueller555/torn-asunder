"""Rebuild the portal's original, seamless material maps; NumPy + Pillow.

Render maps are baked offline for mip-filtered sampling, not evaluated as
pixel-derivative bump noise at run time:
  *_surface.png: R value mask; G roughness; B exposed mineral/polish.
  *_normal.png: linear OpenGL tangent normals (+Y), generated from height.
"""
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 256
DEST = Path(__file__).resolve().parents[2] / "models" / "mine_timber_portal"
RNG = np.random.default_rng(73831)


def field(w: int, h: int) -> np.ndarray:
    """Periodic bicubic lattice in the center tile; no unwrapped kernel edges."""
    tile = RNG.integers(0, 256, (h, w), dtype=np.uint8)
    extended = Image.fromarray(np.tile(tile, (3, 3))).resize((SIZE * 3, SIZE * 3), Image.Resampling.BICUBIC)
    return np.asarray(extended, dtype=float)[SIZE:SIZE * 2, SIZE:SIZE * 2] / 255


def ease(low: float, high: float, data: np.ndarray) -> np.ndarray:
    x = np.clip((data - low) / (high - low), 0, 1)
    return x * x * (3.0 - 2.0 * x)


def save(name: str, channels: tuple | np.ndarray) -> None:
    data = np.dstack(channels) if isinstance(channels, tuple) else channels
    output = Image.fromarray(np.uint8(np.rint(np.clip(data, 0, 1) * 255)))
    # Hammered fittings occupy less screen area than the eight stone courses.
    if name.startswith("iron"):
        output = output.resize((SIZE // 2, SIZE // 2), Image.Resampling.LANCZOS)
    output.save(DEST / f"{name}.png", optimize=True)


def normal(name: str, height: np.ndarray, strength: float) -> None:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    vectors = np.stack((-dx, dy, np.ones_like(height)), axis=2)
    vectors /= np.linalg.norm(vectors, axis=2, keepdims=True)
    save(f"{name}_normal", (vectors + 1.0) * 0.5)


def stone() -> None:
    matrix = field(9, 12)
    matrix_fine = field(29, 35)
    tabular = field(12, 68)
    quarry = field(5, 13)
    grains = field(87, 84)
    chipped = ease(0.62, 0.89, 0.7 * matrix + tabular * 0.30)
    inclusions = ease(0.56, 0.84, matrix_fine * 0.75 + grains * 0.25)
    pores = ease(0.74, 0.94, (grains * 0.82 + matrix_fine * 0.18))
    # Sparse hand-placed quarry pick marks in the tile, not another noise
    # octave. Keep them shallow and stagger the lengths/angles.
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE
    strikes = np.zeros_like(matrix)
    for u, v, angle, width, length in [
        (0.25, 0.37, -0.42, 0.009, 0.030), (0.29, 0.34, -0.56, 0.006, 0.025),
        (0.73, 0.68, 0.20, 0.007, 0.044), (0.76, 0.64, 0.27, 0.008, 0.033),
        (0.84, 0.18, -0.28, 0.010, 0.022),
    ]:
        dx, dy = (x - u + 0.5) % 1.0 - 0.5, (y - v + 0.5) % 1.0 - 0.5
        cross = dx * np.cos(angle) + dy * np.sin(angle)
        along = dy * np.cos(angle) - dx * np.sin(angle)
        strikes = np.maximum(strikes, np.exp(-(cross / width) ** 2 - (along / length) ** 4))
    height = matrix * 0.41 + matrix_fine * 0.16 + quarry * 0.16 + tabular * 0.15 - pores * 0.05 - chipped * 0.083
    height -= strikes * 0.14
    value = 0.67 + quarry * 0.15 + tabular * 0.085 - chipped * 0.11 - pores * 0.08 - strikes * 0.10
    save("stone_surface", (value, 0.84 + grains * 0.08 - inclusions * 0.07, inclusions))
    normal("stone", height, 1.2)


def iron() -> None:
    hammer = field(23, 27)
    oxide = ease(0.46, 0.78, field(7, 13) * 0.66 + hammer * 0.34)
    filing = (field(6, 90) * 0.53 + field(74, 91) * 0.47)
    pits = ease(0.73, 0.91, field(97, 92))
    polish = ease(0.49, 0.81, filing + hammer * 0.14) * (1.0 - oxide * 0.69)
    height = hammer * 0.32 + filing * 0.10 - pits * 0.047
    save("iron_surface", (0.67 + polish * 0.25 - pits * 0.075, 0.67 + oxide * 0.22 - polish * 0.25, oxide))
    normal("iron", height, 0.87)


if __name__ == "__main__":
    stone()
    iron()
