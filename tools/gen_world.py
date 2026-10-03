#!/usr/bin/env python3
"""Мир снаружи поезда: пейзажи для окон (вид сбоку, бесшовные по X) и земля по бокам поезда
(вид сверху), деревья, фонари, платформа станции, стены туннеля.

Запуск:  python3 tools/gen_world.py
"""
import math

from pixelart import Canvas, hexc, mix, noise_rng, shade, soft_glow

NIGHT_TOP = "#0c0a26"
NIGHT_BOTTOM = "#3a2a6a"


def tileable_noise(rng, n, octaves=3):
    """Одномерный периодический шум длины n (для бесшовных силуэтов)."""
    vals = [0.0] * n
    amp = 1.0
    for o in range(octaves):
        k = 2 ** (o + 1)
        phases = [rng.random() * math.tau for _ in range(3)]
        for i in range(n):
            t = i / n * math.tau
            vals[i] += amp * sum(math.sin(t * k * (j + 1) + phases[j]) / (j + 1) for j in range(3))
        amp *= 0.5
    lo, hi = min(vals), max(vals)
    return [(v - lo) / (hi - lo) for v in vals]


def window_layers():
    W, H = 512, 48
    rng = noise_rng(7)
    # небо со звёздами
    sky = Canvas(W, H)
    sky.vgrad(0, 0, W, H, NIGHT_TOP, NIGHT_BOTTOM)
    for _ in range(90):
        x, y = rng.randrange(W), rng.randrange(H - 14)
        b = rng.random()
        sky.set(x, y, "#ffffff" if b > 0.8 else "#b8b8f0")
        if b > 0.93:
            sky.set(x + 1, y, "#8888c8")
            sky.set(x - 1, y, "#8888c8")
    sky.save("world/window_sky.png")

    # дальние горы со снежными шапками
    mnt = Canvas(W, H)
    hts = tileable_noise(rng, W, 2)
    for x in range(W):
        top = int(30 - hts[x] * 22)
        for y in range(top, H):
            t = (y - top) / max(H - top, 1)
            mnt.set(x, y, mix("#4a3a8a", "#24204a", t))
        if hts[x] > 0.72:
            cap = int((hts[x] - 0.72) * 18) + 1
            for y in range(top, top + cap):
                mnt.set(x, y, "#b8b0e8")
        mnt.set(x, top, "#8a7ad0")
    mnt.save("world/window_mountains.png")

    # лес средним планом + редкие окошки домов
    forest = Canvas(W, H)
    base = tileable_noise(rng, W, 2)
    for x in range(W):
        top = int(26 + base[x] * 8)
        for y in range(top, H):
            forest.set(x, y, "#16233a")
    x = 0
    while x < W:
        h = rng.randint(12, 22)
        w = rng.randint(5, 9)
        cx = x
        gy = int(26 + base[x % W] * 8)
        for yy in range(gy - h, gy + 1):
            half = (yy - (gy - h)) / h * w / 2
            for xx in range(int(cx - half), int(cx + half) + 1):
                forest.set(xx % W, yy, "#1a2c44")
        x += rng.randint(5, 10)
    for _ in range(5):
        hx = rng.randrange(W)
        hy = int(30 + base[hx] * 8)
        forest.rect(hx, hy - 6, 9, 7, "#2a2238")
        forest.rect(hx + 2, hy - 4, 2, 2, "#ffcf6a")
        forest.rect(hx + 5, hy - 4, 2, 2, "#ffcf6a")
    forest.save("world/window_forest.png")

    # ближний план: столбы и ели (тёмные силуэты, быстрые)
    near = Canvas(256, H)
    near.rect(0, 40, 256, 8, "#0a0e1a")
    for px in (30, 158):
        near.rect(px, 4, 3, 40, "#0e1220")
        near.rect(px - 6, 8, 15, 2, "#0e1220")
        near.set(px - 6, 7, "#ffd27a")
        near.set(px + 8, 7, "#ffd27a")
    for tx in (80, 110, 210):
        h = rng.randint(26, 38)
        for yy in range(H - h, H):
            half = (yy - (H - h)) / h * 9
            near.rect(int(tx - half), yy, int(half * 2) + 1, 1, "#0b1424")
    for x in range(256):
        near.set(x, 0, (0, 0, 0, 0))
    near.save("world/window_near.png")

    # стены туннеля (кирпич) для окон
    tun = Canvas(128, H)
    tun.rect(0, 0, 128, H, "#1a1626")
    for y in range(0, H, 6):
        off = (y // 6) % 2 * 8
        for x in range(-off, 128, 16):
            tun.rect(x + 1, y + 1, 14, 4, "#2a2236")
            tun.rect(x + 1, y + 1, 14, 1, "#3a3048")
    tun.rect(60, 18, 6, 6, "#ffcf6a")
    tun.save("world/window_tunnel.png")

    # огни станции за окном
    st = Canvas(256, H, )
    st.rect(0, 30, 256, 18, "#2a2a40")
    st.rect(0, 30, 256, 2, "#e8b13e")
    for lx in range(20, 256, 64):
        st.rect(lx, 6, 2, 24, "#3a3a52")
        st.rect(lx - 3, 4, 8, 3, "#3a3a52")
        st.blit(soft_glow(20, "#ffd27a", 1.5, 220), lx - 9, -4)
    st.rect(100, 14, 48, 12, "#1e2a52")
    st.rect(102, 16, 44, 8, "#2f4377")
    st.save("world/window_station.png")


def ground_strip(kind):
    """Полоса земли вдоль поезда (вид сверху), высота 96, бесшовная по X.
    Верх полосы прилегает к вагону (щебень и концы шпал), дальше трава/снег."""
    W, H = 256, 96
    rng = noise_rng(31 if kind == "forest" else 47)
    c = Canvas(W, H)
    grass = "#1c3a3e" if kind == "forest" else "#c8d0e8"
    grass_d = "#16302f" if kind == "forest" else "#a8b0d0"
    grass_l = "#2a5a52" if kind == "forest" else "#e8eef8"
    for y in range(H):
        for x in range(W):
            c.set(x, y, grass)
    for _ in range(500):
        x, y = rng.randrange(W), rng.randrange(18, H)
        c.set(x, y, rng.choice((grass_d, grass_l, grass_d)))
    # щебень у полотна
    for y in range(0, 18):
        for x in range(W):
            v = rng.random()
            c.set(x, y, "#4a4658" if v < 0.4 else ("#5e5a70" if v < 0.75 else "#35323f"))
    for x in range(0, W, 16):
        c.rect(x + 2, 0, 9, 7, "#4a3426")
        c.rect(x + 2, 0, 9, 1, "#6a4a36")
        c.rect(x + 2, 6, 9, 1, "#2e2018")
    c.rect(0, 17, W, 1, shade(grass, -0.3))
    # кустики, цветы/сугробы
    for _ in range(14):
        x, y = rng.randrange(W), rng.randrange(28, H - 6)
        if kind == "forest":
            c.ellipse(x, y, 5, 3.5, "#1f4a3e")
            c.ellipse(x - 1, y - 1, 3, 2, "#2f6a52")
            if rng.random() < 0.4:
                c.set(x + 2, y - 2, "#e86aa8")
        else:
            c.ellipse(x, y, 6, 3, "#e8eef8")
            c.ellipse(x, y + 1, 5, 2, "#b8c0dc")
    if kind == "forest":
        for _ in range(30):
            x, y = rng.randrange(W), rng.randrange(24, H)
            c.set(x, y, "#3a7a5a")
            c.set(x, y - 1, "#3a7a5a")
    return c


def top_trees():
    rng = noise_rng(55)
    # ель сверху
    for i, (col, light) in enumerate((("#163a34", "#2a6a50"), ("#1a3044", "#2f5a6a"))):
        c = Canvas(40, 40)
        c.ellipse(21, 23, 17, 15, (5, 5, 20, 110))  # тень
        for r, cc in ((18, shade(col, -0.2)), (14, col), (9, light), (4, shade(light, 0.2))):
            for a in range(16):
                ang = a / 16 * math.tau
                rr = r * (0.82 if a % 2 else 1.0)
                c.ellipse(20 + math.cos(ang) * rr * 0.35, 19 + math.sin(ang) * rr * 0.35, rr * 0.7, rr * 0.7, cc)
        c.set(19, 18, "#7ad28a")
        c.save(f"world/tree_top_{i}.png")
    # заснеженная ель
    c = Canvas(40, 40)
    c.ellipse(21, 23, 17, 15, (5, 5, 20, 110))
    c.ellipse(20, 19, 15, 15, "#1a3a3a")
    c.ellipse(20, 19, 11, 11, "#e8eef8")
    c.ellipse(19, 18, 7, 7, "#ffffff")
    for a in range(8):
        ang = a / 8 * math.tau
        c.ellipse(20 + math.cos(ang) * 12, 19 + math.sin(ang) * 12, 3, 3, "#d8e0f0")
    c.save("world/tree_top_snow.png")
    # фонарный столб сверху (со светом)
    c = Canvas(24, 24)
    c.ellipse(12, 12, 4, 4, "#2a2a3a")
    c.ellipse(12, 12, 2.5, 2.5, "#ffe08a")
    c.save("world/lamp_top.png")
    soft_glow(64, "#ffcf6a", 1.4, 170).save("world/lamp_glow.png")


def platform_strip():
    W, H = 256, 96
    c = Canvas(W, H)
    c.rect(0, 0, W, H, "#5a5670")
    for y in range(0, H, 16):
        for x in range(0, W, 16):
            c.rect(x, y, 15, 15, "#6a6680" if (x // 16 + y // 16) % 2 else "#625e78")
    c.rect(0, 0, W, 6, "#e8b13e")
    for x in range(0, W, 8):
        c.rect(x, 0, 4, 6, "#2a2a2a")
    c.rect(0, 6, W, 2, "#3a3650")
    for x in (40, 168):
        c.rrect(x, 40, 30, 10, 3, "#6b3f2c")
        c.rect(x + 2, 41, 26, 2, "#8a5a3c")
    c.save("world/platform_top.png")


def tunnel_top():
    W, H = 128, 96
    c = Canvas(W, H)
    c.rect(0, 0, W, H, "#141220")
    for y in range(0, H, 8):
        off = (y // 8) % 2 * 8
        for x in range(-off, W, 16):
            c.rect(x + 1, y + 1, 14, 6, "#1e1a2c")
    c.rect(0, 0, W, 18, "#2a2636")
    c.save("world/tunnel_top.png")


def main():
    window_layers()
    ground_strip("forest").save("world/ground_forest.png")
    ground_strip("snow").save("world/ground_snow.png")
    top_trees()
    platform_strip()
    tunnel_top()
    # капли дождя на стекле (тайл)
    rng = noise_rng(9)
    rain = Canvas(64, 48)
    for _ in range(26):
        x, y = rng.randrange(64), rng.randrange(48)
        ln = rng.randint(2, 5)
        for i in range(ln):
            rain.set(x - i // 2, y + i, (190, 220, 255, 150 - i * 20))
    rain.save("world/rain_glass.png")


if __name__ == "__main__":
    main()
