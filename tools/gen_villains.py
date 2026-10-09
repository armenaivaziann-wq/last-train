#!/usr/bin/env python3
"""Истинные формы злодеев кампании LAST TRAIN в размере NPC (кадр 32×40, ноги на строке 37).
Лист: ряд 0 — «стоит» (2 кадра), ряд 1 — угрожающая поза (2 кадра).
Плюс портреты 64×64 для бестиария и экрана результата.

Запуск:  python3 tools/gen_villains.py
"""
from pixelart import Canvas, OUTLINE, grid

FW, FH = 32, 40
RED = "#d01e30"
RED_DIM = "#7a1420"


def legs(c, col, y0=33, shoes="#0c0a12"):
    c.rect(12, y0, 3, 37 - y0, col)
    c.rect(17, y0, 3, 37 - y0, col)
    c.rect(11, 36, 5, 2, shoes)
    c.rect(17, 36, 5, 2, shoes)


# --- 1. Человек в чёрном плаще: высокий, худой, плащ до пола, шляпа, перчатки ---------------
def black_cloak(f, menace):
    c = Canvas(FW, FH)
    b = f
    cloak, cloak_l, cloak_d = "#18141f", "#2e2840", "#0c0a12"
    if menace:
        # плащ распахнут, руки в перчатках подняты
        c.poly([(16, 12), (2, 37), (30, 37)], cloak)
        c.poly([(16, 12), (4, 36), (9, 37)], cloak_l)
        c.rect(12, 16, 8, 21, "#0c0a12")
        c.line(9, 18, 3, 11 - b, cloak)
        c.line(10, 18, 4, 11 - b, cloak)
        c.line(23, 18, 29, 11 - b, cloak)
        c.line(22, 18, 28, 11 - b, cloak)
        c.rect(2, 9 - b, 3, 3, "#3a3646")
        c.rect(28, 9 - b, 3, 3, "#3a3646")
    else:
        c.poly([(16, 12), (8, 37), (24, 37)], cloak)
        c.poly([(16, 12), (9, 36), (12, 37), (15, 14)], cloak_l)
        c.vline(16, 16, 36, cloak_d)
        c.rect(9, 29, 3, 3, "#3a3646")   # перчатки
        c.rect(21, 29, 3, 3, "#3a3646")
    # высокий воротник
    c.poly([(12, 12), (16, 15), (20, 12), (20, 9), (12, 9)], cloak)
    # тёмное лицо, узкое
    c.rrect(13, 6 + (0 if not menace else -1), 6, 7, 2, "#120e18")
    ey = 9 + (0 if not menace else -1)
    c.set(14, ey, RED if (f == 0 or menace) else RED_DIM)
    c.set(17, ey, RED if (f == 0 or menace) else RED_DIM)
    # шляпа с широкими полями
    hy = 1 + (0 if not menace else -1)
    c.rect(9, hy + 5, 14, 2, "#0c0a12")
    c.rect(12, hy, 8, 6, "#100c16")
    c.rect(12, hy + 4, 8, 1, "#3a2a40")
    c.rect(13, hy, 3, 1, "#2a2234")
    c.outline("#4a4062")  # светлее обычной обводки — силуэт читается на тёмном полу
    return c


# --- 2. Перевёртыш: безликий, «лоскуты» чужой одежды -----------------------------------------
def shapeshifter(f, menace):
    c = Canvas(FW, FH)
    body, dark = "#6a7a96", "#3a4a66"
    legs(c, dark)
    c.rrect(10, 18, 12, 16, 3, body)
    patches = [("#c96a2b", 11, 22), ("#2f8a6b", 17, 26), ("#c0394b", 12, 29), ("#e8b13e", 18, 20)]
    for i, (col, x, y) in enumerate(patches):
        if (i + f) % 2 == 0:
            c.rect(x, y, 4, 3, col)
    arm_y = 12 if menace else 20
    c.rect(7, arm_y, 3, 10, body)
    c.rect(22, arm_y, 3, 10, body)
    c.rrect(8, 4 - (1 if menace else 0), 16, 15, 6, "#8a9ab4")
    # пустое лицо со спиралью
    cx, cy = 16, 11 - (1 if menace else 0)
    for i, (dx, dy) in enumerate(((0, 0), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), (2, -1), (2, 0), (2, 1), (2, 2))):
        if i <= 6 + f * 4:
            c.set(cx + dx, cy + dy, "#4a5a76")
    if menace:
        c.rect(11, 16, 10, 1, "#1a2236")
    c.outline(OUTLINE)
    return c


