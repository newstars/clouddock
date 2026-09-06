#!/usr/bin/env python3
import math
import os
import struct
import zlib


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RESOURCES = os.path.join(ROOT, "Resources")
PNG_PATH = os.path.join(RESOURCES, "CloudDockIcon.png")


def write_png(path, width, height, pixels):
    raw_rows = []
    stride = width * 4
    for y in range(height):
        raw_rows.append(b"\x00" + pixels[y * stride:(y + 1) * stride])
    raw = b"".join(raw_rows)

    def chunk(kind, data):
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9))
    data += chunk(b"IEND", b"")

    with open(path, "wb") as file:
        file.write(data)


def mix(a, b, t):
    return int(a + (b - a) * t)


def rounded_rect_alpha(x, y, left, top, right, bottom, radius):
    inside_x = left <= x <= right
    inside_y = top <= y <= bottom
    if not (inside_x and inside_y):
        return 0

    cx = min(max(x, left + radius), right - radius)
    cy = min(max(y, top + radius), bottom - radius)
    distance = math.hypot(x - cx, y - cy)
    return 255 if distance <= radius else 0


def draw_icon(size=1024):
    pixels = bytearray(size * size * 4)

    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            alpha = rounded_rect_alpha(x, y, 64, 64, 960, 960, 210)
            if alpha == 0:
                continue

            tx = x / (size - 1)
            ty = y / (size - 1)
            glow = max(0, 1 - math.hypot(tx - 0.34, ty - 0.22) * 1.6)
            r = mix(21, 28, ty)
            g = mix(91, 184, glow)
            b = mix(196, 255, glow)

            pixels[i:i + 4] = bytes((r, g, b, alpha))

    # Dock base
    for y in range(610, 760):
        for x in range(205, 820):
            i = (y * size + x) * 4
            alpha = rounded_rect_alpha(x, y, 205, 610, 820, 760, 54)
            if alpha:
                pixels[i:i + 4] = bytes((244, 249, 255, 238))

    # Widget tiles
    tiles = [
        (255, 642, 345, 728, (37, 99, 235)),
        (374, 642, 464, 728, (14, 165, 233)),
        (493, 642, 583, 728, (34, 197, 94)),
        (612, 642, 702, 728, (250, 204, 21)),
    ]
    for left, top, right, bottom, color in tiles:
        for y in range(top, bottom):
            for x in range(left, right):
                i = (y * size + x) * 4
                alpha = rounded_rect_alpha(x, y, left, top, right, bottom, 24)
                if alpha:
                    pixels[i:i + 4] = bytes((*color, 255))

    # Floating cloud arc
    circles = [
        (360, 405, 86),
        (455, 355, 122),
        (590, 405, 96),
    ]
    for cx, cy, radius in circles:
        for y in range(cy - radius, cy + radius + 1):
            for x in range(cx - radius, cx + radius + 1):
                if 0 <= x < size and 0 <= y < size and math.hypot(x - cx, y - cy) <= radius:
                    i = (y * size + x) * 4
                    pixels[i:i + 4] = bytes((246, 251, 255, 238))

    for y in range(400, 500):
        for x in range(300, 660):
            i = (y * size + x) * 4
            pixels[i:i + 4] = bytes((246, 251, 255, 238))

    # Connector line
    for y in range(495, 610):
        for x in range(502, 522):
            i = (y * size + x) * 4
            pixels[i:i + 4] = bytes((226, 242, 255, 220))

    return pixels


def main():
    os.makedirs(RESOURCES, exist_ok=True)
    write_png(PNG_PATH, 1024, 1024, draw_icon())
    print(PNG_PATH)


if __name__ == "__main__":
    main()
