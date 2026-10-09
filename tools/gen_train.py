#!/usr/bin/env python3
"""Вагоны LAST TRAIN (вид сверху 3/4): фон, отдельные спрайты предметов и разметка JSON.

Единый источник геометрии: этот файл рисует вагоны и пишет data/layout/<carriage>.json
(коллизии, точки NPC, слоты багажа, камеры, двери, окна, лампы, интерактивные объекты).
Запуск:  python3 tools/gen_train.py
"""
import json
import math
import os

from pixelart import Canvas, OUTLINE, ROOT, hexc, mix, noise_rng, shade, soft_glow

H = 208
CAP = 8          # верхний торец стены (крыша)
FACE_BOTTOM = 56  # низ лицевой стороны стены = начало пола
FLOOR_BOTTOM = 192
CORRIDOR_Y = 166  # линия маршрутов NPC (общая для всех вагонов)
DOOR_Y0, DOOR_Y1 = 140, 188

LAYOUT_DIR = os.path.join(ROOT, "data", "layout")

# --- палитры -----------------------------------------------------------------------------
WOOD = "#8a5a3c"
WOOD_D = "#5e3a26"
WOOD_L = "#a8744c"
GOLD = "#d9a441"
GOLD_L = "#ffd86b"
VELVET = "#b23a52"
VELVET_D = "#7a2238"
VELVET_L = "#d65a6e"
CARPET = "#9a2c46"
CARPET_D = "#6e1e34"


class Layout:
    def __init__(self, cid, name, w):
        self.d = {
            "id": cid, "name": name, "size": [w, H], "corridor_y": CORRIDOR_Y,
            "colliders": [], "spots": {}, "props": [], "interactables": [], "luggage_slots": {},
            "cameras": [], "doors": [], "windows": [], "lamps": [], "window_lights": [],
        }

    def col(self, x, y, w, h):
        self.d["colliders"].append([x, y, w, h])

    def spot(self, sid, x, y, facing="down", pose="stand", via=None):
        """via — X прохода, по которому NPC выходит к коридору (чтобы не идти сквозь скамью)."""
        self.d["spots"][sid] = {"pos": [x, y], "facing": facing, "pose": pose}
        if via is not None:
            self.d["spots"][sid]["via"] = via

    def prop(self, sprite, x, y, collider=None, glow=None):
        e = {"sprite": sprite, "pos": [x, y]}
        if glow:
            e["glow"] = glow
        self.d["props"].append(e)
        if collider:
            self.col(*collider)

    def inter(self, iid, x, y, label, sprite=None, radius=26):
        self.d["interactables"].append({"id": iid, "pos": [x, y], "label": label, "sprite": sprite, "radius": radius})

    def save(self):
        os.makedirs(LAYOUT_DIR, exist_ok=True)
        path = os.path.join(LAYOUT_DIR, self.d["id"] + ".json")
        with open(path, "w") as f:
            json.dump(self.d, f, ensure_ascii=False, indent=1)
        print("  ", os.path.relpath(path, ROOT))


# --- общие элементы фона -----------------------------------------------------------------
def wood_floor(c, x0, y0, x1, y1, base=WOOD, seed=1, plank_h=8):
    rng = noise_rng(seed)
    y = y0
    row = 0
    while y < y1:
        off = (row * 23) % 40
        x = x0 - off
        while x < x1:
            ln = rng.choice((32, 40, 48))
            tone = rng.choice((-0.08, -0.03, 0.0, 0.04, 0.08))
            col = shade(base, tone)
            for yy in range(y, min(y + plank_h, y1)):
                for xx in range(max(x, x0), min(x + ln, x1)):
                    c.set(xx, yy, col)
            # стык и прожилки
            if x >= x0:
                c.vline(x, y, min(y + plank_h, y1) - 1, shade(base, -0.35))
            for _ in range(2):
                gx = rng.randint(max(x, x0), max(max(x, x0), min(x + ln, x1) - 1))
                gy = rng.randint(y + 2, y + plank_h - 3)
                c.hline(gx, min(gx + rng.randint(3, 8), x1 - 1), gy, shade(col, -0.12))
            x += ln
        c.hline(x0, x1 - 1, min(y + plank_h, y1) - 1, shade(base, -0.3))
        c.hline(x0, x1 - 1, y, shade(base, 0.06))
        y += plank_h
        row += 1


def carpet_runner(c, x0, y0, x1, y1, base=CARPET, dark=CARPET_D, trim=GOLD, motif="diamond"):
    c.rect(x0, y0, x1 - x0, y1 - y0, base)
    c.rect(x0, y0, x1 - x0, 2, dark)
    c.rect(x0, y1 - 2, x1 - x0, 2, dark)
    c.rect(x0, y0 + 2, x1 - x0, 1, trim)
    c.rect(x0, y1 - 3, x1 - x0, 1, trim)
    cy = (y0 + y1) // 2
    for x in range(x0 + 8, x1 - 4, 16):
        if motif == "diamond":
            for d in range(4):
                c.set(x - d, cy - 3 + d, trim)
                c.set(x + d, cy - 3 + d, trim)
                c.set(x - d, cy + 3 - d, trim)
                c.set(x + d, cy + 3 - d, trim)
            c.set(x, cy, GOLD_L)
        else:
            c.ellipse(x, cy, 3, 3, trim)
            c.ellipse(x, cy, 1.6, 1.6, base)
        c.set(x + 8, cy - 6, shade(base, 0.15))
        c.set(x + 8, cy + 6, shade(base, 0.15))