# --- 3. Зеркальник: фигура из стеклянных осколков ---------------------------------------------
def mirror(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#7ad0ff", 32, "#3a90d0")
    c.poly([(16, 14), (8, 33), (24, 33)], "#5ab8f0")
    c.poly([(16, 14), (16, 33), (24, 33)], "#3a90d0")
    c.poly([(16, 2 - menace), (24, 10), (16, 18), (8, 10)], "#a8e8ff")
    c.poly([(16, 2 - menace), (16, 18), (8, 10)], "#d8f6ff")
    c.set(13, 9, "#1a3a8a")
    c.set(19, 9, "#1a3a8a")
    c.line(11, 22, 14, 18, "#ffffff")
    if menace:
        for x, y in ((4, 8), (28, 8), (6, 20), (26, 20)):
            c.poly([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)], "#c8f4ff")
    c.set(10 + f, 26, "#ffffff")
    c.outline(OUTLINE)
    return c


# --- 4. Мимик: чемодан на коротких ножках с зубастой крышкой ----------------------------------
def mimic(f, menace):
    c = Canvas(FW, FH)
    c.rect(10, 33, 3, 4, "#5e3a26")
    c.rect(19, 33, 3, 4, "#5e3a26")
    open_ = 5 if menace else 1 + f
    c.rrect(5, 20, 22, 14, 2, "#8a5a3c")
    c.rect(5, 29, 22, 2, "#5e3a26")
    c.rect(7, 21, 4, 3, "#d9a441")
    c.rect(5, 19 - open_, 22, open_ + 1, "#5a1a3a")
    for x in range(6, 26, 3):
        c.poly([(x, 19 - open_), (x + 2, 19 - open_), (x + 1, 21 - open_)], "#ffffff")
        c.poly([(x, 20), (x + 2, 20), (x + 1, 18)], "#ffffff")
    c.rrect(5, 8 - open_, 22, 12, 2, "#8a5a3c")
    c.rect(12, 5 - open_, 8, 3, "#5e3a26")
    c.rect(10, 12 - open_, 3, 3, "#fff1a8")
    c.rect(19, 12 - open_, 3, 3, "#fff1a8")
    c.set(11, 13 - open_, OUTLINE)
    c.set(20, 13 - open_, OUTLINE)
    c.rect(26, 24, 4, 3, "#f4ead8")
    c.outline(OUTLINE)
    return c


