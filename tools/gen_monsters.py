#!/usr/bin/env python3
"""Истинные формы монстров LAST TRAIN (милые, но странные). Кадр 48×48, 4 кадра парения,
плюс портреты 64×64 для бестиария.

Запуск:  python3 tools/gen_monsters.py
"""
import math

from pixelart import Canvas, OUTLINE, grid, mix, shade

FW = FH = 48


def eyes(c, x0, x1, y, col="#fff1a8", pupil=OUTLINE, r=3.2, glow=None, blink=False):
    for x in (x0, x1):
        if glow:
            c.ellipse(x, y, r + 2, r + 2, glow, blend=True)
        if blink:
            c.rect(int(x - r), int(y), int(r * 2), 1, OUTLINE)
            continue
        c.ellipse(x, y, r, r + 0.6, col)
        c.ellipse(x + 0.6, y + 0.8, r * 0.45, r * 0.55, pupil)
        c.set(x - 1, y - 1, "#ffffff")


def doppel(f):
    """Двойник: фиолетовая «пластилиновая» фигурка с рожками, наполовину копирующая человека."""
    c = Canvas(FW, FH)
    b = [0, -1, -2, -1][f]
    body, dark, light = "#8a4ae0", "#5a2aa8", "#b88aff"
    c.ellipse(24, 44, 12, 3, (20, 10, 40, 100), blend=True)
    c.ellipse(24, 28 + b, 15, 15, body)
    c.rect(9, 28 + b, 30, 12, body)
    # «капли» по низу
    for i, x in enumerate(range(10, 40, 6)):
        h = 3 + ((i + f) % 3)
        c.ellipse(x + 2, 40 + b + h / 2, 3, h / 2 + 1, body)
    c.ellipse(19, 22 + b, 6, 5, light)
    c.ellipse(24, 34 + b, 13, 5, dark)
    c.ellipse(24, 32 + b, 14, 5, body)
    # рожки
    c.poly([(12, 18 + b), (9, 7 + b), (17, 15 + b)], body)
    c.poly([(36, 18 + b), (39, 7 + b), (31, 15 + b)], body)
    c.set(10, 9 + b, light)
    c.set(38, 9 + b, light)
    eyes(c, 18, 30, 25 + b, glow=(255, 230, 120, 70), blink=(f == 3))
    # улыбка с клычком
    c.rect(19, 32 + b, 10, 1, OUTLINE)
    c.set(18, 31 + b, OUTLINE)
    c.set(29, 31 + b, OUTLINE)
    c.set(21, 33 + b, "#ffffff")
    c.set(26, 33 + b, "#ffffff")
    # половинка «маски» человека — галстук и воротник (следы копирования)
    c.rect(22, 36 + b, 4, 3, "#2f3f6b")
    c.poly([(19, 35 + b), (24, 37 + b), (21, 39 + b)], "#f0ecdf")
    c.poly([(29, 35 + b), (24, 37 + b), (27, 39 + b)], "#f0ecdf")
    for i in range(3):
        a = (f * 0.7 + i * 2.1)
        c.set(24 + math.cos(a) * 18, 20 + math.sin(a) * 10 + b, "#d8b8ff")
    return c.outline()


def mirror(f):
    """Зеркальник: хрустальный осколок-призрак с гранями и перевёрнутым отражением."""
    c = Canvas(FW, FH)
    b = [0, -1, -2, -1][f]
    c.ellipse(24, 45, 10, 2.5, (20, 40, 80, 100), blend=True)
    pts = [(24, 4 + b), (36, 14 + b), (38, 30 + b), (30, 42 + b), (18, 42 + b), (10, 30 + b), (12, 14 + b)]
    c.poly(pts, "#5ab8f0")
    c.poly([(24, 4 + b), (36, 14 + b), (24, 22 + b)], "#a8e8ff")
    c.poly([(24, 4 + b), (12, 14 + b), (24, 22 + b)], "#7ad0ff")
    c.poly([(12, 14 + b), (10, 30 + b), (24, 22 + b)], "#3a90d0")
    c.poly([(36, 14 + b), (38, 30 + b), (24, 22 + b)], "#4aa8e8")
    c.poly([(10, 30 + b), (18, 42 + b), (30, 42 + b), (38, 30 + b), (24, 22 + b)], "#2a78c0")
    # блики и «отражение» внутри
    c.line(16, 12 + b, 20, 8 + b, "#ffffff")
    c.line(30, 34 + b, 33, 30 + b, "#c8f4ff")
    eyes(c, 19, 29, 22 + b, col="#ffffff", pupil="#1a3a8a", r=3, glow=(150, 230, 255, 70), blink=(f == 2))
    c.rect(21, 30 + b, 6, 1, "#1a3a8a")
    c.set(20, 29 + b, "#1a3a8a")
    c.set(27, 29 + b, "#1a3a8a")
    # парящие осколки
    for i in range(3):
        a = f * 0.8 + i * 2.1
        x, y = 24 + math.cos(a) * 20, 24 + math.sin(a) * 14 + b
        c.poly([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)], "#c8f4ff")
    return c.outline()


