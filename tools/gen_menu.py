#!/usr/bin/env python3
"""Арт главного меню и карты маршрутов: ночное небо с луной, горы, лес, поезд сбоку,
иллюстрированная карта долины. Всё 1:1 при выводе ×2 на 1280×720.

Запуск:  python3 tools/gen_menu.py
"""
import math

from pixelart import Canvas, OUTLINE, mix, noise_rng, shade, soft_glow
from gen_world import tileable_noise


def sky():
    W, H = 640, 360
    c = Canvas(W, H)
    c.vgrad(0, 0, W, H, "#080620", "#4a2a7a")
    rng = noise_rng(3)
    for _ in range(260):
        x, y = rng.randrange(W), rng.randrange(int(H * 0.75))
        b = rng.random()
        c.set(x, y, "#ffffff" if b > 0.85 else ("#c8c8ff" if b > 0.5 else "#7a7ab8"))
        if b > 0.97:
            for d in (1, 2):
                c.set(x + d, y, "#9a9ad8")
                c.set(x - d, y, "#9a9ad8")
                c.set(x, y + d, "#9a9ad8")
                c.set(x, y - d, "#9a9ad8")
    # луна
    g = soft_glow(150, "#b8a8ff", 1.6, 120)
    c.blit(g, 470, -10)
    c.ellipse(545, 62, 26, 26, "#fff4d8")
    c.ellipse(552, 58, 24, 24, "#fffbea")
    for x, y, r in ((535, 55, 4), (552, 72, 3), (560, 50, 2.5), (540, 74, 2)):
        c.ellipse(x, y, r, r, "#f0e4c0")
    # тонкие облака
    for cx, cy, w in ((120, 70, 90), (330, 40, 120), (600, 110, 80)):
        for i in range(w):
            y = cy + int(math.sin(i / 9) * 2)
            c.blend(cx + i - w // 2, y, (180, 160, 255, 60))
            c.blend(cx + i - w // 2, y + 1, (140, 120, 230, 40))
    c.save("menu/sky.png")


def silhouette(name, W, H, base_y, amp, col_top, col_bot, seed, trees=False, lights=False, snow=False):
    rng = noise_rng(seed)
    c = Canvas(W, H)
    n = tileable_noise(rng, W, 3)
    for x in range(W):
        top = int(base_y - n[x] * amp)
        for y in range(top, H):
            c.set(x, y, mix(col_top, col_bot, (y - top) / max(H - top, 1)))
        if snow and n[x] > 0.68:
            for y in range(top, top + int((n[x] - 0.68) * 30) + 1):
                c.set(x, y, "#c8c0f0")
    if trees:
        x = 0
        while x < W:
            h = rng.randint(10, 26)
            w = rng.randint(7, 12)
            gy = int(base_y - n[x % W] * amp) + 4
            for yy in range(gy - h, gy + 1):
                half = (yy - (gy - h)) / h * w / 2
                for xx in range(int(x - half), int(x + half) + 1):
                    c.set(xx % W, yy, col_top)
            x += rng.randint(4, 9)
    if lights:
        for _ in range(7):
            hx = rng.randrange(W - 12)
            hy = int(base_y - n[hx] * amp) + 6
            c.rect(hx, hy - 8, 12, 9, shade(col_top, -0.2))
            c.poly([(hx - 1, hy - 8), (hx + 6, hy - 13), (hx + 13, hy - 8)], shade(col_top, -0.3))
            c.rect(hx + 2, hy - 6, 3, 3, "#ffcf6a")
            c.rect(hx + 7, hy - 6, 3, 3, "#ffcf6a")
    c.save(f"menu/{name}.png")


def ground():
    W, H = 640, 80
    c = Canvas(W, H)
    c.rect(0, 0, W, H, "#140e2a")
    c.rect(0, 0, W, 3, "#2a2050")
    # насыпь и рельсы
    c.rect(0, 14, W, 10, "#2a2440")
    for x in range(0, W, 12):
        c.rect(x, 18, 8, 4, "#3a2a26")
    c.rect(0, 16, W, 2, "#8a94b8")
    c.rect(0, 16, W, 1, "#c8d0f0")
    rng = noise_rng(8)
    for _ in range(80):
        c.set(rng.randrange(W), rng.randrange(26, H), "#2a2050")
    c.save("menu/ground.png")


def train_side():
    """Поезд сбоку: паровоз и три вагона с тёплыми окнами (≈ 560×70)."""
    cars = []
    W = 0
    # паровоз
    loco = Canvas(150, 72)
    body, dark, light = "#3a3a8a", "#24245a", "#5a5ab8"
    loco.rrect(30, 22, 110, 34, 6, body)
    loco.rect(30, 22, 110, 3, light)
    loco.rrect(4, 30, 36, 26, 10, body)  # котёл-нос
    loco.rect(0, 46, 20, 6, "#5a5a6a")  # скотосбрасыватель
    loco.poly([(0, 56), (14, 44), (14, 56)], "#8a2f3f")
    loco.rect(48, 6, 12, 18, dark)       # труба
    loco.rect(45, 4, 18, 4, light)
    loco.rect(100, 8, 40, 16, body)      # будка
    loco.rect(100, 8, 40, 3, light)
    loco.rect(108, 13, 10, 8, "#ffcf6a")
    loco.rect(122, 13, 10, 8, "#ffcf6a")
    loco.rect(30, 40, 70, 2, "#d9a441")
    loco.ellipse(10, 38, 5, 5, "#fff4c0")  # фара
    for wx in (40, 64, 88, 120):
        loco.ellipse(wx, 60, 9, 9, "#2a2a3a")
        loco.ellipse(wx, 60, 6, 6, "#c0394b")
        loco.ellipse(wx, 60, 2, 2, "#d9a441")
    loco.rect(40, 59, 80, 2, "#aab4c8")
    loco.outline()
    cars.append(loco)
    for i in range(3):
        car = Canvas(150, 72)
        col = ("#4a2a7a", "#2f4377", "#5a2a5a")[i]
        car.rrect(4, 14, 142, 44, 5, col)
        car.rect(4, 14, 142, 4, shade(col, 0.3))
        car.rrect(2, 10, 146, 6, 3, shade(col, -0.35))
        car.rect(4, 50, 142, 3, "#d9a441")
        for wx in range(14, 136, 22):
            car.rect(wx, 24, 14, 16, "#ffcf6a")
            car.rect(wx, 24, 14, 3, "#fff4c0")
            car.rect(wx + 6, 24, 1, 16, shade(col, -0.2))
            # силуэт пассажира в одном из окон
            if (wx + i * 22) % 66 == 14:
                car.ellipse(wx + 4, 33, 3, 3, "#4a2a3a")
                car.rect(wx + 1, 36, 7, 4, "#4a2a3a")
        for wx in (24, 46, 104, 126):
            car.ellipse(wx, 62, 7, 7, "#2a2a3a")
            car.ellipse(wx, 62, 4, 4, "#6a6a8a")
        car.rect(0, 40, 4, 6, "#2a2a3a")
        car.outline()
        cars.append(car)
    out = Canvas(150 * 4 + 6, 72)
    for i, car in enumerate(cars):
        out.blit(car, i * 152, 0)
    out.save("menu/train_side.png")
    # свечение окон (для аддитивного слоя)
    gl = Canvas(out.w, 72)
    for i in range(1, 4):
        for wx in range(14, 136, 22):
            gl.blit(soft_glow(30, "#ffcf6a", 1.6, 120), i * 152 + wx - 8, 17)
    gl.save("menu/train_glow.png")
    # клуб пара
    smoke = Canvas(32, 24)
    for x, y, r in ((10, 14, 8), (18, 10, 9), (24, 14, 7)):
        smoke.ellipse(x, y, r, r * 0.8, (200, 190, 240, 150))
    smoke.save("menu/smoke.png")


def route_map():
    """Иллюстрированная карта долины (вид сверху) 640×360."""
    W, H = 640, 360
    rng = noise_rng(77)
    c = Canvas(W, H)
    c.vgrad(0, 0, W, H, "#4a7a4a", "#3a6a44", dither=True)
    for _ in range(2500):
        x, y = rng.randrange(W), rng.randrange(H)
        c.set(x, y, rng.choice(("#5a8a52", "#3a6240", "#6a9a5a")))
    # горы на севере
    for i in range(9):
        mx = 40 + i * 70 + rng.randint(-10, 10)
        my = 40 + rng.randint(-8, 8)
        h = rng.randint(40, 60)
        c.poly([(mx - 40, my + h // 2), (mx, my - h // 2), (mx + 40, my + h // 2)], "#6a6a8a")
        c.poly([(mx, my - h // 2), (mx + 40, my + h // 2), (mx + 6, my + h // 2)], "#4a4a6a")
        c.poly([(mx - 10, my - h // 2 + 12), (mx, my - h // 2), (mx + 10, my - h // 2 + 12)], "#f4f4ff")
    # снежная область на северо-востоке
    for _ in range(600):
        x, y = rng.randrange(440, W), rng.randrange(60, 170)
        c.set(x, y, "#e8eef8")
    c.ellipse(560, 120, 70, 40, "#dfe6f4", blend=False)
    # река
    pts = []
    for i in range(80):
        t = i / 79
        pts.append((t * W, 230 + math.sin(t * 7) * 30 + t * 40))
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for s in range(8):
            xx = x0 + (x1 - x0) * s / 8
            yy = y0 + (y1 - y0) * s / 8
            c.ellipse(xx, yy, 7, 5, "#3a7ad0")
            c.ellipse(xx, yy - 1, 4, 2.5, "#5aa8f0")
    # озеро
    c.ellipse(140, 300, 50, 26, "#2f6ac0")
    c.ellipse(136, 296, 40, 18, "#4a90e0")
    for i in range(6):
        c.hline(110 + i * 8, 114 + i * 8, 292 + (i % 2) * 6, "#a8d8ff")
    # леса
    tree_cols = ("#1f5a3a", "#2a6a42", "#174a30")
    for _ in range(420):
        x, y = rng.randrange(W), rng.randrange(90, H)
        if 200 < y < 290 and abs(y - (230 + math.sin(x / W * 7) * 30 + x / W * 40)) < 14:
            continue
        r = rng.randint(4, 7)
        col = rng.choice(tree_cols)
        c.ellipse(x + 1, y + 2, r, r * 0.8, (10, 30, 20, 120), blend=True)
        c.ellipse(x, y, r, r * 0.85, col)
        c.ellipse(x - 1, y - 1, r * 0.5, r * 0.4, shade(col, 0.2))
    # домики деревни
    for hx, hy in ((300, 150), (318, 158), (290, 166), (470, 300), (488, 292)):
        c.rect(hx, hy, 12, 9, "#e8d8b8")
        c.poly([(hx - 2, hy), (hx + 6, hy - 7), (hx + 14, hy)], "#c0394b")
        c.rect(hx + 4, hy + 3, 3, 3, "#ffcf6a")
    # виньетка по краям
    for y in range(H):
        for x in range(W):
            d = max(abs(x - W / 2) / (W / 2), abs(y - H / 2) / (H / 2))
            if d > 0.86:
                c.blend(x, y, (20, 14, 50, int(min(1, (d - 0.86) / 0.14) * 170)))
    c.save("menu/route_map.png")


def main():
    sky()
    silhouette("mountains", 640, 200, 120, 70, "#3a2a6a", "#20184a", 5, snow=True)
    silhouette("hills", 640, 140, 70, 30, "#1c1a40", "#120f2e", 9, trees=True, lights=True)
    ground()
    train_side()
    route_map()


if __name__ == "__main__":
    main()