def wall_face(c, x0, x1, upper, upper_d, pattern="dots", wain=WOOD_D, seed=3):
    """Лицевая сторона верхней стены: обои сверху, деревянная панель снизу, золотой кант."""
    c.rect(x0, CAP, x1 - x0, FACE_BOTTOM - CAP, upper)
    rng = noise_rng(seed)
    if pattern == "dots":
        for y in range(CAP + 4, 40, 6):
            for x in range(x0 + ((y // 6) % 2) * 3, x1, 6):
                c.set(x, y, upper_d)
    elif pattern == "damask":
        for y in range(CAP + 5, 40, 10):
            for x in range(x0 + ((y // 10) % 2) * 6, x1, 12):
                c.set(x, y - 1, upper_d)
                c.set(x - 1, y, upper_d)
                c.set(x + 1, y, upper_d)
                c.set(x, y + 1, upper_d)
                c.set(x, y, GOLD)
    elif pattern == "stripes":
        for x in range(x0, x1):
            if x % 8 < 2:
                c.vline(x, CAP, 40, upper_d)
    # деревянная панель (вагонка)
    c.rect(x0, 40, x1 - x0, FACE_BOTTOM - 40, wain)
    for x in range(x0, x1, 12):
        c.vline(x, 42, FACE_BOTTOM - 2, shade(wain, -0.3))
        c.vline(x + 1, 42, FACE_BOTTOM - 2, shade(wain, 0.12))
    c.rect(x0, 40, x1 - x0, 2, GOLD)
    c.rect(x0, 40, x1 - x0, 1, GOLD_L)
    c.rect(x0, FACE_BOTTOM - 2, x1 - x0, 2, shade(wain, -0.45))
    # торец стены (крыша) сверху
    c.rect(x0, 0, x1 - x0, CAP, "#232038")
    c.rect(x0, CAP - 2, x1 - x0, 2, "#3a3456")
    c.rect(x0, 0, x1 - x0, 1, "#4a4470")
    for x in range(x0 + 6, x1, 16):
        c.set(x, 3, "#5a5480")
    # потолочный карниз
    c.rect(x0, CAP, x1 - x0, 2, shade(upper, -0.35))


def window(c, x, y, w, h, curtain="#6b2f7a", arched=False):
    """Окно в лицевой стене: прозрачный проём (за ним — движущийся пейзаж), рама, шторы."""
    frame_c = "#4a2c1e"
    c.rect(x - 3, y - 3, w + 6, h + 6, frame_c)
    c.rect(x - 2, y - 2, w + 4, h + 4, GOLD)
    c.rect(x - 1, y - 1, w + 2, h + 2, shade(frame_c, -0.2))
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if arched:
                r = w / 2
                if yy < y + r:
                    if math.hypot(xx + 0.5 - (x + r), yy + 0.5 - (y + r)) > r:
                        c.set(xx, yy, frame_c)
                        continue
            c.set(xx, yy, (0, 0, 0, 0))
    # блик на стекле (полупрозрачный)
    for i in range(min(w, h) - 4):
        c.blend(x + 3 + i, y + h - 4 - i, (255, 255, 255, 40))
        c.blend(x + 6 + i, y + h - 4 - i, (255, 255, 255, 22))
    # средник
    c.rect(x + w // 2, y, 1, h, frame_c)
    # подоконник
    c.rect(x - 4, y + h + 2, w + 8, 3, WOOD_L)
    c.rect(x - 4, y + h + 4, w + 8, 1, WOOD_D)
    # шторы с подхватами
    for side in (0, 1):
        cx0 = x - 6 if side == 0 else x + w - 2
        for yy in range(y - 4, y + h + 1):
            t = (yy - y + 4) / (h + 5)
            ww = 6 + int(3 * math.sin(t * math.pi))
            xs = cx0 if side == 0 else cx0 + 8 - ww
            for xx in range(xs, xs + ww):
                fold = (xx - xs) % 3 == 0
                c.set(xx, yy, shade(curtain, -0.25) if fold else curtain)
        c.rect(cx0 + 1, y + h // 2, 7, 2, GOLD)
    # карниз
    c.rect(x - 8, y - 6, w + 16, 2, GOLD)
    c.set(x - 9, y - 6, GOLD_L)
    c.set(x + w + 8, y - 6, GOLD_L)


def sconce(c, x, y):
    c.rect(x - 1, y + 2, 3, 8, GOLD)
    c.rect(x - 4, y + 8, 9, 2, "#b07a2a")
    c.ellipse(x + 0.5, y, 5, 4.5, "#ffd27a")
    c.ellipse(x + 0.5, y - 0.5, 3.5, 3, "#ffe8a8")
    c.ellipse(x + 0.5, y - 1, 2, 1.6, "#ffffff")


def end_walls(c, w, layout, left_locked=False, right_locked=False):
    for x0 in (0, w - 8):
        c.rect(x0, 0, 8, H, "#3a3456")
        c.rect(x0 + 1, CAP, 6, FACE_BOTTOM - CAP, "#2e2a48")
        c.rect(x0, 0, 8, CAP, "#232038")
        c.vline(x0 + (7 if x0 == 0 else 0), CAP, H - 1, "#4a4470")
        # проём двери
        c.rect(x0, DOOR_Y0, 8, DOOR_Y1 - DOOR_Y0, "#14121e")
    layout.col(0, 0, 8, DOOR_Y0)
    layout.col(0, DOOR_Y1, 8, H - DOOR_Y1)
    layout.col(w - 8, 0, 8, DOOR_Y0)
    layout.col(w - 8, DOOR_Y1, 8, H - DOOR_Y1)
    layout.d["doors"].append({"id": "left", "pos": [4, (DOOR_Y0 + DOOR_Y1) // 2], "locked": left_locked})
    layout.d["doors"].append({"id": "right", "pos": [w - 4, (DOOR_Y0 + DOOR_Y1) // 2], "locked": right_locked})


def bottom_wall(c, w, window_xs, glass="#6a8ab8"):
    """Нижняя стена видна сверху: толщина 16px, узкие окна коридора."""
    c.rect(0, FLOOR_BOTTOM, w, H - FLOOR_BOTTOM, "#3a3456")
    c.rect(0, FLOOR_BOTTOM, w, 2, "#5a3426")
    c.rect(0, FLOOR_BOTTOM + 2, w, 1, GOLD)
    c.rect(0, H - 3, w, 3, "#232038")
    for x in window_xs:
        c.rect(x, FLOOR_BOTTOM + 5, 34, 6, "#1a1830")
        c.rect(x + 1, FLOOR_BOTTOM + 6, 32, 4, glass)
        c.rect(x + 1, FLOOR_BOTTOM + 6, 32, 1, shade(glass, 0.35))
        c.set(x + 4, FLOOR_BOTTOM + 8, "#ffffff")
        c.set(x + 5, FLOOR_BOTTOM + 7, "#ffffff")


def bench_vertical(c, x, y, w, h, facing):
    """Мягкая скамья вдоль перегородки; facing — куда смотрит сидящий ('right'/'left')."""
    # тень на полу (свет ламп сверху-слева)
    c.brect(x + 3, y + 4, w, h + 2, (24, 10, 34, 70))
    c.rrect(x, y, w, h, 3, VELVET_D)
    back_x = x if facing == "right" else x + w - 7
    seat_x = x + 7 if facing == "right" else x
    c.rrect(seat_x, y + 2, w - 7, h - 4, 2, VELVET)
    c.rect(seat_x + 1, y + 3, w - 9, 1, VELVET_L)
    # спинка
    c.rrect(back_x, y, 7, h, 2, shade(VELVET_D, -0.1))
    c.rect(back_x + 1, y + 1, 5, h - 2, VELVET_D)
    c.rect(back_x + 2, y + 1, 1, h - 2, VELVET)
    # строчка-капитоне
    for yy in range(y + 8, y + h - 4, 9):
        c.set(seat_x + (w - 7) // 2, yy, VELVET_D)
        c.set(back_x + 3, yy + 4, shade(VELVET_D, -0.3))
    # деревянная рамка снизу
    c.rect(x, y + h - 2, w, 2, WOOD_D)
    c.rect(x, y + h, w, 2, shade(WOOD_D, -0.4))


def table_top(c, x, y, w, h, cloth=False):
    c.brect(x + 3, y + h, w - 1, 5, (20, 10, 34, 90))  # тень
    if cloth:
        c.rrect(x, y, w, h, 2, "#f0ece4")
        c.rect(x, y + h - 4, w, 4, "#d8d0dc")
        for xx in range(x + 2, x + w - 2, 4):
            c.set(xx, y + h - 1, "#b8b0c8")
        c.rect(x + 1, y + 1, w - 2, 1, "#ffffff")
    else:
        c.rrect(x, y, w, h, 2, WOOD)
        c.rect(x, y + h - 3, w, 3, WOOD_D)
        c.rect(x + 1, y + 1, w - 2, 1, WOOD_L)
        for yy in range(y + 4, y + h - 4, 4):
            c.hline(x + 2, x + w - 3, yy, shade(WOOD, -0.08))


def partition(c, x, y0, y1, w=6):
    """Перегородка между отсеками: верхний торец + видимая южная грань."""
    c.rect(x, y0, w, y1 - y0, WOOD_D)
    c.rect(x + 1, y0, w - 2, y1 - y0 - 6, shade(WOOD, -0.1))
    c.rect(x + 1, y0, 1, y1 - y0 - 6, WOOD_L)
    c.rect(x, y1 - 6, w, 6, shade(WOOD_D, -0.25))
    c.rect(x, y1 - 6, w, 1, GOLD)


def teacup(c, x, y):
    c.ellipse(x, y, 3, 2, "#ffffff")
    c.ellipse(x, y, 1.6, 1, "#a0602a")
    c.set(x + 3, y, "#ffffff")


def table_items(c, x, y, rng, rich=False):
    teacup(c, x + 6, y + 6)
    if rng.random() < 0.7:
        teacup(c, x + 20, y + 14)
    if rich:
        # лампа с абажуром
        c.ellipse(x + 15, y + 8, 5, 4, "#f2c14e")
        c.ellipse(x + 15, y + 7, 3, 2, "#ffe8a8")
        c.rect(x + 14, y + 12, 3, 2, GOLD)
    else:
        c.rect(x + 12, y + 4, 8, 6, "#f4ead8")
        c.hline(x + 13, x + 18, y + 6, "#a8a0b8")
        c.hline(x + 13, x + 17, y + 8, "#a8a0b8")


def make_story_props():
    """Предметы новых вагонов: ящики, мешки почты, клетка, длинный чёрный ящик."""
    c = Canvas(28, 26)
    c.rect(1, 6, 26, 19, "#9a7448")
    c.rect(1, 4, 26, 4, "#b48a58")
    for x in (1, 13, 26):
        c.vline(x, 4, 24, "#6a4c2c")
    c.line(2, 8, 25, 23, "#7a5a36")
    c.rect(8, 12, 10, 5, "#d8c49a")
    c.hline(9, 16, 14, "#6a4c2c")
    prop_sprite("crate", c.outline())
    c = Canvas(30, 40)
    for i, (x, y, w, h) in enumerate(((1, 18, 28, 21), (4, 2, 22, 17))):
        col = "#8a6840" if i == 0 else "#a07c4c"
        c.rect(x, y, w, h, col)
        c.rect(x, y, w, 3, shade(col, 0.15))
        c.vline(x, y, y + h - 1, shade(col, -0.35))
        c.vline(x + w - 1, y, y + h - 1, shade(col, -0.35))
        c.line(x + 1, y + 4, x + w - 2, y + h - 2, shade(col, -0.2))
    c.rect(9, 24, 12, 5, "#d8c49a")
    prop_sprite("crate_stack", c.outline())
    c = Canvas(22, 20)
    c.ellipse(11, 12, 10, 7, "#8a8466")
    c.ellipse(11, 10, 9, 6, "#a8a07c")
    c.rect(8, 2, 6, 5, "#a8a07c")
    c.rect(7, 6, 8, 2, "#6a4c2c")
    c.rect(6, 12, 9, 4, "#e8dcc0")
    c.hline(7, 13, 13, "#c0394b")
    prop_sprite("mail_sack", c.outline())
    c = Canvas(34, 34)
    c.rect(1, 30, 32, 3, "#3a3a44")
    c.rect(1, 2, 32, 2, "#5a5a68")
    for x in range(1, 34, 5):
        c.vline(x, 2, 31, "#7a7a8c")
    c.rect(1, 16, 32, 1, "#5a5a68")
    c.rect(14, 18, 6, 5, "#d9a441")
    c.set(17, 20, "#222222")
    for x, y in ((8, 27), (12, 28), (20, 27), (24, 28)):
        c.set(x, y, "#c8c0b0")
    prop_sprite("cage", c.outline())
    c = Canvas(18, 46)
    c.poly([(4, 1), (13, 1), (17, 10), (14, 45), (3, 45), (0, 10)], "#2a1e26")
    c.poly([(5, 3), (12, 3), (15, 10), (12, 43), (5, 43), (2, 10)], "#3e2a36")
    c.vline(8, 8, 30, "#8a6a3c")
    c.hline(5, 12, 14, "#8a6a3c")
    for y in (6, 40):
        c.hline(4, 13, y, "#6a5040")
    prop_sprite("coffin", c.outline())
    c = Canvas(30, 22)
    c.rect(1, 6, 28, 12, "#6a4c2c")
    c.rect(1, 4, 28, 3, "#8a6840")
    c.rect(3, 18, 3, 4, "#4a3420")
    c.rect(24, 18, 3, 4, "#4a3420")
    c.rect(5, 1, 9, 5, "#efe6c8")
    c.rect(17, 2, 8, 4, "#d8c49a")
    c.ellipse(24, 3, 3, 2, "#ffd27a")
    prop_sprite("mail_desk", c.outline())


# --- спрайты-предметы (сортировка по Y) --------------------------------------------------
PROPS = {}


def prop_sprite(name, c):
    PROPS[name] = c


def make_props():
    # растение в кадке
    c = Canvas(20, 30)
    c.rrect(5, 20, 10, 9, 2, "#8a4a2a")
    c.rect(5, 20, 10, 2, "#b0663a")
    c.rect(6, 27, 8, 2, "#6a341e")
    leaves = [(10, 10, 7, 6, "#2f7a4a"), (5, 13, 5, 4, "#2a6a42"), (15, 13, 5, 4, "#2a6a42"),
              (10, 6, 4, 4, "#3f9a5a"), (7, 16, 4, 3, "#3f9a5a"), (13, 17, 4, 3, "#2f7a4a")]
    for x, y, rx, ry, col in leaves:
        c.ellipse(x, y, rx, ry, col)
    for x, y in ((8, 7), (12, 9), (5, 12), (15, 12), (10, 14)):
        c.set(x, y, "#7ad28a")
    prop_sprite("plant", c.outline())

    # стеллаж для багажа с чемоданами и шляпными коробками
    c = Canvas(76, 40)
    c.rect(0, 6, 76, 30, "#4a2c1e")
    c.rect(2, 8, 72, 26, "#6b3f2c")
    for y in (8, 20):
        c.rect(2, y + 10, 72, 2, WOOD_L)
    bags = [(4, 9, 16, 10, "#7a3a8a"), (22, 11, 12, 8, "#2f6b8a"), (37, 10, 14, 9, "#a0602a"),
            (54, 9, 16, 10, "#3f8a5a"), (6, 23, 18, 9, "#b23a52"), (27, 24, 10, 8, "#d9a441"),
            (40, 22, 14, 10, "#5a4a7a"), (57, 24, 12, 8, "#8a5a3c")]
    for x, y, w, h, col in bags:
        c.rrect(x, y, w, h, 2, col)
        c.rect(x + 1, y + 1, w - 2, 1, shade(col, 0.3))
        c.rect(x + w // 2 - 2, y - 1, 4, 1, shade(col, -0.4))
        c.set(x + 2, y + h // 2, GOLD)
    c.rect(0, 36, 76, 4, "#2a1a14")
    prop_sprite("luggage_rack", c.outline())

    # пианино (вид сверху 3/4)
    c = Canvas(48, 32)
    c.rect(0, 0, 48, 22, "#2a1a24")
    c.rect(1, 1, 46, 3, "#4a2c3e")
    c.rect(2, 4, 44, 14, "#3a2230")
    for x in range(6, 42, 8):
        c.rect(x, 6, 4, 9, "#4a2c3e")
    c.rect(0, 18, 48, 8, "#1e1218")
    for x in range(2, 46, 3):
        c.rect(x, 20, 2, 5, "#f4f0e8")
    for x in range(4, 44, 6):
        c.rect(x, 20, 1, 3, "#14101a")
        c.rect(x + 3, 20, 1, 3, "#14101a")
    c.rect(0, 26, 48, 4, "#2a1a24")
    c.rect(4, 0, 6, 2, GOLD)
    c.rect(38, 0, 6, 2, GOLD)
    prop_sprite("piano", c.outline())

    # кофейный автомат с принтером чеков
    c = Canvas(26, 40)
    c.rrect(0, 0, 26, 36, 3, "#3a4a6b")
    c.rect(2, 2, 22, 10, "#1a2236")
    c.rect(4, 4, 18, 6, "#2fd6c6")
    c.rect(5, 5, 6, 1, "#c8fff8")
    c.rect(4, 14, 8, 8, "#b0b8c8")
    c.rect(6, 16, 4, 4, "#5a3020")
    c.rect(14, 14, 8, 3, "#d9a441")
    c.rect(14, 19, 8, 2, "#f4f0e8")  # щель чека
    c.rect(15, 21, 6, 4, "#ffffff")
    c.rect(2, 26, 22, 8, "#2a3450")
    c.set(20, 28, "#ff5a6a")
    c.set(20, 30, "#5aff8a")
    c.rect(0, 36, 26, 4, "#1a1e2c")
    prop_sprite("coffee_machine", c.outline())

    # мусорная корзина
    c = Canvas(14, 16)
    c.rrect(1, 3, 12, 12, 2, "#5a6478")
    c.rect(1, 3, 12, 2, "#8a94a8")
    c.ellipse(7, 4, 5, 1.5, "#2a2a3a")
    c.rect(3, 2, 4, 2, "#f4ead8")
    c.set(8, 1, "#f4ead8")
    for x in (3, 7, 11):
        c.vline(x, 6, 13, "#4a5266")
    prop_sprite("trash_bin", c.outline())

    # барная стойка (горизонтальная)
    c = Canvas(78, 26)
    c.rect(0, 0, 78, 10, WOOD_L)
    c.rect(0, 0, 78, 2, "#c8905e")
    c.rect(0, 8, 78, 2, GOLD)
    c.rect(0, 10, 78, 14, "#5a3426")
    for x in range(4, 78, 12):
        c.rect(x, 12, 8, 9, "#6b3f2c")
        c.rect(x, 12, 8, 1, "#8a5a3c")
    c.rect(0, 24, 78, 2, "#2a1a14")
    teacup(c, 12, 4)
    teacup(c, 50, 5)
    c.rect(28, 2, 10, 5, "#c8d8e8")  # поднос
    prop_sprite("bar_counter", c.outline())

    # барный табурет
    c = Canvas(12, 14)
    c.ellipse(6, 4, 5, 3.5, VELVET)
    c.ellipse(6, 3.5, 3, 2, VELVET_L)
    c.rect(5, 7, 2, 5, GOLD)
    c.rect(2, 12, 8, 2, "#5a3426")
    prop_sprite("stool", c.outline())

    # круглый столик у южной стены
    c = Canvas(24, 20)
    c.ellipse(12, 7, 11, 6, "#f0ece4")
    c.ellipse(12, 6, 9, 4.5, "#ffffff")
    c.rect(10, 12, 4, 6, "#5a3426")
    c.rect(6, 17, 12, 2, "#3a2218")
    teacup(c, 8, 6)
    c.rect(14, 4, 5, 3, "#d9a441")
    prop_sprite("round_table", c.outline())

    # стул
    c = Canvas(12, 16)
    c.rect(1, 0, 10, 5, "#6b3f2c")
    c.rect(2, 1, 8, 2, "#8a5a3c")
    c.rect(1, 5, 10, 6, VELVET)
    c.rect(2, 6, 8, 1, VELVET_L)
    c.rect(1, 11, 2, 4, "#4a2c1e")
    c.rect(9, 11, 2, 4, "#4a2c1e")
    prop_sprite("chair", c.outline())

    # пульт камер (монитор на столе)
    c = Canvas(20, 18)
    c.rrect(0, 0, 20, 14, 2, "#2a3048")
    c.rect(2, 2, 16, 9, "#0e2a2e")
    for y in range(3, 10, 2):
        c.hline(3, 16, y, "#1a5a5a")
    c.rect(3, 3, 7, 4, "#2fd6c6")
    c.rect(11, 6, 5, 3, "#7a5ad6")
    c.rect(7, 14, 6, 3, "#1a1e2c")
    c.set(17, 12, "#ff5a6a")
    prop_sprite("monitor", c.outline())

    # журнал вагона на столе
    c = Canvas(16, 12)
    c.rect(0, 1, 16, 10, "#7a2236")
    c.rect(1, 1, 7, 9, "#f4ead8")
    c.rect(8, 1, 7, 9, "#ece0c8")
    for y in (3, 5, 7):
        c.hline(2, 6, y, "#8a8aa8")
        c.hline(9, 13, y, "#8a8aa8")
    c.vline(8, 1, 10, "#5a1a2a")
    c.set(14, 2, "#e8d8b8")
    c.set(13, 9, "#c8b898")  # оборванный край
    prop_sprite("register", c.outline())

    # самовар на полке
    c = Canvas(14, 20)
    c.rect(5, 0, 4, 3, "#e0b64a")
    c.rrect(2, 3, 10, 12, 3, "#d9a441")
    c.rect(3, 5, 2, 7, "#ffe08a")
    c.rect(0, 9, 3, 2, "#b07a2a")
    c.rect(3, 15, 8, 3, "#b07a2a")
    c.rect(2, 18, 10, 2, "#8a5a2a")
    prop_sprite("samovar", c.outline())

    # чемоданы (варианты для слотов багажа)
    cases = {
        "suitcase_brown": ("#8a5a3c", 16, 12), "suitcase_red": ("#b23a52", 16, 12),
        "suitcase_teal": ("#2f8a8a", 14, 11), "suitcase_purple": ("#6b3f8a", 16, 12),
        "briefcase": ("#5a3a24", 14, 10), "hatbox": ("#2c2440", 13, 12),
        "toolbox": ("#c96a2b", 16, 10), "violin_case": ("#5a2e24", 10, 18),
        "bindle": ("#8c7a5a", 13, 11), "camera_bag": ("#e8b13e", 12, 10),
        "book_stack": ("#3f6b8a", 12, 10),
    }
    for name, (col, w, h) in cases.items():
        c = Canvas(w + 2, h + 4)
        if name == "hatbox":
            c.ellipse(w / 2 + 1, h / 2 + 2, w / 2, h / 2, col)
            c.ellipse(w / 2 + 1, h / 2, w / 2, h / 2 - 2, shade(col, 0.2))
            c.rect(2, h // 2, w - 2, 1, "#9b4fd6")
        elif name == "violin_case":
            c.rrect(1, 2, w, h, 4, col)
            c.rrect(3, 4, w - 4, 6, 2, shade(col, 0.15))
            c.rect(4, 12, w - 6, 5, shade(col, 0.15))
        elif name == "bindle":
            c.ellipse(w / 2 + 1, h / 2 + 2, w / 2, h / 2, col)
            c.rect(w // 2, 0, 2, 4, "#5a4a34")
            c.set(w // 2 - 1, h // 2 + 2, shade(col, -0.3))
        elif name == "book_stack":
            for i, bc in enumerate(("#3f6b8a", "#8a3a4a", "#3f8a5a")):
                c.rect(1 + i, 2 + i * 4, w - 2, 4, bc)
                c.rect(1 + i, 2 + i * 4, w - 2, 1, shade(bc, 0.3))
        else:
            c.rrect(1, 3, w, h, 2, col)
            c.rect(2, 4, w - 2, 1, shade(col, 0.3))
            c.rect(1, 3 + h - 3, w, 2, shade(col, -0.3))
            c.rect(w // 2 - 2, 1, 5, 2, shade(col, -0.45))
            if name in ("briefcase",):
                c.set(3, 6, GOLD_L)
                c.set(w - 2, 6, GOLD_L)
                c.rect(3, 5, 1, 1, GOLD)
            else:
                c.rect(1, 3 + h // 2, w, 1, shade(col, -0.25))
                c.set(3, 3 + h // 2, GOLD)
                c.set(w - 2, 3 + h // 2, GOLD)
            if name == "toolbox":
                c.rect(4, 2, w - 6, 1, "#9aa4b4")
        prop_sprite(name, c.outline())

    # стремянка (тамбур)
    c = Canvas(16, 30)
    c.rect(2, 0, 2, 30, "#9aa4b4")
    c.rect(12, 0, 2, 30, "#9aa4b4")
    for y in range(4, 30, 6):
        c.rect(2, y, 12, 2, "#c8d0dc")
    prop_sprite("ladder", c.outline())

    # огнетушитель
    c = Canvas(8, 16)
    c.rrect(1, 3, 6, 12, 2, "#d0303a")
    c.rect(2, 4, 1, 9, "#ff6a6a")
    c.rect(2, 0, 4, 3, "#2a2a2a")
    prop_sprite("extinguisher", c.outline())

    # зеркало на стене (сам по себе спрайт, чтобы в будущем рисовать «неправильное отражение»)
    c = Canvas(22, 30)
    c.rrect(0, 0, 22, 30, 8, GOLD)
    c.rrect(2, 2, 18, 26, 7, "#8fb8d8")
    c.rrect(3, 3, 16, 24, 6, "#a8d0e8")
    for i in range(10):
        c.set(5 + i // 2, 18 - i, "#e8f8ff")
    prop_sprite("mirror", c)

    # камера наблюдения (на стене)
    c = Canvas(14, 10)
    c.rect(0, 0, 3, 4, "#2a2a3a")
    c.rrect(2, 2, 11, 6, 2, "#d8dce8")
    c.rect(10, 3, 3, 4, "#2a2a3a")
    c.set(11, 4, "#5ad6ff")
    c.set(4, 3, "#ff3a4a")
    prop_sprite("cctv", c.outline())

    # дверь вагона: кадры открытия (панель уезжает вниз в карман)
    for i in range(4):
        c = Canvas(12, 52)
        c.rect(0, 0, 12, 52, "#2a2640")
        c.rect(1, 1, 10, 50, "#14121e")
        shift = int(i * 46 / 3)
        if i < 3:
            c.rect(2, 2 + shift, 8, 48 - shift, "#6b3f2c")
            c.rect(3, 4 + shift, 6, max(0, 18 - shift), "#6a8ab8")
            c.rect(3, 4 + shift, 6, 1 if shift < 18 else 0, "#b8d8f8")
            c.rect(2, 2 + shift, 8, 1, WOOD_L)
            c.rect(8, 26 + shift // 2, 1, 4, GOLD)
        c.rect(0, 0, 12, 2, GOLD)
        c.rect(0, 50, 12, 2, GOLD)
        prop_sprite(f"door_{i}", c)

    # лампочка-индикатор замка
    c = Canvas(4, 4)
    c.rect(0, 0, 4, 4, "#ff3a4a")
    c.rect(1, 1, 1, 1, "#ffb0b8")
    prop_sprite("lock_led", c)

    # свечение: лампа и окно (аддитивные)
    prop_sprite("glow_lamp", soft_glow(48, "#ffcf7a", 1.6, 190))
    prop_sprite("glow_small", soft_glow(24, "#ffe0a0", 1.8, 200))
    prop_sprite("glow_cyan", soft_glow(32, "#7ae8ff", 1.8, 180))
    # пятно света из окна на полу (трапеция)
    c = Canvas(64, 48)
    for y in range(48):
        t = y / 47
        half = 22 + 10 * t
        a = int(110 * (1 - t) ** 1.3)
        for x in range(64):
            d = abs(x + 0.5 - 32)
            if d < half:
                edge = min(1.0, (half - d) / 6)
                c.px[y][x] = (150, 190, 255, int(a * edge))
    prop_sprite("window_light", c)


# --- вагоны ------------------------------------------------------------------------------
def passenger():
    W = 656
    L = Layout("passenger", "Пассажирский вагон", W)
    c = Canvas(W, H)
    rng = noise_rng(11)
    wall_face(c, 0, W, "#4a3264", "#5c3e7c", "dots", seed=2)
    wood_floor(c, 8, FACE_BOTTOM, W - 8, FLOOR_BOTTOM, seed=4)
    carpet_runner(c, 8, 146, W - 8, 186)
    # тень от стены на пол
    for i in range(6):
        c.brect(8, FACE_BOTTOM + i, W - 16, 1, (20, 10, 40, 90 - i * 15))
    bottom_wall(c, W, range(40, W - 40, 72))
    L.col(0, 0, W, 60)          # стена с окнами
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)

    # --- служебное купе (x 8..104)
    window(c, 30, 16, 40, 22, curtain="#2f4377")
    table_top(c, 18, 58, 62, 26)
    L.col(18, 58, 62, 26)
    L.prop("monitor", 30, 74)
    L.prop("samovar", 92, 76, collider=[84, 64, 16, 12])
    # шкафчик с ключами на стене
    c.rect(80, 14, 20, 24, "#4a2c1e")
    c.rect(81, 15, 18, 22, "#6b3f2c")
    for ky in (19, 25, 31):
        for kx in (84, 89, 94):
            c.set(kx, ky, GOLD)
            c.set(kx, ky + 1, "#9aa4b4")
    # перегородка служебного купе с табличкой
    partition(c, 104, FACE_BOTTOM, 128)
    L.col(104, FACE_BOTTOM, 6, 72)
    c.rect(96, 112, 8, 6, "#2f4377")
    c.rect(97, 113, 6, 4, GOLD)
    L.spot("svc_desk", 50, 102, "up", "sit")
    L.spot("svc_register", 62, 98, "up")
    L.spot("svc_shelf", 88, 100, "up")
    L.spot("svc_door", 64, 166, "right")
    L.inter("obj_register", 54, 70, "Осмотреть журнал", "register", radius=34)
    L.inter("obj_monitor", 34, 70, "Камеры", None, radius=30)
    L.d["lamps"].append([56, 12])
    sconce(c, 20, 22)
    L.d["window_lights"].append([50, 60])

    # --- 4 отсека-купе
    bays = []
    for k in range(4):
        x0 = 110 + 112 * k
        bays.append(x0)
        window(c, x0 + 30, 16, 46, 22)
        bench_vertical(c, x0 + 2, 60, 22, 64, "right")
        bench_vertical(c, x0 + 82, 60, 22, 64, "left")
        table_top(c, x0 + 38, 58, 30, 28)
        table_items(c, x0 + 38, 58, rng)
        L.col(x0 + 2, 60, 22, 64)
        L.col(x0 + 82, 60, 22, 64)
        L.col(x0 + 38, 58, 30, 28)
        n = k + 1
        L.spot(f"bay{n}_l1", x0 + 14, 86, "right", "sit", via=x0 + 32)
        L.spot(f"bay{n}_l2", x0 + 14, 114, "right", "sit", via=x0 + 32)
        L.spot(f"bay{n}_r1", x0 + 92, 86, "left", "sit", via=x0 + 74)
        L.spot(f"bay{n}_r2", x0 + 92, 114, "left", "sit", via=x0 + 74)
        L.spot(f"bay{n}_w", x0 + 53, 104, "up")
        L.spot(f"bay{n}_c", x0 + 53, CORRIDOR_Y, "up")
        L.spot(f"corr_win{n}", x0 + 53, 184, "down")
        L.d["luggage_slots"][f"bay{n}_left"] = [x0 + 31, 82]
        L.d["luggage_slots"][f"bay{n}_right"] = [x0 + 75, 82]
        L.d["window_lights"].append([x0 + 53, 60])
        if k < 3:
            partition(c, x0 + 106, FACE_BOTTOM, 128)
            L.col(x0 + 106, FACE_BOTTOM, 6, 72)
            L.d["lamps"].append([x0 + 109, 20])
            sconce(c, x0 + 109, 24)
        # номер места на перегородке
        c.rect(x0 + 50, 128, 6, 4, GOLD)
    partition(c, 552, FACE_BOTTOM, 128)
    L.col(552, FACE_BOTTOM, 6, 72)
    sconce(c, 555, 24)
    L.d["lamps"].append([555, 20])
    L.d["bays"] = bays

    # --- торец: стеллаж для багажа и зеркало
    L.prop("luggage_rack", 600, 92, collider=[562, 60, 76, 30])
    L.prop("mirror", 611, 30)
    L.spot("end_rack", 586, 104, "up")
    L.spot("end_mirror", 612, 104, "up")
    L.spot("end_corner", 634, 120, "left")
    L.d["luggage_slots"]["end_floor"] = [618, 134]
    L.inter("obj_rack", 600, 88, "Осмотреть стеллаж", None, radius=30)

    # растения в коридоре
    L.prop("plant", 162, 190, collider=[156, 182, 12, 8])
    L.prop("plant", 498, 190, collider=[492, 182, 12, 8])

    end_walls(c, W, L, left_locked=True)
    L.prop("cctv", 540, 12)
    L.prop("cctv", 96, 50)
    L.d["cameras"].append({"id": "cam1", "name": "Пассажирский вагон", "rect": [100, 40, 556, 168]})
    L.d["cameras"].append({"id": "cam2", "name": "Служебное купе", "rect": [0, 40, 150, 168]})
    c.save("train/passenger_bg.png")
    L.save()


def vestibule():
    W = 64
    L = Layout("vestibule", "Тамбур", W)
    c = Canvas(W, H)
    # металлическая стена с круглым окном
    c.rect(0, 0, W, CAP, "#232038")
    c.rect(0, CAP, W, FACE_BOTTOM - CAP, "#3e465c")
    for x in range(0, W, 16):
        c.rect(x, CAP, 1, FACE_BOTTOM - CAP, "#2e3448")
        for y in range(CAP + 4, FACE_BOTTOM, 8):
            c.set(x + 3, y, "#6a7490")
    c.ellipse(32, 28, 11, 11, "#2a2a3a")
    c.ellipse(32, 28, 10, 10, "#9aa4b4")
    for yy in range(18, 39):
        for xx in range(22, 43):
            if math.hypot(xx + 0.5 - 32, yy + 0.5 - 28) < 8.6:
                c.set(xx, yy, (0, 0, 0, 0))
    c.rect(0, FACE_BOTTOM - 4, W, 4, "#2a2e40")
    # рифлёный пол
    c.rect(0, FACE_BOTTOM, W, FLOOR_BOTTOM - FACE_BOTTOM, "#4a5266")
    for y in range(FACE_BOTTOM, FLOOR_BOTTOM, 6):
        for x in range((y // 6) % 2 * 3, W, 6):
            c.set(x, y + 2, "#6a7490")
            c.set(x + 1, y + 3, "#353c50")
    # переходные мостки и предупреждающие полосы у стыков
    for x0 in (0, W - 6):
        for y in range(FACE_BOTTOM, FLOOR_BOTTOM):
            for x in range(x0, x0 + 6):
                c.set(x, y, "#e8b13e" if ((x + y) // 4) % 2 else "#2a2a2a")
    c.rect(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM, "#2a2e40")
    c.rect(0, FLOOR_BOTTOM, W, 2, "#5a6478")
    # гармошка межвагонного перехода (над и под полом)
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)
    L.prop("extinguisher", 54, 54, collider=[50, 50, 8, 8])
    L.prop("ladder", 20, 150)
    L.spot("vest_mid", 32, 150, "up")
    L.spot("vest_window", 32, 76, "up")
    L.spot("vest_door", 50, 170, "right")
    L.spot("vest_side", 14, 120, "right")
    L.d["luggage_slots"]["vest_floor"] = [48, 96]
    L.d["lamps"].append([32, 12])
    L.d["window_lights"].append([32, 60])
    L.prop("cctv", 6, 14)
    L.d["cameras"].append({"id": "cam3", "name": "Тамбур", "rect": [-40, 40, 144, 168]})
    L.d["flicker_lamp"] = [32, 12]
    c.save("train/vestibule_bg.png")
    L.save()


def restaurant():
    W = 656
    L = Layout("restaurant", "Вагон-ресторан", W)
    c = Canvas(W, H)
    rng = noise_rng(21)
    wall_face(c, 0, W, "#1f5a52", "#174640", "damask", wain="#4a2c1e", seed=5)
    # паркет «ёлочкой»-шашкой
    for y in range(FACE_BOTTOM, FLOOR_BOTTOM):
        for x in range(8, W - 8):
            cell = ((x // 16) + (y // 16)) % 2
            base = "#8a5a3c" if cell else "#74482e"
            if cell:
                col = shade(base, 0.05) if (x + y) % 16 < 2 else base
            else:
                col = shade(base, -0.05) if (x - y) % 16 < 2 else base
            c.set(x, y, col)
    for i in range(6):
        c.brect(8, FACE_BOTTOM + i, W - 16, 1, (10, 20, 30, 90 - i * 15))
    carpet_runner(c, 8, 128, W - 8, 160, base="#4a2a6b", dark="#2e1a46", trim=GOLD, motif="circle")
    bottom_wall(c, W, range(60, W - 60, 96))
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)

    # пианино
    L.prop("piano", 40, 86, collider=[16, 58, 48, 26])
    L.spot("piano", 40, 104, "up", "sit")
    L.prop("stool", 40, 106)

    # кабинки-«боксы» у окон
    for k in range(4):
        x0 = 72 + 108 * k
        window(c, x0 + 28, 14, 48, 26, curtain="#7a2a4a", arched=True)
        bench_vertical(c, x0, 60, 18, 58, "right")
        bench_vertical(c, x0 + 86, 60, 18, 58, "left")
        table_top(c, x0 + 26, 58, 52, 36, cloth=True)
        table_items(c, x0 + 26, 58, rng, rich=True)
        L.col(x0, 60, 18, 58)
        L.col(x0 + 86, 60, 18, 58)
        L.col(x0 + 26, 58, 52, 36)
        n = k + 1
        L.spot(f"rb{n}_l1", x0 + 10, 84, "right", "sit", via=x0 + 22)
        L.spot(f"rb{n}_l2", x0 + 10, 110, "right", "sit", via=x0 + 22)
        L.spot(f"rb{n}_r1", x0 + 94, 84, "left", "sit", via=x0 + 82)
        L.spot(f"rb{n}_r2", x0 + 94, 110, "left", "sit", via=x0 + 82)
        L.d["lamps"].append([x0 + 41, 66])
        L.d["window_lights"].append([x0 + 52, 60])
        sconce(c, x0 + 106 if k < 3 else x0 + 108, 24)
        L.d["lamps"].append([x0 + 106, 20])

    # кофейный автомат, мусорная корзина, зеркало
    L.prop("coffee_machine", 520, 94, collider=[508, 60, 24, 32])
    L.spot("rest_coffee", 520, 108, "up")
    L.inter("obj_coffee", 520, 92, "Осмотреть автомат", None, radius=28)
    L.prop("trash_bin", 544, 104, collider=[538, 96, 12, 8])
    L.spot("rest_trash", 546, 118, "up")
    L.inter("obj_trash", 544, 100, "Осмотреть корзину", None, radius=24)
    L.prop("mirror", 546, 30)
    L.d["mirror_restaurant"] = [546, 30]

    # бар: полки с бутылками на стене, стойка, табуреты
    c.rect(566, 12, 80, 28, "#3a2218")
    for sy in (20, 32):
        c.rect(566, sy + 4, 80, 2, GOLD)
        for bx in range(570, 644, 6):
            colr = rng.choice(("#2f8a6b", "#8a2f4a", "#d9a441", "#5a7ad6", "#e8e0f8"))
            c.rect(bx, sy - 3, 3, 7, colr)
            c.set(bx + 1, sy - 5, shade(colr, -0.3))
            c.set(bx, sy - 2, "#ffffff")
    L.prop("bar_counter", 609, 120, collider=[570, 96, 78, 22])
    L.spot("bar_back", 562, 88, "up")
    L.spot("bar_stool1", 590, 132, "up", "sit")
    L.spot("bar_stool2", 624, 132, "up", "sit")
    L.prop("stool", 590, 134)
    L.prop("stool", 624, 134)

    # южные столики
    for tx in (200, 420):
        L.prop("round_table", tx, 190, collider=[tx - 10, 176, 20, 12])
        L.prop("chair", tx - 18, 190)
        L.prop("chair", tx + 18, 190)
    L.spot("rest_s1_l", 182, 188, "right", "sit")
    L.spot("rest_s1_r", 218, 188, "left", "sit")
    L.spot("rest_s2_l", 402, 188, "right", "sit")
    L.spot("rest_s2_r", 438, 188, "left", "sit")
    L.spot("rest_window", 310, 184, "down")
    L.spot("rest_aisle", 300, CORRIDOR_Y, "up")
    L.prop("plant", 70, 190, collider=[64, 182, 12, 8])
    L.prop("plant", 540, 190, collider=[534, 182, 12, 8])

    end_walls(c, W, L, right_locked=True)
    L.prop("cctv", 20, 12)
    L.d["cameras"].append({"id": "cam4", "name": "Вагон-ресторан", "rect": [0, 40, 656, 168]})
    c.save("train/restaurant_bg.png")
    L.save()


def berth(c, x, y, w, h, blanket, pillow_top=True):
    """Полка спального купе: матрас, одеяло, подушка."""
    c.brect(x + 3, y + 4, w, h + 2, (24, 10, 34, 70))
    c.rrect(x, y, w, h, 3, WOOD_D)
    c.rrect(x + 2, y + 2, w - 4, h - 4, 2, "#e8e0d0")
    py = y + 4 if pillow_top else y + h - 14
    c.rrect(x + 4, py, w - 8, 10, 3, "#ffffff")
    c.rect(x + 5, py + 7, w - 10, 2, "#d8d0dc")
    by0 = y + 16 if pillow_top else y + 3
    c.rrect(x + 2, by0, w - 4, h - 20, 2, blanket)
    for yy in range(by0 + 3, by0 + h - 22, 6):
        c.hline(x + 3, x + w - 4, yy, shade(blanket, -0.2))
    c.rect(x + 2, by0, w - 4, 2, shade(blanket, 0.2))


def sleeper():
    W = 656
    L = Layout("sleeper", "Спальный вагон", W)
    c = Canvas(W, H)
    rng = noise_rng(31)
    wall_face(c, 0, W, "#2a3a5e", "#34477a", "stripes", wain="#4a2c1e", seed=7)
    wood_floor(c, 8, FACE_BOTTOM, W - 8, FLOOR_BOTTOM, base="#6e4a34", seed=9)
    carpet_runner(c, 8, 146, W - 8, 186, base="#2f5a4a", dark="#1e3e32", trim=GOLD, motif="diamond")
    for i in range(6):
        c.brect(8, FACE_BOTTOM + i, W - 16, 1, (20, 10, 40, 90 - i * 15))
    bottom_wall(c, W, range(40, W - 40, 72))
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)

    # --- купе проводника
    window(c, 30, 16, 40, 22, curtain="#2f4377")
    table_top(c, 18, 58, 62, 26)
    L.col(18, 58, 62, 26)
    L.prop("samovar", 92, 76, collider=[84, 64, 16, 12])
    partition(c, 104, FACE_BOTTOM, 128)
    L.col(104, FACE_BOTTOM, 6, 72)
    L.spot("sl_svc_desk", 50, 102, "up", "sit")
    L.spot("sl_svc_shelf", 88, 100, "up")
    L.spot("sl_svc_door", 64, 166, "right")
    L.inter("obj_sl_journal", 54, 70, "Журнал спального вагона", "register", radius=34)
    L.d["lamps"].append([56, 12])
    sconce(c, 20, 22)
    L.d["window_lights"].append([50, 60])

    # --- 4 закрытых купе: две полки, столик у окна, дверь в коридор
    blankets = ("#7a2a4a", "#2f4377", "#2f6a4a", "#6b2f7a")
    for k in range(4):
        x0 = 110 + 112 * k
        n = k + 1
        window(c, x0 + 30, 16, 46, 22, curtain="#2f4a6b")
        berth(c, x0 + 3, 62, 30, 60, blankets[k])
        berth(c, x0 + 73, 62, 30, 60, blankets[(k + 2) % 4])
        L.col(x0 + 3, 62, 30, 60)
        L.col(x0 + 73, 62, 30, 60)
        table_top(c, x0 + 40, 58, 26, 18)
        teacup(c, x0 + 47, 64)
        L.col(x0 + 40, 58, 26, 18)
        # передняя стенка купе с дверным проёмом (x0+44..x0+68)
        for (a, b) in ((x0, x0 + 44), (x0 + 68, x0 + 112 if k < 3 else x0 + 112)):
            c.rect(a, 124, b - a, 10, WOOD_D)
            c.rect(a, 124, b - a, 6, shade(WOOD, -0.1))
            c.rect(a, 124, b - a, 1, WOOD_L)
            c.rect(a, 133, b - a, 1, GOLD)
            L.col(a, 124, b - a, 10)
        # открытая дверь-купе (сдвинута за стенку) и номер
        c.rect(x0 + 70, 120, 22, 4, "#5e3a26")
        c.rect(x0 + 50, 126, 12, 5, GOLD)
        c.rect(x0 + 52, 127, 8, 3, "#2a1e26")
        c.set(x0 + 55, 128, GOLD_L)
        door = x0 + 56
        L.spot(f"sl{n}_b1", x0 + 18, 92, "right", "sit", via=door)
        L.spot(f"sl{n}_b2", x0 + 88, 92, "left", "sit", via=door)
        L.spot(f"sl{n}_w", x0 + 53, 96, "up", via=door)
        L.spot(f"sl{n}_in", x0 + 56, 112, "down", via=door)
        L.spot(f"sl{n}_door", door, CORRIDOR_Y, "up")
        L.spot(f"sl_corr{n}", x0 + 53, 184, "down")
        L.d["luggage_slots"][f"sl{n}_shelf"] = [x0 + 53, 108]
        L.d["window_lights"].append([x0 + 53, 60])
        L.d["lamps"].append([x0 + 53, 30])
        if k < 3:
            partition(c, x0 + 106, FACE_BOTTOM, 134)
            L.col(x0 + 106, FACE_BOTTOM, 6, 78)
        sconce(c, x0 + 18, 24)
    partition(c, 552, FACE_BOTTOM, 134)
    L.col(552, FACE_BOTTOM, 6, 78)

    # --- торец: умывальник, зеркало, расписание
    c.rect(570, 60, 40, 18, "#c8ccd8")
    c.ellipse(590, 68, 12, 6, "#e8ecf4")
    c.ellipse(590, 68, 8, 4, "#9aa4b4")
    L.col(570, 60, 40, 18)
    L.prop("mirror", 590, 30)
    c.rect(616, 18, 26, 30, "#efe6c8")
    for yy in range(22, 46, 4):
        c.hline(619, 639, yy, "#7a6a8a")
    L.spot("sl_basin", 590, 92, "up")
    L.spot("sl_end_corner", 632, 120, "left")
    L.inter("obj_sl_timetable", 628, 70, "Расписание поезда", None, radius=30)
    L.d["lamps"].append([600, 20])
    sconce(c, 600, 24)

    L.prop("plant", 120, 190, collider=[114, 182, 12, 8])
    end_walls(c, W, L, left_locked=True)
    L.prop("cctv", 540, 12)
    L.prop("cctv", 96, 50)
    L.d["cameras"].append({"id": "cam5", "name": "Коридор спального вагона", "rect": [100, 136, 556, 72]})
    L.d["cameras"].append({"id": "cam7", "name": "Купе проводника", "rect": [0, 40, 150, 168]})
    L.d["door_messages"] = {"left": "Дверь в локомотив заперта."}
    c.save("train/sleeper_bg.png")
    L.save()


def baggage():
    W = 656
    L = Layout("baggage", "Багажный вагон", W)
    c = Canvas(W, H)
    rng = noise_rng(41)
    # дощатые стены и грубый пол
    c.rect(0, CAP, W, FACE_BOTTOM - CAP, "#3e3a30")
    for x in range(0, W, 10):
        c.vline(x, CAP, FACE_BOTTOM - 1, "#2e2a22")
        c.vline(x + 1, CAP, FACE_BOTTOM - 1, "#4e4838")
    for y in (20, 38):
        c.rect(0, y, W, 2, "#5a4c34")
    c.rect(0, 0, W, CAP, "#232038")
    c.rect(0, CAP - 2, W, 2, "#3a3456")
    wood_floor(c, 8, FACE_BOTTOM, W - 8, FLOOR_BOTTOM, base="#5a4632", seed=13, plank_h=10)
    for i in range(6):
        c.brect(8, FACE_BOTTOM + i, W - 16, 1, (10, 8, 20, 110 - i * 18))
    # сдвижная грузовая дверь, солома, пятна, жёлтая разметка прохода
    c.rect(560, CAP + 2, 70, FACE_BOTTOM - CAP - 2, "#4a4436")
    c.frame(560, CAP + 2, 70, FACE_BOTTOM - CAP - 2, "#2a2620")
    c.hline(556, 634, CAP + 3, "#7a7a8c")
    c.rect(592, 30, 6, 3, "#9aa4b4")
    for _ in range(260):
        x, y = rng.randint(12, W - 12), rng.randint(FACE_BOTTOM + 4, FLOOR_BOTTOM - 4)
        c.set(x, y, rng.choice(("#c8a85a", "#b0904a", "#d8bc6a")))
        if rng.random() < 0.4:
            c.set(x + 1, y + (1 if rng.random() < 0.5 else -1), "#a8884a")
    for _ in range(7):
        c.ellipse(rng.randint(40, W - 40), rng.randint(130, 180), rng.uniform(6, 14), rng.uniform(3, 6), (30, 22, 18, 70), blend=True)
    for x in range(12, W - 12, 12):
        c.rect(x, 150, 6, 2, "#c8a038")
        c.rect(x, 182, 6, 2, "#c8a038")
    # маленькие зарешёченные окна
    for x in (90, 270, 450):
        window(c, x, 18, 26, 16, curtain="#3e3a30")
        for gx in range(x + 4, x + 26, 6):
            c.vline(gx, 18, 33, "#2a2a2a")
        L.d["window_lights"].append([x + 13, 60])
    bottom_wall(c, W, range(60, W - 60, 120), glass="#4a5a7a")
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)

    # почтовый стол
    L.prop("mail_desk", 40, 96, collider=[26, 76, 30, 20])
    L.spot("bg_desk", 40, 112, "up", "sit")
    L.inter("obj_bg_manifest", 40, 82, "Накладные", None, radius=30)
    L.prop("mail_sack", 76, 92, collider=[66, 82, 20, 12])
    L.prop("mail_sack", 92, 100)
    L.spot("bg_mail", 84, 118, "up")
    # штабеля ящиков
    for x, sprite in ((150, "crate_stack"), (186, "crate"), (232, "crate_stack"), (330, "crate"), (366, "crate_stack")):
        h = 40 if sprite == "crate_stack" else 26
        L.prop(sprite, x, 100, collider=[x - 14, 100 - h + 8, 28, h - 8])
    L.spot("bg_crates1", 168, 120, "up")
    L.spot("bg_crates2", 300, 112, "up")
    # клетка для животных
    L.prop("cage", 440, 104, collider=[424, 76, 34, 28])
    L.spot("bg_cage", 440, 124, "up")
    # длинный чёрный ящик на козлах
    c.rect(500, 96, 4, 10, "#3a2a1e")
    c.rect(540, 96, 4, 10, "#3a2a1e")
    L.prop("coffin", 522, 104, collider=[512, 62, 20, 42])
    L.spot("bg_coffin", 548, 112, "left")
    L.spot("bg_corner", 618, 110, "left")
    L.spot("bg_aisle", 300, CORRIDOR_Y, "up")
    L.spot("bg_door", 30, 166, "right")
    L.d["luggage_slots"]["bg_floor"] = [600, 140]
    for x in (120, 330, 560):
        L.d["lamps"].append([x, 14])
        c.rect(x - 1, 8, 2, 8, "#5a5a68")
        c.ellipse(x, 18, 4, 3, "#ffd27a")
    end_walls(c, W, L, right_locked=True)
    L.prop("cctv", 20, 12)
    L.d["cameras"].append({"id": "cam6", "name": "Багажный вагон", "rect": [0, 40, 656, 168]})
    L.d["door_messages"] = {"right": "Хвост поезда. Дальше — только рельсы."}
    c.save("train/baggage_bg.png")
    L.save()


def main():
    make_props()
    make_story_props()
    for name, img in PROPS.items():
        img.save(f"props/{name}.png")
    passenger()
    vestibule()
    restaurant()
    sleeper()
    baggage()


if __name__ == "__main__":
    main()
