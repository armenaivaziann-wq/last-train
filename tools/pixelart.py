"""Общие инструменты пиксель-арта для генераторов LAST TRAIN: холст, примитивы, обводка,
градиенты, шум, запись PNG без внешних библиотек (чистый Python 3)."""
import math
import os
import random
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")

OUTLINE = "#1a1430"


def hexc(c, a=255):
    if isinstance(c, tuple):
        return c if len(c) == 4 else (c[0], c[1], c[2], a)
    c = c.lstrip("#")
    if len(c) == 8:
        return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), int(c[6:8], 16))
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


def mix(a, b, t):
    a, b = hexc(a), hexc(b)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def shade(c, k):
    """k < 0 — темнее (к сине-фиолетовому), k > 0 — светлее (к тёплому)."""
    c = hexc(c)
    if k < 0:
        return mix(c, (24, 16, 48, c[3]), min(1.0, -k))
    return mix(c, (255, 244, 214, c[3]), min(1.0, k))


def alpha(c, a):
    c = hexc(c)
    return (c[0], c[1], c[2], int(a))


class Canvas:
    def __init__(self, w, h, fill=None):
        self.w, self.h = w, h
        base = hexc(fill) if fill else (0, 0, 0, 0)
        self.px = [[base] * w for _ in range(h)]

    # --- базовые операции ---
    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = hexc(c)

    def blend(self, x, y, c):
        """Альфа-смешивание поверх текущего пикселя."""
        x, y = int(x), int(y)
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        c = hexc(c)
        if c[3] == 0:
            return
        d = self.px[y][x]
        a = c[3] / 255.0
        if c[3] == 255 or d[3] == 0:
            self.px[y][x] = c
            return
        out_a = a + d[3] / 255.0 * (1 - a)
        rgb = [int(round((c[i] * a + d[i] * (d[3] / 255.0) * (1 - a)) / max(out_a, 1e-6))) for i in range(3)]
        self.px[y][x] = (rgb[0], rgb[1], rgb[2], int(round(out_a * 255)))

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[int(y)][int(x)]
        return (0, 0, 0, 0)

    def opaque(self, x, y):
        return self.get(x, y)[3] > 0

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.set(xx, yy, c)

    def brect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.blend(xx, yy, c)

    def frame(self, x, y, w, h, c):
        self.rect(x, y, w, 1, c)
        self.rect(x, y + h - 1, w, 1, c)
        self.rect(x, y, 1, h, c)
        self.rect(x + w - 1, y, 1, h, c)

    def hline(self, x0, x1, y, c):
        for x in range(int(x0), int(x1) + 1):
            self.set(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(int(y0), int(y1) + 1):
            self.set(x, y, c)

    def fill(self, pred, c, blend=False):
        for yy in range(self.h):
            for xx in range(self.w):
                if pred(xx + 0.5, yy + 0.5):
                    (self.blend if blend else self.set)(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, c, blend=False):
        x0, x1 = int(cx - rx - 1), int(cx + rx + 1)
        y0, y1 = int(cy - ry - 1), int(cy + ry + 1)
        for yy in range(max(0, y0), min(self.h, y1 + 1)):
            for xx in range(max(0, x0), min(self.w, x1 + 1)):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0:
                    (self.blend if blend else self.set)(xx, yy, c)

    def ring(self, cx, cy, r_out, r_in, c):
        for yy in range(int(cy - r_out - 1), int(cy + r_out + 2)):
            for xx in range(int(cx - r_out - 1), int(cx + r_out + 2)):
                d = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
                if r_in <= d <= r_out:
                    self.set(xx, yy, c)

    def rrect(self, x, y, w, h, r, c, blend=False):
        """Скруглённый прямоугольник."""
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                dx = max(x + r - (xx + 0.5), 0, (xx + 0.5) - (x + w - r))
                dy = max(y + r - (yy + 0.5), 0, (yy + 0.5) - (y + h - r))
                if dx * dx + dy * dy <= r * r:
                    (self.blend if blend else self.set)(xx, yy, c)

    def poly(self, pts, c, blend=False):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]

        def inside(x, y):
            n, ok = len(pts), False
            j = n - 1
            for i in range(n):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                    ok = not ok
                j = i
            return ok
        for yy in range(max(0, int(min(ys)) - 1), min(self.h, int(max(ys)) + 2)):
            for xx in range(max(0, int(min(xs)) - 1), min(self.w, int(max(xs)) + 2)):
                if inside(xx + 0.5, yy + 0.5):
                    (self.blend if blend else self.set)(xx, yy, c)

    def line(self, x0, y0, x1, y1, c):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(steps + 1):
            t = i / max(steps, 1)
            self.set(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def vgrad(self, x, y, w, h, c0, c1, dither=True):
        """Вертикальный градиент с упорядоченным дизерингом (пиксельный стиль)."""
        bayer = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
        steps = 6
        for yy in range(int(y), int(y + h)):
            t = (yy - y) / max(h - 1, 1)
            for xx in range(int(x), int(x + w)):
                tt = t
                if dither:
                    q = t * steps
                    base = math.floor(q)
                    frac = q - base
                    tt = (base + (1 if frac * 16 > bayer[yy % 4][xx % 4] else 0)) / steps
                self.set(xx, yy, mix(c0, c1, min(1.0, tt)))

    def outline(self, c=OUTLINE, diag=False):
        """Внешняя обводка в 1px вокруг непрозрачных пикселей."""
        col = hexc(c)
        add = []
        nb = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if diag:
            nb = nb + ((1, 1), (-1, -1), (1, -1), (-1, 1))
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x][3] != 0:
                    continue
                for dx, dy in nb:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny][nx][3] > 128:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = col
        return self

    def blit(self, other, ox, oy, flip=False):
        for y in range(other.h):
            for x in range(other.w):
                p = other.px[y][other.w - 1 - x if flip else x]
                if p[3]:
                    if p[3] == 255:
                        self.set(ox + x, oy + y, p)
                    else:
                        self.blend(ox + x, oy + y, p)

    def flipped(self):
        c = Canvas(self.w, self.h)
        for y in range(self.h):
            c.px[y] = list(reversed(self.px[y]))
        return c

    def copy(self):
        c = Canvas(self.w, self.h)
        c.px = [list(r) for r in self.px]
        return c

    def sub(self, x, y, w, h):
        c = Canvas(w, h)
        for yy in range(h):
            for xx in range(w):
                c.px[yy][xx] = self.get(x + xx, y + yy)
        return c

    def recolor(self, mapping):
        m = {hexc(k)[:3]: hexc(v) for k, v in mapping.items()}
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y][x]
                if p[3] and p[:3] in m:
                    n = m[p[:3]]
                    self.px[y][x] = (n[0], n[1], n[2], p[3])
        return self

    def tint(self, c, k):
        for y in range(self.h):
            for x in range(self.w):
                p = self.px[y][x]
                if p[3]:
                    q = mix(p, c, k)
                    self.px[y][x] = (q[0], q[1], q[2], p[3])
        return self

    def scaled(self, s):
        c = Canvas(self.w * s, self.h * s)
        for y in range(c.h):
            for x in range(c.w):
                c.px[y][x] = self.px[y // s][x // s]
        return c

    # --- запись ---
    def save(self, rel, root=SPRITES):
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_png(path, self.w, self.h, self.px)
        print("  ", os.path.relpath(path, ROOT), f"{self.w}x{self.h}")
        return path


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + b"".join(struct.pack("4B", *p) for p in row) for row in rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def read_png(path):
    """Читает RGBA PNG без интерлейса (нужен для превью-коллажей)."""
    with open(path, "rb") as f:
        data = f.read()
    pos = 8
    w = h = 0
    idat = b""
    color_type = 6
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            w, h, _, color_type = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat += body
        pos += 12 + length
    bpp = 4 if color_type == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * bpp
    prev = bytearray(stride)
    c = Canvas(w, h)
    i = 0
    for y in range(h):
        ft = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            cc = prev[x - bpp] if x >= bpp else 0
            if ft == 1:
                line[x] = (line[x] + a) & 255
            elif ft == 2:
                line[x] = (line[x] + b) & 255
            elif ft == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif ft == 4:
                p = a + b - cc
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - cc)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else cc)
                line[x] = (line[x] + pr) & 255
        for x in range(w):
            px = line[x * bpp:(x + 1) * bpp]
            c.px[y][x] = (px[0], px[1], px[2], px[3] if bpp == 4 else 255)
        prev = line
    return c


def strip(frames):
    """Склеивает кадры по горизонтали в спрайт-лист."""
    w, h = frames[0].w, frames[0].h
    sheet = Canvas(w * len(frames), h)
    for i, f in enumerate(frames):
        sheet.blit(f, i * w, 0)
    return sheet


def grid(rows):
    """Склеивает список рядов кадров в сетку (ряд = анимация)."""
    w, h = rows[0][0].w, rows[0][0].h
    cols = max(len(r) for r in rows)
    sheet = Canvas(w * cols, h * len(rows))
    for ry, row in enumerate(rows):
        for cx, f in enumerate(row):
            sheet.blit(f, cx * w, ry * h)
    return sheet


def noise_rng(seed):
    return random.Random(seed)


def soft_glow(size, color, power=2.0, max_a=255):
    """Мягкое круглое пятно света (для аддитивных спрайтов ламп и окон)."""
    c = Canvas(size, size)
    r = size / 2
    col = hexc(color)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - r, y + 0.5 - r) / r
            if d < 1:
                a = (1 - d) ** power
                c.px[y][x] = (col[0], col[1], col[2], int(max_a * a))
    return c