# --- 5. Теневик: дымчатый силуэт с розовыми глазами -------------------------------------------
def shadow(f, menace):
    c = Canvas(FW, FH)
    body, dark = "#241a40", "#120c24"
    for i in range(6):
        y = 34 + (i % 3)
        c.ellipse(9 + i * 3, y, 3, 2, dark)
    c.rrect(9, 15, 14, 20, 5, body)
    w = 6 if menace else 0
    c.poly([(9, 18), (3 - w // 2, 30), (9, 28)], dark)
    c.poly([(23, 18), (29 + w // 2, 30), (23, 28)], dark)
    c.ellipse(16, 10 - (1 if menace else 0), 7, 7, body)
    eye = "#ff5a8a" if menace or f == 0 else "#b03a6a"
    c.rect(13, 10, 2, 2, eye)
    c.rect(18, 10, 2, 2, eye)
    c.outline("#0a0614")
    return c


# --- 6. Голос за дверью: человек в сером, маска с открытым ртом -------------------------------
def voice(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#2a2236")
    c.rect(10, 18, 12, 15, "#5a5068")
    c.vline(16, 19, 32, "#3a3448")
    c.rect(7, 19 if not menace else 14, 3, 10, "#5a5068")
    c.rect(22, 19, 3, 10, "#5a5068")
    c.rrect(9, 4, 14, 15, 5, "#e8e0d8")
    c.rect(12, 9, 2, 2, OUTLINE)
    c.rect(18, 9, 2, 2, OUTLINE)
    c.ellipse(16, 14, 2.5, 2 + (1 if menace else 0), "#3a1a2a")
    for r in (3, 5) if menace or f else (3,):
        c.set(16 + r + 4, 14 - r // 2, "#c8a8ff")
        c.set(16 + r + 4, 14 + r // 2, "#c8a8ff")
    c.rect(9, 3, 14, 3, "#3a3448")
    c.outline(OUTLINE)
    return c


# --- 7. Сонник: ночной колпак, халат, термос --------------------------------------------------
def sleeper(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#2a2a4a")
    c.rect(9, 18, 14, 16, "#4a4a8a")
    c.rect(9, 26, 14, 2, "#c8b8ff")
    c.rect(21, 22, 5, 9, "#9aa4b4")   # термос
    c.rect(21, 21, 5, 2, "#c0394b")
    c.rect(6, 20, 3, 9, "#4a4a8a")
    c.rrect(9, 5, 14, 14, 5, "#e8c8b0")
    if menace:
        c.rect(11, 10, 3, 2, "#ff5a8a")
        c.rect(18, 10, 3, 2, "#ff5a8a")
    else:
        c.rect(11, 11, 3, 1, OUTLINE)
        c.rect(18, 11, 3, 1, OUTLINE)
    c.rect(14, 15, 4, 1, "#8a3a4a")
    c.poly([(9, 7), (23, 7), (27, 1 + f), (16, 3)], "#6a5ad6")
    c.rect(26, 0 + f, 3, 3, "#ffffff")
    c.outline(OUTLINE)
    return c


# --- 8. Двойник проводницы: форма, кривая фуражка, бледная маска ------------------------------
def conductor_double(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#1a2550")
    c.rect(10, 18, 12, 16, "#2f4377")
    for y in (21, 25, 29):
        c.set(13, y, "#f2c14e")
        c.set(18, y, "#f2c14e")
    c.rect(7, 19 if not menace else 13, 3, 10, "#2f4377")
    c.rect(22, 19, 3, 10, "#2f4377")
    c.rrect(9, 5, 14, 14, 5, "#f0eef4")
    c.rect(12, 10, 2, 2, RED)
    c.rect(18, 10, 2, 2, RED)
    c.rect(12, 15, 8, 1, "#7a1420")
    c.poly([(8, 6), (24, 3), (24, 8), (8, 9)], "#2b3a6b")
    c.rect(14, 5, 3, 2, "#f2c14e")
    c.outline(OUTLINE)
    return c


# --- 9. Кукловод: фрак, цилиндр, белая маска, нити от пальцев ---------------------------------
def puppeteer(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#2a1430")
    c.rect(10, 18, 12, 16, "#5a1a5a")
    c.poly([(10, 30), (8, 37), (13, 34)], "#5a1a5a")
    c.poly([(22, 30), (24, 37), (19, 34)], "#5a1a5a")
    hand_y = 12 if menace else 18
    c.rect(6, hand_y, 3, 8, "#5a1a5a")
    c.rect(23, hand_y, 3, 8, "#5a1a5a")
    for x in (6, 8, 24, 26):
        c.vline(x, 0, hand_y - 1, (230, 230, 255, 160 if f == 0 else 110))
    c.rrect(10, 6, 12, 12, 4, "#ffffff")
    c.set(13, 10, OUTLINE)
    c.set(18, 10, OUTLINE)
    c.line(12, 14, 15, 15, OUTLINE)
    c.line(16, 15, 19, 14, OUTLINE)
    c.rect(11, 0, 10, 7, "#1a1022")
    c.rect(9, 6, 14, 2, "#1a1022")
    c.rect(11, 5, 10, 1, "#c0394b")
    c.outline(OUTLINE)
    return c


# --- 10. Пассажир ноль: чёрная пустота в пальто, на лице — номер «0» --------------------------
def passenger_zero(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#0c0a12")
    c.poly([(16, 14), (7, 36), (25, 36)], "#14111c")
    c.rect(7 if not menace else 3, 20, 3, 10, "#14111c")
    c.rect(22 if not menace else 26, 20, 3, 10, "#14111c")
    c.rrect(9, 3, 14, 14, 5, "#08060c")
    c.ring(16, 10, 3.5, 2.2, "#e8e4f4" if not menace else "#ff3a4a")
    for i in range(6):
        x = (i * 7 + f * 3) % 30 + 1
        y = (i * 11 + f * 5) % 34 + 3
        c.set(x, y, "#5a5070")
    c.outline("#4a4062")
    return c


# --- Глава 2 -----------------------------------------------------------------------------
def ghost(f, menace):
    """Призрак: полупрозрачная бледная фигура в старинном платье, низ растворяется."""
    c = Canvas(FW, FH)
    body, light, dark = (200, 220, 255, 150), (235, 245, 255, 190), (150, 170, 220, 120)
    sway = f
    c.poly([(16, 12), (7 + sway, 34), (25 + sway, 34)], body, blend=True)
    for x in range(8 + sway, 25 + sway, 3):
        c.blend(x, 35 + (x % 2), dark)
        c.blend(x + 1, 37, (150, 170, 220, 60))
    c.rrect(11, 3 - (1 if menace else 0), 10, 10, 4, light, blend=True)
    # волосы и тёмные глазницы
    c.rect(11, 3 - (1 if menace else 0), 10, 3, (120, 130, 170, 170))
    ey = 8 - (1 if menace else 0)
    c.rect(13, ey, 2, 2, (20, 30, 60, 220))
    c.rect(18, ey, 2, 2, (20, 30, 60, 220))
    if menace:
        c.line(9, 16, 2, 8 - f, body)
        c.line(23, 16, 30, 8 - f, body)
        c.rect(15, 11, 3, 2, (20, 30, 60, 220))
    else:
        c.line(10, 16, 8, 26, body)
        c.line(22, 16, 24, 26, body)
    return c


def vampire(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#1a1420")
    cape = "#1a0c14"
    lining = "#8a1424"
    if menace:
        c.poly([(16, 11), (1, 30 - f), (8, 36), (24, 36), (31, 30 - f)], cape)
        c.poly([(16, 13), (5, 29 - f), (10, 34), (22, 34), (27, 29 - f)], lining)
    else:
        c.poly([(16, 11), (7, 36), (25, 36)], cape)
        c.poly([(16, 13), (10, 35), (13, 35)], lining)
    c.rect(12, 14, 8, 20, "#241a2a")
    c.rect(15, 14, 2, 8, "#f0ecf4")
    c.set(16, 16, RED)
    # высокий воротник
    c.poly([(9, 13), (12, 7), (14, 13)], cape)
    c.poly([(23, 13), (20, 7), (18, 13)], cape)
    c.rrect(12, 4, 8, 9, 3, "#e8e0ec")
    c.poly([(12, 4), (16, 7), (20, 4), (20, 2), (12, 2)], "#140c18")
    c.set(14, 8, RED)
    c.set(18, 8, RED)
    if menace or f == 1:
        c.set(14, 11, "#ffffff")
        c.set(18, 11, "#ffffff")
    c.hline(14, 18, 10, "#5a1424")
    c.outline("#4a4062")
    return c


def werewolf(f, menace):
    c = Canvas(FW, FH)
    fur, fur_d, fur_l = "#6a5a4a", "#4a3e32", "#8a7a64"
    c.rect(11, 31, 4, 6, fur_d)
    c.rect(18, 31, 4, 6, fur_d)
    c.rect(10, 36, 6, 2, "#2a221c")
    c.rect(17, 36, 6, 2, "#2a221c")
    c.rrect(9, 14, 15, 18, 5, fur)
    c.rect(12, 18, 9, 10, fur_l)
    # рваные остатки зелёной куртки
    c.poly([(9, 16), (13, 15), (12, 28), (9, 26)], "#4e5a2c")
    c.poly([(24, 16), (20, 15), (21, 27), (24, 25)], "#4e5a2c")
    arm_up = 4 if menace else 0
    c.rect(5, 16 - arm_up, 4, 12, fur)
    c.rect(24, 16 - arm_up, 4, 12, fur)
    for x in (5, 7, 24, 26):
        c.set(x, 28 - arm_up, "#f0ecdf")
    # голова с мордой и ушами
    c.rrect(10, 4, 13, 11, 4, fur)
    c.poly([(10, 6), (11, 0), (14, 4)], fur_d)
    c.poly([(23, 6), (22, 0), (19, 4)], fur_d)
    c.rrect(13, 9, 7, 6, 2, fur_l)
    c.rect(15, 9, 3, 2, "#1a1414")
    ey = 7
    c.set(12, ey, "#ffd23a" if (menace or f == 0) else "#b08a2a")
    c.set(20, ey, "#ffd23a" if (menace or f == 0) else "#b08a2a")
    if menace:
        c.hline(14, 19, 14, "#ffffff")
        c.set(14, 13, "#ffffff")
        c.set(19, 13, "#ffffff")
    c.outline("#4a4062")
    return c


def witch(f, menace):
    c = Canvas(FW, FH)
    legs(c, "#1e1434")
    robe, robe_d = "#2e1f4a", "#1e1434"
    c.poly([(16, 12), (6, 37), (26, 37)], robe)
    c.poly([(16, 14), (8, 36), (11, 36)], "#43306a")
    c.vline(16, 16, 36, robe_d)
    # пояс со склянками
    c.rect(10, 22, 13, 2, "#6a4c2c")
    for x, col in ((11, "#7fd18a"), (15, "#c0394b"), (19, "#5ab8f0")):
        c.rect(x, 24, 2, 3, col)
    if menace:
        c.line(9, 16, 3, 9 - f, robe)
        c.line(23, 16, 29, 9 - f, robe)
        for i in range(5):
            c.set(29 + (i % 2), 7 - f - i, "#7fd18a")
            c.set(2 - (i % 2), 7 - f - i, "#7fd18a")
    else:
        c.rect(7, 18, 3, 10, robe)
        c.rect(22, 18, 3, 10, robe)
    c.rrect(12, 6, 8, 8, 3, "#ece2ea")
    c.set(14, 9, "#7fd18a")
    c.set(18, 9, "#7fd18a")
    # остроконечная шляпа
    c.rect(8, 6, 16, 2, "#140c22")
    c.poly([(11, 6), (21, 6), (18 + f, -1), (16 + f, -2)], "#1e1434")
    c.rect(11, 5, 10, 1, "#7fd18a")
    c.outline("#4a4062")
    return c


VILLAINS = {
    "black_cloak": black_cloak, "shapeshifter": shapeshifter, "mirror": mirror, "mimic": mimic,
    "shadow": shadow, "voice": voice, "sleeper": sleeper, "conductor_double": conductor_double,
    "puppeteer": puppeteer, "passenger_zero": passenger_zero,
    "ghost": ghost, "vampire": vampire, "werewolf": werewolf, "witch": witch,
}


def main():
    for vid, fn in VILLAINS.items():
        rows = [[fn(0, False), fn(1, False)], [fn(0, True), fn(1, True)]]
        grid(rows).save(f"villains/{vid}.png")
        p = Canvas(64, 64)
        p.blit(fn(0, True).sub(0, 0, 32, 32).scaled(2), 0, 0)
        p.save(f"portraits/villain_{vid}.png")


if __name__ == "__main__":
    main()
