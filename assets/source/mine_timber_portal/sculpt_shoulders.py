"""Bake the connected load-bearing shoulder relief, mineral color + roughness.
Run where NumPy and Pillow are installed. No third-party artwork used.
The paired 512×1024 shoulders share one 1024² UV sheet; horizontal and
vertical boundaries come from a common authored masonry graph.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

W, H = 512, 1024
METRES_X, METRES_Y = 3.04, 5.27
DEST = Path(__file__).resolve().parents[2] / "models" / "mine_timber_portal"

COURSES = [
    [0, .55, 1.25, 1.94, 2.66, 3.42, 4.11, 4.77, METRES_Y],
    [0, .59, 1.36, 1.98, 2.77, 3.39, 4.05, 4.71, METRES_Y],
]
# Seams measured from the timber outward. The dressing next to the timber
# is larger and straighter. The outer wing receives smaller slate/limestone
# splits and narrow chocks; row junctions do not line up in long cracks.
JOINTS = [
    [[1.67], [1.19, 2.16], [1.46, 2.63], [1.06, 1.88, 2.52],
     [1.48, 2.46], [1.22, 2.11, 2.76], [1.59, 2.48], [1.14, 2.42]],
    [[1.48], [1.32, 2.12], [1.52, 2.62], [1.18, 1.94, 2.48],
     [1.50, 2.51], [1.18, 2.18, 2.71], [1.63, 2.37], [1.13, 2.27]],
]
LOTS = np.array([[.492, .471, .427], [.535, .509, .451],
                 [.484, .433, .368], [.429, .457, .455]])
Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
X *= METRES_X / (W - 1)
Y = METRES_Y - Y * METRES_Y / (H - 1)


def smooth(low: float, high: float, value: np.ndarray) -> np.ndarray:
    f = np.clip((value - low) / (high - low), 0, 1)
    return f * f * (3 - 2 * f)


def field(rng: np.random.Generator, w: int, h: int) -> np.ndarray:
    pixels = rng.integers(0, 256, (h, w), dtype=np.uint8)
    img = Image.fromarray(pixels).resize((W, H), Image.Resampling.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255


def bed_height(side: int, row: int, x: np.ndarray) -> np.ndarray:
    y = COURSES[side][row]
    if row in (0, len(COURSES[side]) - 1):
        return y + x * 0
    control_x = [0, .6, 1.16, 1.62, 1.89, 2.26, 2.73, 3.04]
    # Shared planes join to exactly the same mortar bed from both stones.
    dx = np.array([0, -.01, .011, -.084, .068, -.021, .065, -.043])
    dx = dx * (-1 if row % 2 else 1) + np.array([0, .01, .015, .015, -.015, .008, 0, -.018]) * side
    return y + np.interp(x, control_x, dx)


def head_joint(side: int, row: int, j: int, base: float, f: np.ndarray) -> np.ndarray:
    if j in (0, len(JOINTS[side][row]) + 1):
        return base + f * 0
    amp = (.044 if j == 1 else .134) * (-1 if (j + row + side) % 2 else 1)
    return base + np.interp(np.clip(f, 0, 1), [0, .23, .59, 1], [-amp * .52, amp * .43, amp, -amp * .62])


def shoulders(side: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(200411 + 199 * side)
    mineral = field(rng, 12, 17)
    cloud = field(rng, 31, 41)
    shale = field(rng, 9, 85)
    grit = field(rng, 197, 340)
    porous = field(rng, 121, 241)
    coarse = field(rng, 7, 13)
    edge_chip = field(rng, 92, 133)
    calcium = field(rng, 66, 119)
    wet = (1 - smooth(.1, 1.56, Y)) * smooth(.16, .83, coarse * .73 + cloud * .27)
    sand = .90 + (.14 * grit + .12 * porous + .09 * cloud) - .092
    # Mortar has its own surface. It fills depth behind all the shared
    # joints; no dry gaps or fake outlines on a separately rendered board.
    base = np.array([.371, .342, .296], dtype=np.float32)
    color = np.broadcast_to(base, (H, W, 3)).copy() * sand[..., None]
    h = (.033 + .014 * porous + .009 * cloud).copy()
    rough = (.88 + grit * .065).copy()
    salt_vein = smooth(.020, .053, np.abs(np.sin(5.02 * Y + .86 * X + mineral * 1.8)))
    for row in range(len(COURSES[side]) - 1):
        bottom = bed_height(side, row, X)
        top = bed_height(side, row + 1, X)
        f = (Y - bottom) / (top - bottom)
        cuts = [0, *JOINTS[side][row], METRES_X]
        for j in range(len(cuts) - 1):
            left = head_joint(side, row, j, cuts[j], f)
            right = head_joint(side, row, j + 1, cuts[j + 1], f)
            distance = np.minimum.reduce((Y - bottom, top - Y, X - left, right - X))
            # Cut local, unequal facet chips into the shared relief, leaving
            # the mortar/contact foundation continuous underneath each edge.
            p = (X - left) / (right - left)
            pick_side, pick_top = (j + row) % 2, (j * 2 + row + side) % 3
            pick_x = .18 if pick_side == 0 else .81
            pick_y = .93 if pick_top else .075
            macroscopic_spall = np.maximum(0, 1 - np.abs(p - pick_x) * (6.2 + rng.uniform(0, 3)))
            macroscopic_spall *= np.maximum(0, 1 - np.abs(f - pick_y) * (4.1 + rng.uniform(0, 3)))
            cutout = macroscopic_spall * (.030 if j == 0 else .056)
            bite = .009 + edge_chip * (.008 if j == 0 else .018) + cutout
            core = smooth(0, .061 if j == 0 else .092, distance - bite)
            stone = smooth(-.003, .021, distance - bite)
            if j in (0, len(cuts) - 2):
                stone = np.maximum(stone, smooth(-.018, .025, distance - bite)) * (distance > -0.04)
            active = (distance >= -.044)
            if not np.any(active):
                continue
            lot = (row + j * 3 + side) % len(LOTS) if ((row + j + side) % 4 != 1) else 0
            tone = LOTS[lot] * rng.uniform(.91, 1.10)
            vein = (1 - salt_vein) * smooth(.44, .80, calcium) * (.26 if lot == 1 else .10)
            lithic = (.82 + mineral * .22 + cloud * .14 + shale * .12 + grit * .065)
            pits = smooth(.70, .93, porous) * smooth(.35, .73, cloud)
            lithic -= pits * .113
            lithic *= .81 + core * .19
            rock = tone[None, None, :] * lithic[..., None] + vein[..., None] * np.array([.16, .145, .10])
            browning = wet * (.17 + .17 * coarse)
            rock *= 1 - browning[..., None] * np.array([.32, .21, .39])
            rock += (wet * calcium * .027)[..., None] * np.array([.61, .72, .43])
            color[active] = (color * (1 - stone[..., None]) + rock * stone[..., None])[active]
            relief = .081 + (.044 if row == 0 else .016) + .024 * (j == 0) + rng.uniform(-.017, .022)
            fracture = .033 * (p - .40) * (1 if (j + row) % 2 else -1) + .018 * (f - .53)
            wear = (.031 + .023 * cloud) * macroscopic_spall
            stone_h = .035 + core * (relief + fracture + .022 * (shale - .5) + .017 * (mineral - .5) - wear)
            stone_h += stone * (.007 * grit - .011 * pits + vein * .012)
            h[active] = np.maximum(h, stone_h)[active]
            rough[active] = (rough * (1 - stone) + (.78 + porous * .16 - vein * .13) * stone)[active]
    # Weather from the floor up, including the actual mortar bed.
    color *= (1 - wet * .19)[..., None]
    return color, rough, np.clip(h, 0, .28)


def image_bytes(data: np.ndarray) -> Image.Image:
    return Image.fromarray(np.uint8(np.rint(np.clip(data, 0, 1) * 255)))


def main() -> None:
    color_pages, normals, depths = [], [], []
    for side in range(2):
        color, rough, height = shoulders(side)
        color_pages.append(np.dstack((color, rough)))
        depths.append(height / .28)
        # Remove broad support-slab curvature, but retain the same contact
        # bevels and individual mineral laminae as the sculpt.
        blurred = np.asarray(image_bytes(height / .28).filter(ImageFilter.GaussianBlur(9)), dtype=np.float32)
        residual = height - (blurred / 255 * .28) * .48
        dy, dx = np.gradient(residual, METRES_Y / (H - 1), METRES_X / (W - 1))
        vectors = np.dstack((-dx * .63, dy * .63, np.ones_like(dx)))
        vectors /= np.linalg.norm(vectors, axis=2, keepdims=True)
        normals.append((vectors + 1) * .5)
    for name, pages in [("shoulder_diffuse_roughness", color_pages), ("shoulder_tangent_normal", normals), ("shoulder_relief", depths)]:
        texture = image_bytes(np.concatenate(pages, axis=1))
        if name == "shoulder_relief":
            texture = texture.resize((256, 256), Image.Resampling.LANCZOS)
        texture.save(DEST / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