def shadow(f):
    """Теневик: клубок тени с горящими глазами и тянущимся «хвостом»."""
    c = Canvas(FW, FH)
    b = [0, -1, -2, -1][f]
    body, dark = "#2a1e4a", "#140e2a"
    for i in range(6):
        a = i / 6 * math.tau + f * 0.3
        c.ellipse(24 + math.cos(a) * 9, 26 + b + math.sin(a) * 7, 9, 9, dark)
    c.ellipse(24, 26 + b, 14, 13, body)
    c.ellipse(20, 20 + b, 6, 4, "#3e2e6a")
    # хвост
    for i in range(10):
        c.ellipse(24 + math.sin(i * 0.6 + f) * 3, 38 + i * 0.9 + b, 6 - i * 0.5, 2, dark)
    c.poly([(13, 18 + b), (10, 9 + b), (18, 14 + b)], body)
    c.poly([(35, 18 + b), (38, 9 + b), (30, 14 + b)], body)
    eyes(c, 18, 30, 25 + b, col="#ff5a8a", pupil="#fff1a8", r=3.2, glow=(255, 60, 120, 90), blink=(f == 3))
    c.rect(20, 32 + b, 8, 1, "#ff5a8a")
    c.set(19, 31 + b, "#ff5a8a")
    c.set(28, 31 + b, "#ff5a8a")
    return c.outline("#0a0614")


def mimic(f):
    """Мимик: чемодан с глазками, зубастой крышкой и языком."""
    c = Canvas(FW, FH)
    b = [0, -1, 0, 1][f]
    open_ = [3, 5, 7, 5][f]
    c.ellipse(24, 45, 16, 3, (20, 10, 40, 100), blend=True)
    # нижняя часть
    c.rrect(6, 24 + b, 36, 18, 3, "#8a5a3c")
    c.rect(7, 25 + b, 34, 2, "#a8744c")
    c.rect(6, 38 + b, 36, 2, "#5e3a26")
    c.rect(10, 34 + b, 4, 6, "#d9a441")
    c.rect(34, 34 + b, 4, 6, "#d9a441")
    # пасть
    c.rect(8, 24 - open_ + b, 32, open_ + 1, "#5a1a3a")
    c.ellipse(26, 25 + b, 7, 3, "#ff6a9a")
    for x in range(9, 39, 4):
        c.poly([(x, 24 - open_ + b), (x + 3, 24 - open_ + b), (x + 1.5, 27 - open_ + b)], "#ffffff")
        c.poly([(x, 24 + b), (x + 3, 24 + b), (x + 1.5, 21 + b)], "#ffffff")
    # крышка
    c.rrect(6, 8 - open_ + b, 36, 16, 3, "#8a5a3c")
    c.rect(7, 9 - open_ + b, 34, 2, "#a8744c")
    c.rect(18, 4 - open_ + b, 12, 5, "#5e3a26")
    c.rect(20, 6 - open_ + b, 8, 3, (0, 0, 0, 0))
    eyes(c, 17, 31, 15 - open_ + b, col="#fff1a8", pupil="#3a1a5a", r=3.4, blink=(f == 2))
    c.rect(22, 20 - open_ + b, 4, 3, "#d9a441")
    # бирка
    c.rect(38, 28 + b, 6, 4, "#f4ead8")
    c.set(37, 27 + b, "#5e3a26")
    return c.outline()


MONSTERS = {"doppelganger": doppel, "mirror": mirror, "shadow": shadow, "mimic": mimic}


def main():
    for mid, fn in MONSTERS.items():
        frames = [fn(i) for i in range(4)]
        grid([frames]).save(f"monsters/{mid}.png")
        q = Canvas(64, 64)
        q.blit(frames[0], 8, 10)
        q.save(f"portraits/monster_{mid}.png")


if __name__ == "__main__":
    main()
