#!/usr/bin/env python3
"""Вагоны-варианты для миссий кампании: у каждой миссии свой состав.

Вагон выполняет «роль» в составе и сохраняет точки маршрутов этой роли, поэтому авторские
расписания NPC продолжают работать, но планировка, мебель, предметы, освещение и объекты —
свои у каждого вагона:
  • роль «тамбур»    (точки vest_*, камера cam3)  — переходы между вагонами;
  • роль «ресторан»  (точки rb*, rest_*, bar_*, piano, камера cam4);
  • роль «пассажирский» (точки svc_*, bay*, corr_win*, end_*, камеры cam1/cam2);
  • самостоятельные вагоны (архив) — со своими точками.
У интерактивных объектов вагона есть описание по умолчанию ("object"), дело может его
переопределить.

Запуск:  python3 tools/gen_train_variants.py   (после tools/gen_train.py)
"""
import math

from pixelart import Canvas, noise_rng, shade
from gen_train import (H, CAP, FACE_BOTTOM, FLOOR_BOTTOM, CORRIDOR_Y, GOLD, GOLD_L, WOOD, WOOD_D, WOOD_L,
                       VELVET, VELVET_D, CARPET, CARPET_D, Layout, wood_floor, carpet_runner, wall_face,
                       window, sconce, end_walls, bottom_wall, bench_vertical, table_top, partition,
                       teacup, table_items)

PROPS = {}


def prop(name, c):
    PROPS[name] = c.outline()


def inter(L, iid, x, y, label, title, text, kind="item", radius=26, sprite=None):
    L.inter(iid, x, y, label, sprite, radius=radius)
    L.d["interactables"][-1]["object"] = {"title": title, "kind": kind, "text": text, "hotspots": []}


def tiles(c, x0, y0, x1, y1, a, b, size=8):
    for y in range(y0, y1):
        for x in range(x0, x1):
            c.set(x, y, a if ((x // size) + (y // size)) % 2 == 0 else b)


# =========================================================================================
# Роль «тамбур»
# =========================================================================================
def connector(cid, name, W, wall, wall_d, floor, floor_d, lamp_x=None):
    L = Layout(cid, name, W)
    L.d["role"] = "vestibule"
    c = Canvas(W, H)
    c.rect(0, 0, W, CAP, "#232038")
    c.rect(0, CAP, W, FACE_BOTTOM - CAP, wall)
    c.rect(0, FACE_BOTTOM - 4, W, 4, wall_d)
    c.rect(0, FACE_BOTTOM, W, FLOOR_BOTTOM - FACE_BOTTOM, floor)
    for y in range(FACE_BOTTOM, FLOOR_BOTTOM, 6):
        for x in range((y // 6) % 2 * 3, W, 6):
            c.set(x, y + 2, floor_d)
    for x0 in (0, W - 6):
        for y in range(FACE_BOTTOM, FLOOR_BOTTOM):
            for x in range(x0, x0 + 6):
                c.set(x, y, "#e8b13e" if ((x + y) // 4) % 2 else "#2a2a2a")
    c.rect(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM, "#2a2e40")
    c.rect(0, FLOOR_BOTTOM, W, 2, "#5a6478")
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)
    L.spot("vest_mid", W // 2, 150, "up")
    L.spot("vest_window", W // 2, 76, "up")
    L.spot("vest_door", W - 14, 170, "right")
    L.spot("vest_side", 14, 120, "right")
    L.d["luggage_slots"]["vest_floor"] = [W - 16, 96]
    lx = W // 2 if lamp_x is None else lamp_x
    L.d["lamps"].append([lx, 12])
    L.d["flicker_lamp"] = [lx, 12]
    L.d["window_lights"].append([W // 2, 60])
    L.prop("cctv", 6, 14)
    L.d["cameras"].append({"id": "cam3", "name": name, "rect": [-40, 40, W + 80, 168]})
    return L, c


def round_window(c, cx, cy, r):
    c.ellipse(cx, cy, r + 1, r + 1, "#2a2a3a")
    c.ellipse(cx, cy, r, r, "#9aa4b4")
    for yy in range(cy - r, cy + r + 1):
        for xx in range(cx - r, cx + r + 1):
            if math.hypot(xx + 0.5 - cx, yy + 0.5 - cy) < r - 1.4:
                c.set(xx, yy, (0, 0, 0, 0))


def v_service():
    """Служебный тамбур буфета (дело 2): кафель, ниша для тележки, окошко раздачи, пустой патрон."""
    W = 96
    L, c = connector("v_service", "Служебный тамбур буфета", W, "#cfe0c8", "#8aa080", "#c8c0a8", "#a89c80", lamp_x=48)
    for y in range(CAP, FACE_BOTTOM - 4, 6):
        for x in range(0, W, 6):
            c.set(x, y, "#9ab494")
            c.hline(x, x + 5, y, "#b4ccae")
    tiles(c, 6, FACE_BOTTOM, W - 6, FLOOR_BOTTOM, "#d8d0b8", "#a89c80", 8)
    # ниша для тележки с разметкой
    c.frame(8, 98, 30, 34, "#e8b13e")
    for i in range(0, 30, 6):
        c.line(8 + i, 131, 14 + i, 99, "#c8a038")
    # окошко раздачи с подносом
    c.rect(52, 18, 34, 24, "#5e3a26")
    c.rect(55, 21, 28, 18, "#2a1e1a")
    c.rect(55, 33, 28, 3, "#9aa4b4")
    c.rect(60, 30, 8, 3, "#efe6c8")
    # патрон без лампы (лампа выкручена) и полка с ящиками бутылок
    c.rect(46, 8, 4, 6, "#5a5a68")
    c.rect(10, 20, 30, 3, WOOD_D)
    for x in (12, 20, 28):
        c.rect(x, 12, 6, 8, "#5a8a5a")
        c.rect(x + 2, 10, 2, 2, "#2a4a2a")
    inter(L, "obj_v_hatch", 68, 70, "Окошко раздачи", "Окошко раздачи", "Через окошко из буфета подают подносы. Внутри пахнет морсом и ванилью.")
    c.save("train/v_service_bg.png")
    L.save()


def v_luggage():
    """Кладовая-переход (дело 4): стеллажи посылок, багажные весы, тележка-ручник."""
    W = 112
    L, c = connector("v_luggage", "Тамбур-кладовая", W, "#4e4636", "#2e2a22", "#6a5a40", "#4a3e2c")
    for x in range(0, W, 10):
        c.vline(x, CAP, FACE_BOTTOM - 5, "#3e382a")
    for sy in (16, 32):
        c.rect(4, sy + 8, W - 8, 2, WOOD_D)
        for bx in range(6, W - 12, 13):
            col = ("#b48a58", "#9a7448", "#c8a878")[(bx // 13 + sy) % 3]
            c.rect(bx, sy, 11, 8, col)
            c.hline(bx, bx + 10, sy + 3, shade(col, -0.25))
    # весы с площадкой
    c.rect(70, 84, 30, 18, "#5a5a68")
    c.rect(72, 86, 26, 14, "#7a7a8c")
    c.rect(82, 66, 6, 18, "#3a3a44")
    c.ellipse(85, 64, 7, 6, "#efe6c8")
    c.line(85, 64, 89, 60, "#c0394b")
    L.col(70, 60, 30, 42)
    inter(L, "obj_v_scale", 85, 100, "Багажные весы", "Багажные весы", "Площадка для взвешивания багажа. Стрелка на нуле.", kind="item", radius=28)
    c.save("train/v_luggage_bg.png")
    L.save()


def v_workshop():
    """Тамбур-мастерская (дело 5): верстак с тисками, стена инструментов, тормозной штурвал, две висячие лампы."""
    W = 128
    L, c = connector("v_workshop", "Тамбур-мастерская", W, "#46505e", "#2e3440", "#4a5266", "#353c50")
    # стена инструментов
    c.rect(8, 12, 48, 30, "#8a6a4a")
    for yy in range(14, 40, 5):
        for xx in range(10, 54, 5):
            c.set(xx, yy, "#5a4030")
    for x, h, col in ((14, 14, "#9aa4b4"), (22, 10, "#c0394b"), (30, 16, "#9aa4b4"), (40, 12, "#d9a441"), (48, 14, "#9aa4b4")):
        c.rect(x, 16, 2, h, col)
        c.rect(x - 1, 16, 4, 2, shade(col, -0.2))
    # верстак с тисками
    c.rect(8, 62, 50, 22, WOOD)
    c.rect(8, 62, 50, 4, WOOD_L)
    c.rect(44, 58, 10, 8, "#5a5a68")
    L.col(8, 58, 50, 26)
    # тормозной штурвал и кожух троса
    c.ellipse(96, 30, 12, 12, "#3a3a44")
    c.ellipse(96, 30, 9, 9, "#c0394b")
    c.ellipse(96, 30, 3, 3, "#3a3a44")
    for a in range(0, 360, 60):
        c.line(96, 30, 96 + int(9 * math.cos(math.radians(a))), 30 + int(9 * math.sin(math.radians(a))), "#3a3a44")
    c.rect(92, 42, 8, 14, "#5a5a68")
    c.rect(94, FACE_BOTTOM, 4, 50, "#2a2a2a")
    for x in (40, 96):
        c.rect(x, 4, 1, 6, "#5a5a68")
        c.ellipse(x, 11, 4, 3, "#ffd27a")
    L.d["lamps"] = [[40, 12], [96, 12]]
    inter(L, "obj_v_tools", 32, 70, "Стена инструментов", "Стена инструментов", "Ключи, отвёртки, кусачки — всё развешано по контурам. Хозяйство механика.", radius=30)
    c.save("train/v_workshop_bg.png")
    L.save()


def v_smoking():
    """Курительный тамбур (дело 6): кресла, пепельница на ножке, переговорная труба в служебку."""
    W = 112
    L, c = connector("v_smoking", "Курительный тамбур", W, "#5a2a3a", "#3a1a26", "#5e3a26", "#4a2c1e")
    for y in range(CAP + 4, 40, 8):
        for x in range((y // 8) % 2 * 6, W, 12):
            c.set(x, y, "#7a3a4e")
    c.rect(0, 40, W, FACE_BOTTOM - 44, WOOD_D)
    c.rect(0, 40, W, 2, GOLD)
    # переговорная труба: латунный раструб и труба вдоль стены
    c.rect(4, 22, W - 30, 3, "#b08a3a")
    c.ellipse(W - 22, 24, 7, 6, "#d9a441")
    c.ellipse(W - 22, 24, 4, 3, "#2a1e1a")
    c.rect(4, 22, 3, 30, "#b08a3a")
    inter(L, "obj_v_tube", W - 22, 68, "Переговорная труба", "Переговорная труба", "Латунная труба тянется вдоль вагонов к служебному купе. Скажешь сюда — услышат там.", radius=28)
    c.save("train/v_smoking_bg.png")
    L.prop("armchair", 26, 92, collider=[14, 70, 24, 22])
    L.prop("ashtray", 56, 96, collider=[52, 88, 8, 8])
    L.save()


def v_telegraph():
    """Тамбур с телеграфной будкой (дело 9): аппарат, провода под потолком, сигнальный колокол."""
    W = 112
    L, c = connector("v_telegraph", "Телеграфный тамбур", W, "#3e465c", "#2a2e40", "#4a5266", "#353c50")
    for y in (10, 14):
        c.hline(0, W - 1, y, "#1a1a22")
    # будка
    c.rect(56, 14, 50, 42, "#5e3a26")
    c.rect(60, 18, 42, 30, "#2a1e1a")
    c.rect(64, 22, 34, 4, "#efe6c8")
    c.rect(64, 30, 34, 3, "#efe6c8")
    c.rect(56, 14, 50, 3, GOLD)
    # колокол
    c.ellipse(20, 26, 7, 7, "#d9a441")
    c.ellipse(20, 31, 9, 3, "#b08a3a")
    c.rect(19, 12, 2, 8, "#5a5a68")
    L.prop("telegraph_desk", 80, 84, collider=[60, 62, 42, 22])
    inter(L, "obj_v_bell", 20, 72, "Сигнальный колокол", "Сигнальный колокол", "Колокол для сигналов машинисту. Язычок подвязан, чтобы не звенел зря.", radius=28)
    c.save("train/v_telegraph_bg.png")
    L.save()


def v_switch():
    """Старый тамбур 1926 года (дело 10): стрелочный рычаг, иней, табличка «Вагон 0»."""
    W = 96
    L, c = connector("v_switch", "Тамбур «Вагон 0»", W, "#3a3a46", "#24242e", "#55505a", "#3a3640")
    rng = noise_rng(61)
    for x in range(0, W, 8):
        c.vline(x, CAP, FACE_BOTTOM - 5, "#2c2c36")
    c.rect(30, 18, 36, 14, "#2a2a2a")
    c.rect(32, 20, 32, 10, "#c8c0b0")
    for i, ch in enumerate((1, 0, 1, 1, 0, 1)):
        c.rect(35 + i * 5, 23, 3, 4, "#3a3a3a" if ch else "#7a7a7a")
    # иней по углам и на полу
    for _ in range(160):
        x, y = rng.randint(0, W - 1), rng.randint(FACE_BOTTOM, FLOOR_BOTTOM - 1)
        if x < 22 or x > W - 22 or rng.random() < 0.15:
            c.blend(x, y, (220, 240, 255, 120))
    for x in range(4, W - 4, 7):
        c.vline(x, FACE_BOTTOM - 4, FACE_BOTTOM - 1 + (x % 3), "#dcecff")
    c.save("train/v_switch_bg.png")
    L.prop("switch_lever", 18, 104, collider=[12, 90, 14, 12])
    L.save()


def v_platform():
    """Открытая площадка (дело 11): снег, перила, фонарь, звёздное небо вместо стены."""
    W = 96
    L, c = connector("v_platform", "Открытая площадка", W, "#101a34", "#0a1024", "#8a96b0", "#6a7690", lamp_x=72)
    rng = noise_rng(71)
    for _ in range(40):
        c.set(rng.randint(0, W - 1), rng.randint(CAP, FACE_BOTTOM - 8), rng.choice(("#ffffff", "#c8d4ff")))
    c.rect(0, FACE_BOTTOM - 10, W, 3, "#4a4a5a")
    for x in range(2, W, 8):
        c.vline(x, FACE_BOTTOM - 10, FACE_BOTTOM - 1, "#4a4a5a")
    for _ in range(420):
        x, y = rng.randint(0, W - 1), rng.randint(FACE_BOTTOM, FLOOR_BOTTOM - 1)
        c.blend(x, y, (240, 246, 255, rng.randint(90, 200)))
    c.rect(70, 14, 4, 40, "#2a2a2a")
    c.ellipse(72, 12, 6, 5, "#ffd27a")
    inter(L, "obj_v_rail", 40, 70, "Перила", "Перила площадки", "Ледяные перила. Снег на них нетронут — кроме одного места, где лежала чья-то ладонь.", radius=28)
    c.save("train/v_platform_bg.png")
    L.save()


def v_mirror():
    """Тамбур с большим зеркалом (дело 12): гардеробная, вешалки, зеркало во весь рост."""
    W = 96
    L, c = connector("v_mirror", "Зеркальный тамбур", W, "#3a2a4a", "#24182e", "#5e4a5a", "#4a3a48")
    c.rect(32, 10, 32, 44, GOLD)
    c.rect(34, 12, 28, 40, "#9ab4cc")
    for i in range(6):
        c.blend(38 + i, 46 - i * 5, (255, 255, 255, 60))
    for x in (8, 16, 76, 84):
        c.rect(x, 16, 2, 6, "#b08a3a")
        c.rect(x - 2, 22, 6, 18, ("#4a3a6a", "#2a2a3a", "#6a2a3a", "#3a4a3a")[(x // 8) % 4])
    L.prop("mirror", 48, 30)
    inter(L, "obj_v_coats", 12, 70, "Вешалка", "Вешалка с пальто", "Пальто пассажиров спального вагона. Одно — тяжёлое, с бархатным воротником, пахнет сырой землёй.", radius=28)
    c.save("train/v_mirror_bg.png")
    L.save()


def v_moon():
    """Тамбур с большим круглым окном (дело 13): лунный свет на полу."""
    W = 96
    L, c = connector("v_moon", "Лунный тамбур", W, "#2e3448", "#1e2232", "#4a5266", "#353c50")
    round_window(c, 48, 30, 18)
    for y in range(FACE_BOTTOM, 150):
        for x in range(28, 68):
            if abs(x - 48) < 14 + (y - FACE_BOTTOM) // 6:
                c.blend(x, y, (210, 225, 255, 34))
    inter(L, "obj_v_window", 20, 72, "Круглое окно", "Круглое окно", "Сквозь окно видно небо. Когда поезд выходит из леса, лунный свет падает прямо на пол тамбура.", radius=28)
    c.save("train/v_moon_bg.png")
    L.save()


# =========================================================================================
# Роль «ресторан»
# =========================================================================================
def restaurant_skeleton(cid, name, wall, wall_d, pattern, wain, floor_a, floor_b, runner, runner_d, runner_trim):
    W = 656
    L = Layout(cid, name, W)
    L.d["role"] = "restaurant"
    c = Canvas(W, H)
    wall_face(c, 0, W, wall, wall_d, pattern, wain=wain, seed=9)
    for y in range(FACE_BOTTOM, FLOOR_BOTTOM):
        for x in range(8, W - 8):
            c.set(x, y, floor_a if ((x // 16) + (y // 16)) % 2 else floor_b)
    for i in range(6):
        c.brect(8, FACE_BOTTOM + i, W - 16, 1, (10, 20, 30, 90 - i * 15))
    carpet_runner(c, 8, 128, W - 8, 160, base=runner, dark=runner_d, trim=runner_trim, motif="circle")
    bottom_wall(c, W, range(60, W - 60, 96))
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)
    L.spot("piano", 40, 104, "up", "sit")
    for k in range(4):
        x0 = 72 + 108 * k
        n = k + 1
        L.spot(f"rb{n}_l1", x0 + 10, 84, "right", "sit", via=x0 + 22)
        L.spot(f"rb{n}_l2", x0 + 10, 110, "right", "sit", via=x0 + 22)
        L.spot(f"rb{n}_r1", x0 + 94, 84, "left", "sit", via=x0 + 82)
        L.spot(f"rb{n}_r2", x0 + 94, 110, "left", "sit", via=x0 + 82)
    L.spot("rest_coffee", 520, 108, "up")
    L.spot("rest_trash", 546, 118, "up")
    L.spot("bar_back", 562, 88, "up")
    L.spot("bar_stool1", 590, 132, "up", "sit")
    L.spot("bar_stool2", 624, 132, "up", "sit")
    L.spot("rest_s1_l", 182, 188, "right", "sit")
    L.spot("rest_s1_r", 218, 188, "left", "sit")
    L.spot("rest_s2_l", 402, 188, "right", "sit")
    L.spot("rest_s2_r", 438, 188, "left", "sit")
    L.spot("rest_window", 310, 184, "down")
    L.spot("rest_aisle", 300, CORRIDOR_Y, "up")
    end_walls(c, W, L, right_locked=True)
    L.prop("cctv", 20, 12)
    L.d["cameras"].append({"id": "cam4", "name": name, "rect": [0, 40, 656, 168]})
    return L, c


def low_table(c, x, y, w, h, top, rng, samovar=False):
    c.brect(x + 3, y + h, w - 1, 4, (20, 10, 34, 90))
    c.rrect(x, y, w, h, 4, top)
    c.rect(x + 2, y + 2, w - 4, 1, shade(top, 0.2))
    if samovar:
        c.ellipse(x + w // 2, y + h // 2 - 2, 6, 7, "#d9a441")
        c.ellipse(x + w // 2, y + h // 2 - 8, 3, 2, "#b08a3a")
        c.rect(x + w // 2 + 6, y + h // 2, 3, 2, "#b08a3a")
    teacup(c, x + 6, y + h - 6)
    teacup(c, x + w - 8, y + 6)


def cushion(c, x, y, w, h, col):
    c.brect(x + 2, y + 3, w, h, (24, 10, 34, 70))
    c.rrect(x, y, w, h, 4, col)
    c.rect(x + 2, y + 2, w - 4, 2, shade(col, 0.2))
    for yy in range(y + 6, y + h - 4, 8):
        c.set(x + w // 2, yy, shade(col, -0.3))


def r_tearoom():
    """Чайный вагон (дело 7): низкие столики с самоварами, подушки, полки с травами, граммофон."""
    L, c = restaurant_skeleton("r_tearoom", "Чайный вагон", "#7a3a1e", "#5a2a14", "damask", "#4a2c1e",
                               "#8a5a3c", "#74482e", "#3a2a5a", "#241a3e", GOLD)
    rng = noise_rng(81)
    for k in range(4):
        x0 = 72 + 108 * k
        window(c, x0 + 28, 14, 48, 26, curtain="#a85a2a")
        cushion(c, x0, 62, 18, 54, ("#a83a3a", "#3a6a8a", "#8a6a2a", "#5a3a8a")[k])
        cushion(c, x0 + 86, 62, 18, 54, ("#3a6a8a", "#8a6a2a", "#5a3a8a", "#a83a3a")[k])
        low_table(c, x0 + 28, 66, 48, 30, "#6a3a1e", rng, samovar=True)
        L.col(x0, 62, 18, 54)
        L.col(x0 + 86, 62, 18, 54)
        L.col(x0 + 28, 66, 48, 30)
        L.d["lamps"].append([x0 + 52, 20])
        L.d["window_lights"].append([x0 + 52, 60])
        sconce(c, x0 + 106 if k < 3 else x0 + 108, 24)
    # полки с банками трав за чайной стойкой
    for sy in (18, 32):
        c.rect(566, sy + 6, 80, 2, GOLD)
        for bx in range(570, 644, 8):
            c.rect(bx, sy - 2, 6, 8, "#cfe6f4")
            c.rect(bx + 1, sy + 1, 4, 4, rng.choice(("#7fd18a", "#c8a038", "#a85a2a", "#5a8a5a")))
            c.rect(bx, sy - 3, 6, 1, "#8a6a4a")
    L.prop("gramophone", 40, 88, collider=[24, 62, 32, 24])
    L.prop("big_samovar", 520, 94, collider=[508, 60, 24, 32])
    L.inter("obj_coffee", 520, 92, "Осмотреть самовар", None, radius=28)
    L.prop("tea_bucket", 544, 104, collider=[538, 96, 12, 8])
    L.inter("obj_trash", 544, 100, "Осмотреть ведро", None, radius=24)
    L.prop("tea_counter", 609, 120, collider=[570, 96, 78, 22])
    L.prop("stool", 590, 134)
    L.prop("stool", 624, 134)
    for tx in (200, 420):
        L.prop("round_table", tx, 190, collider=[tx - 10, 176, 20, 12])
        L.prop("chair", tx - 18, 190)
        L.prop("chair", tx + 18, 190)
    L.prop("plant", 70, 190, collider=[64, 182, 12, 8])
    L.prop("plant", 540, 190, collider=[534, 182, 12, 8])
    c.save("train/r_tearoom_bg.png")
    L.save()


def r_club():
    """Клубный вагон (дело 8): карточные столы с зелёным сукном, кожаные кресла, бар с сигарами, рояль."""
    L, c = restaurant_skeleton("r_club", "Клубный вагон", "#1e2a4a", "#141c34", "stripes", "#3a2418",
                               "#4a3024", "#3a2418", "#5a1a24", "#3a1018", GOLD)
    rng = noise_rng(91)
    for k in range(4):
        x0 = 72 + 108 * k
        window(c, x0 + 32, 14, 40, 24, curtain="#5a1a24")
        for side, sx in ((0, x0 + 2), (1, x0 + 88)):
            for yy in (64, 92):
                c.brect(sx + 2, yy + 3, 16, 22, (20, 10, 30, 80))
                c.rrect(sx, yy, 16, 22, 3, "#6a3a24")
                c.rect(sx + 2, yy + 2, 12, 3, "#8a5034")
            L.col(sx, 64, 16, 50)
        # карточный стол с сукном и картами
        c.brect(x0 + 30, 70, 46, 34, (20, 10, 30, 90))
        c.rrect(x0 + 28, 66, 46, 34, 6, "#3a2418")
        c.rrect(x0 + 31, 69, 40, 28, 5, "#1f6a3a")
        for i in range(4):
            c.rect(x0 + 36 + i * 8, 76 + (i % 2) * 6, 5, 7, "#f4f0ff")
            c.set(x0 + 38 + i * 8, 79 + (i % 2) * 6, "#c0394b" if i % 2 else "#1a1430")
        L.col(x0 + 28, 66, 46, 34)
        L.d["lamps"].append([x0 + 51, 60])
        L.d["window_lights"].append([x0 + 52, 60])
    # бар: тёмное дерево, коробки сигар, бутылки
    c.rect(566, 12, 80, 28, "#2a1810")
    for bx in range(570, 644, 10):
        c.rect(bx, 26, 8, 5, "#8a5a2a")
        c.rect(bx + 1, 27, 6, 1, GOLD)
    for bx in range(572, 644, 7):
        c.rect(bx, 15, 3, 8, rng.choice(("#5a2a14", "#2a5a3a", "#8a6a2a")))
    L.prop("grand_piano", 40, 88, collider=[14, 60, 52, 26])
    L.prop("coffee_machine", 520, 94, collider=[508, 60, 24, 32])
    L.inter("obj_coffee", 520, 92, "Осмотреть кофейный автомат", None, radius=28)
    L.prop("trash_bin", 544, 104, collider=[538, 96, 12, 8])
    L.inter("obj_trash", 544, 100, "Осмотреть корзину", None, radius=24)
    L.prop("bar_counter", 609, 120, collider=[570, 96, 78, 22])
    L.prop("stool", 590, 134)
    L.prop("stool", 624, 134)
    for tx in (200, 420):
        L.prop("armchair", tx - 16, 190)
        L.prop("armchair", tx + 16, 190)
        L.col(tx - 28, 176, 56, 12)
    inter(L, "obj_r_humidor", 600, 70, "Ящик для сигар", "Хьюмидор клуба", "Коробки сигар с именными ярлыками постоянных пассажиров. Ключик — у проводницы.", radius=26)
    c.save("train/r_club_bg.png")
    L.save()


def r_greenhouse():
    """Вагон-оранжерея (дело 14): кадки с растениями, пучки трав под потолком, столики среди зелени."""
    L, c = restaurant_skeleton("r_greenhouse", "Вагон-оранжерея", "#2a5a3a", "#1e4a2e", "dots", "#4a3a24",
                               "#7a6a4a", "#6a5a3c", "#3a5a2a", "#2a4a1e", "#c8d478")
    rng = noise_rng(101)
    # стеклянная крыша и пучки трав
    for x in range(0, 656, 24):
        c.vline(x, CAP, 40, "#9ab494")
    for x in range(12, 640, 18):
        c.rect(x, CAP + 2, 1, 6, "#6a4c2c")
        col = rng.choice(("#7fd18a", "#a8b45a", "#8a6aa8", "#c8a038"))
        c.poly([(x - 3, CAP + 8), (x + 3, CAP + 8), (x + 1, CAP + 18), (x - 1, CAP + 18)], col)
    for k in range(4):
        x0 = 72 + 108 * k
        window(c, x0 + 28, 18, 48, 20, curtain="#3a6a3a")
        for sx in (x0, x0 + 86):
            c.brect(sx + 2, 64, 18, 54, (20, 30, 10, 70))
            c.rrect(sx, 60, 18, 56, 3, "#8a5a3c")
            c.rect(sx + 2, 62, 14, 52, "#4a3a24")
            for yy in range(64, 112, 9):
                c.ellipse(sx + 9, yy + 3, 6, 4, rng.choice(("#3f9a5a", "#2f7a4a", "#5aa86a")))
                c.set(sx + 9, yy + 2, rng.choice(("#e86a8a", "#f2c14e", "#ffffff")))
            L.col(sx, 60, 18, 56)
        table_top(c, x0 + 28, 62, 48, 30, cloth=True)
        c.ellipse(x0 + 52, 72, 6, 5, "#3f9a5a")
        c.rect(x0 + 50, 74, 4, 4, "#8a4a2a")
        L.col(x0 + 28, 62, 48, 30)
        L.d["lamps"].append([x0 + 52, 20])
        L.d["window_lights"].append([x0 + 52, 60])
    # травяная стойка с банками
    for bx in range(570, 644, 8):
        c.rect(bx, 18, 6, 14, "#cfe6f4")
        c.rect(bx + 1, 22, 4, 9, rng.choice(("#7fd18a", "#a8b45a", "#8a6aa8")))
    L.prop("piano", 40, 86, collider=[16, 58, 48, 26])
    L.prop("tea_urn", 520, 94, collider=[508, 60, 24, 32])
    L.inter("obj_coffee", 520, 92, "Осмотреть чайный бак", None, radius=28)
    L.prop("planter", 544, 104, collider=[536, 94, 16, 12])
    L.inter("obj_trash", 544, 100, "Осмотреть кадку", None, radius=24)
    L.prop("herb_counter", 609, 120, collider=[570, 96, 78, 22])
    L.prop("stool", 590, 134)
    L.prop("stool", 624, 134)
    for tx in (200, 420):
        L.prop("round_table", tx, 190, collider=[tx - 10, 176, 20, 12])
        L.prop("chair", tx - 18, 190)
        L.prop("chair", tx + 18, 190)
    for px in (70, 300, 540):
        L.prop("planter", px, 190, collider=[px - 8, 180, 16, 10])
    inter(L, "obj_r_herbs", 596, 70, "Травяная стойка", "Травяная стойка", "Банки с подписями: мята, чабрец, душица. Пустое место на полке — для какой-то банки, которой здесь нет.", radius=28)
    c.save("train/r_greenhouse_bg.png")
    L.save()


# =========================================================================================
# Роль «пассажирский» — общий скелет (служебка, 4 отсека, торец), разная мебель и отделка
# =========================================================================================
def passenger_skeleton(cid, name, style):
    W = 656
    L = Layout(cid, name, W)
    L.d["role"] = "passenger"
    c = Canvas(W, H)
    rng = noise_rng(style.get("seed", 11))
    wall_face(c, 0, W, style["wall"], style["wall_d"], style["pattern"], wain=style.get("wain", WOOD_D), seed=style.get("seed", 3))
    wood_floor(c, 8, FACE_BOTTOM, W - 8, FLOOR_BOTTOM, base=style.get("floor", WOOD), seed=style.get("seed", 4))
    if style.get("runner"):
        carpet_runner(c, 8, 146, W - 8, 186, base=style["runner"], dark=shade(style["runner"], -0.3), trim=style.get("trim", GOLD))
    for i in range(6):
        c.brect(8, FACE_BOTTOM + i, W - 16, 1, (20, 10, 40, 90 - i * 15))
    bottom_wall(c, W, range(40, W - 40, 72))
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)
    # служебное купе
    window(c, 30, 16, 40, 22, curtain=style.get("curtain_svc", "#2f4377"))
    style["svc"](c, L, rng)
    L.col(18, 58, 62, 26)
    partition(c, 104, FACE_BOTTOM, 128)
    L.col(104, FACE_BOTTOM, 6, 72)
    L.spot("svc_desk", 50, 102, "up", "sit")
    L.spot("svc_register", 62, 98, "up")
    L.spot("svc_shelf", 88, 100, "up")
    L.spot("svc_door", 64, 166, "right")
    L.inter("obj_register", 54, 70, "Осмотреть журнал", "register", radius=34)
    L.inter("obj_monitor", 34, 70, "Камеры", None, radius=30)
    L.d["lamps"].append([56, 12])
    L.d["window_lights"].append([50, 60])
    bays = []
    for k in range(4):
        x0 = 110 + 112 * k
        bays.append(x0)
        n = k + 1
        style["bay"](c, L, x0, k, rng)
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
            style["lamp"](c, x0 + 109, 24)
    partition(c, 552, FACE_BOTTOM, 128)
    L.col(552, FACE_BOTTOM, 6, 72)
    style["lamp"](c, 555, 24)
    L.d["lamps"].append([555, 20])
    L.d["bays"] = bays
    style["end"](c, L, rng)
    L.spot("end_rack", 586, 104, "up")
    L.spot("end_mirror", 612, 104, "up")
    L.spot("end_corner", 634, 120, "left")
    L.d["luggage_slots"]["end_floor"] = [618, 134]
    L.inter("obj_rack", 600, 88, style.get("rack_label", "Осмотреть стеллаж"), None, radius=30)
    for px in (162, 498):
        L.prop(style.get("corridor_prop", "plant"), px, 190, collider=[px - 6, 182, 12, 8])
    end_walls(c, W, L, left_locked=True)
    L.prop("cctv", 540, 12)
    L.prop("cctv", 96, 50)
    L.d["cameras"].append({"id": "cam1", "name": name, "rect": [100, 40, 556, 168]})
    L.d["cameras"].append({"id": "cam2", "name": "Служебное купе", "rect": [0, 40, 150, 168]})
    if style.get("extra"):
        style["extra"](c, L, rng)
    c.save(f"train/{cid}_bg.png")
    L.save()


def armchair_bg(c, x, y, col):
    c.brect(x + 3, y + 3, 20, 24, (20, 10, 30, 80))
    c.rrect(x, y, 20, 24, 4, shade(col, -0.25))
    c.rrect(x + 3, y + 4, 14, 18, 3, col)
    c.rect(x + 4, y + 5, 12, 2, shade(col, 0.2))


def gas_lamp(c, x, y):
    c.rect(x - 1, y + 2, 3, 8, "#5a4a3a")
    c.ellipse(x + 0.5, y, 4, 4, "#e8d0a0")
    c.ellipse(x + 0.5, y - 0.5, 2, 2, "#fff4d8")


def bulb(c, x, y):
    c.rect(x, y - 4, 1, 6, "#2a2a2a")
    c.ellipse(x + 0.5, y + 3, 3, 3, "#fff4c8")


def chandelier(c, x, y):
    c.rect(x, y - 4, 1, 4, GOLD)
    c.hline(x - 6, x + 6, y, GOLD)
    for dx in (-6, -2, 2, 6):
        c.ellipse(x + dx + 0.5, y + 3, 1.6, 2, "#fff4c8")


def p_firstclass():
    """Первый класс (дело 3): кресла попарно, круглые столики, панорамные окна, зеркала-простенки."""
    def svc(c, L, rng):
        table_top(c, 18, 58, 62, 26)
        c.ellipse(70, 66, 4, 3, GOLD)   # звонок консьержа
        c.rect(69, 62, 2, 3, GOLD_L)
        L.prop("monitor", 30, 74)
        L.prop("samovar", 92, 76, collider=[84, 64, 16, 12])

    def bay(c, L, x0, k, rng):
        window(c, x0 + 16, 14, 74, 26, curtain="#1f4a3a")
        for sx in (x0 + 4, x0 + 82):
            armchair_bg(c, sx, 72, "#2f6a4a")
            armchair_bg(c, sx, 100, "#2f6a4a")
            L.col(sx, 72, 20, 52)
        c.ellipse(x0 + 53, 76, 14, 10, "#5e3a26")
        c.ellipse(x0 + 53, 75, 12, 8, "#8a5a3c")
        c.ellipse(x0 + 49, 73, 3, 2, "#ffffff")
        c.rect(x0 + 56, 72, 3, 5, "#c0394b")
        L.col(x0 + 41, 66, 24, 20)
        # высокое зеркало на простенке
        c.rect(x0 + 102, 16, 8, 30, GOLD)
        c.rect(x0 + 103, 17, 6, 28, "#9ab4cc")

    def end(c, L, rng):
        c.rect(562, 14, 76, 44, "#3a2418")
        c.rect(566, 18, 32, 38, "#5e3a26")
        c.rect(602, 18, 32, 38, "#5e3a26")
        c.rect(597, 34, 2, 6, GOLD)
        c.rect(601, 34, 2, 6, GOLD)
        L.col(562, 60, 76, 30)
        c.rect(562, 60, 76, 28, "#4a2c1e")
        for bx in (566, 590, 614):
            c.rect(bx, 64, 20, 20, ("#7a2a3a", "#2f4a6b", "#6a5a2a")[(bx // 24) % 3])
        L.prop("mirror", 611, 30)

    passenger_skeleton("p_firstclass", "Вагон первого класса", {
        "wall": "#1e3a2e", "wall_d": "#2a4a3a", "pattern": "damask", "wain": "#3a2418", "floor": "#6e4a34",
        "runner": "#7a1a2a", "seed": 13, "svc": svc, "bay": bay, "end": end, "lamp": chandelier,
        "rack_label": "Осмотреть гардероб", "corridor_prop": "plant"})


def p_hardseat():
    """Общий вагон (дело 2): деревянные лавки рядами, плакаты, голые лампочки, титан с кипятком."""
    def svc(c, L, rng):
        table_top(c, 18, 58, 62, 26)
        L.prop("monitor", 30, 74)
        L.prop("titan", 92, 76, collider=[84, 64, 16, 12])

    def bay(c, L, x0, k, rng):
        window(c, x0 + 30, 16, 46, 22, curtain="#4a6a4a")
        for sx, facing in ((x0 + 2, "right"), (x0 + 82, "left")):
            c.brect(sx + 3, 64, 22, 62, (24, 10, 34, 60))
            c.rect(sx, 60, 22, 64, "#8a6a4a")
            for yy in range(62, 122, 6):
                c.hline(sx + 1, sx + 20, yy, "#6a4c2c")
            bx = sx if facing == "right" else sx + 16
            c.rect(bx, 60, 6, 64, "#6a4c2c")
            L.col(sx, 60, 22, 64)
        c.rect(x0 + 40, 60, 26, 22, "#9a7a5a")
        c.rect(x0 + 40, 80, 26, 2, "#5a3a24")
        c.rect(x0 + 46, 64, 6, 6, "#efe6c8")
        L.col(x0 + 40, 60, 26, 22)
        # плакат на стене
        if k % 2 == 0:
            c.rect(x0 + 84, 16, 18, 22, "#e8dcc0")
            c.rect(x0 + 86, 18, 14, 8, "#c0394b")
            c.hline(x0 + 86, x0 + 99, 30, "#3a3a3a")
            c.hline(x0 + 86, x0 + 96, 33, "#3a3a3a")

    def end(c, L, rng):
        c.rect(562, 60, 76, 30, "#6a5a40")
        for bx in range(566, 634, 14):
            c.ellipse(bx + 6, 74, 6, 5, rng.choice(("#a8a07c", "#8a8466", "#b48a58")))
        L.col(562, 60, 76, 30)
        L.prop("mirror", 611, 30)

    passenger_skeleton("p_hardseat", "Общий вагон", {
        "wall": "#4a6a5a", "wall_d": "#5a7a6a", "pattern": "stripes", "wain": "#5a4632", "floor": "#7a6a52",
        "runner": None, "seed": 17, "svc": svc, "bay": bay, "end": end, "lamp": bulb,
        "rack_label": "Осмотреть полку для узлов", "corridor_prop": "plant"})


def p_platzkart():
    """Плацкартный ночной вагон (дело 7): нижние полки и верхние полки над ними, синяя ночная отделка."""
    def svc(c, L, rng):
        table_top(c, 18, 58, 62, 26)
        L.prop("monitor", 30, 74)
        L.prop("samovar", 92, 76, collider=[84, 64, 16, 12])

    def bay(c, L, x0, k, rng):
        window(c, x0 + 30, 16, 46, 22, curtain="#24305a")
        for sx in (x0 + 2, x0 + 80):
            c.brect(sx + 3, 64, 24, 62, (24, 10, 34, 70))
            c.rrect(sx, 60, 24, 64, 3, "#3a4a7a")
            c.rect(sx + 2, 62, 20, 60, "#e8e0d0")
            c.rect(sx + 2, 80, 20, 40, ("#2f4377", "#5a3a6a", "#2f5a4a", "#6a3a3a")[k])
            c.rrect(sx + 4, 64, 16, 10, 3, "#ffffff")
            L.col(sx, 60, 24, 64)
        # верхние полки (видны как тень и бортик поверх)
        for sx in (x0 + 2, x0 + 80):
            c.blend(sx, 58, (10, 10, 30, 80))
            c.rect(sx, 56, 24, 3, "#2a3458")
        # свисающее с полки полотенце
        c.rect(x0 + 26, 58, 4, 14, "#efe6c8")
        c.rect(x0 + 40, 60, 26, 20, "#4a3a2a")
        c.rect(x0 + 44, 64, 6, 4, "#efe6c8")
        L.col(x0 + 40, 60, 26, 20)

    def end(c, L, rng):
        c.rect(566, 20, 22, 36, "#9aa4b4")
        c.rect(568, 22, 18, 30, "#c8ccd8")
        c.ellipse(577, 40, 4, 4, "#5a5a68")
        L.prop("luggage_rack", 600, 92, collider=[562, 60, 76, 30])
        L.prop("mirror", 611, 30)

    passenger_skeleton("p_platzkart", "Плацкартный вагон", {
        "wall": "#1e2648", "wall_d": "#283258", "pattern": "dots", "wain": "#2a2e4a", "floor": "#4a4a5e",
        "runner": "#2a3a6a", "trim": "#8a9ad0", "seed": 19, "svc": svc, "bay": bay, "end": end, "lamp": bulb,
        "rack_label": "Осмотреть багажную полку", "corridor_prop": "plant"})


def p_vintage():
    """Вагон 1926 года (дела 9–10): тёмное дерево, газовые рожки, кружевные занавески, паутина, пыль."""
    def svc(c, L, rng):
        table_top(c, 18, 58, 62, 26)
        c.rect(24, 62, 10, 7, "#efe6c8")
        L.prop("monitor", 30, 74)
        L.prop("samovar", 92, 76, collider=[84, 64, 16, 12])

    def bay(c, L, x0, k, rng):
        window(c, x0 + 30, 16, 46, 22, curtain="#d8d0c0")
        for yy in range(16, 38, 3):
            for xx in range(x0 + 24, x0 + 30, 2):
                c.set(xx, yy, "#efe6dc")
        bench_vertical(c, x0 + 2, 60, 22, 64, "right")
        bench_vertical(c, x0 + 82, 60, 22, 64, "left")
        table_top(c, x0 + 38, 58, 30, 28)
        c.rect(x0 + 44, 62, 8, 6, "#d8c49a")
        L.col(x0 + 2, 60, 22, 64)
        L.col(x0 + 82, 60, 22, 64)
        L.col(x0 + 38, 58, 30, 28)
        # выцветший портрет и паутина в углу
        c.rect(x0 + 84, 14, 16, 20, "#6a5040")
        c.rect(x0 + 86, 16, 12, 16, "#a8987c")
        c.ellipse(x0 + 92, 22, 3, 4, "#7a6a5a")
        for i in range(6):
            c.blend(x0 + 2 + i, CAP + 2 + i, (220, 220, 230, 90))
            c.blend(x0 + 2 + i * 2, CAP + 2, (220, 220, 230, 70))
        for _ in range(40):
            c.blend(rng.randint(x0, x0 + 104), rng.randint(130, 190), (180, 170, 150, 50))

    def end(c, L, rng):
        L.col(562, 60, 76, 30)
        for bx, col in ((566, "#5e3a26"), (590, "#4a3a2a"), (614, "#6a4a2a")):
            c.rect(bx, 62, 22, 24, col)
            c.rect(bx, 62, 22, 3, shade(col, 0.2))
            c.rect(bx + 9, 70, 4, 4, GOLD)
        c.rect(570, 20, 60, 14, "#3a2418")
        c.rect(574, 24, 52, 6, "#c8b48a")
        L.prop("mirror", 611, 30)

    passenger_skeleton("p_vintage", "Вагон 1926 года", {
        "wall": "#3a2a24", "wall_d": "#4a362e", "pattern": "damask", "wain": "#2a1a14", "floor": "#5a4030",
        "runner": "#5a3a3a", "trim": "#a8906a", "seed": 23, "svc": svc, "bay": bay, "end": end, "lamp": gas_lamp,
        "rack_label": "Осмотреть старые сундуки", "corridor_prop": "plant"})


# =========================================================================================
# Самостоятельный вагон: архив (дело 10)
# =========================================================================================
def archive():
    W = 400
    L = Layout("archive", "Архивный вагон", W)
    c = Canvas(W, H)
    rng = noise_rng(111)
    wall_face(c, 0, W, "#3a3428", "#4a4434", "stripes", wain="#2a2418", seed=7)
    wood_floor(c, 8, FACE_BOTTOM, W - 8, FLOOR_BOTTOM, base="#5a4632", seed=29)
    bottom_wall(c, W, range(40, W - 40, 90))
    L.col(0, 0, W, 60)
    L.col(0, FLOOR_BOTTOM, W, H - FLOOR_BOTTOM)
    # стеллажи с папками вдоль стены
    for x0 in (16, 112, 208):
        c.rect(x0, 14, 84, 42, "#4a3424")
        for sy in (18, 32, 46):
            c.rect(x0 + 2, sy + 8, 80, 2, "#2a1a10")
            for bx in range(x0 + 4, x0 + 80, 5):
                c.rect(bx, sy, 4, 8, rng.choice(("#c8b48a", "#a8987c", "#8a6a4a", "#d8c8a0", "#6a5a8a")))
    # картотека и стол архивариуса
    L.prop("file_cabinet", 60, 90, collider=[44, 60, 32, 28])
    L.prop("file_cabinet", 156, 90, collider=[140, 60, 32, 28])
    table_top(c, 250, 64, 60, 26)
    c.rect(256, 68, 12, 8, "#efe6c8")
    c.rect(272, 70, 10, 7, "#d8c49a")
    c.ellipse(298, 70, 5, 4, "#ffd27a")
    L.col(250, 64, 60, 26)
    # доска с фотографиями
    c.rect(322, 14, 64, 40, "#6a5040")
    for i, (px, py) in enumerate(((326, 18), (344, 22), (362, 18), (330, 36), (352, 38), (370, 34))):
        c.rect(px, py, 12, 10, "#c8c0b0")
        c.rect(px + 1, py + 1, 10, 6, "#7a7a7a")
        c.set(px + 6, py, "#c0394b")
    c.line(332, 23, 356, 27, "#c0394b")
    c.line(356, 27, 376, 39, "#c0394b")
    L.spot("ar_desk", 280, 104, "up", "sit")
    L.spot("ar_shelf1", 58, 104, "up")
    L.spot("ar_shelf2", 200, 100, "up")
    L.spot("ar_board", 354, 96, "up")
    L.spot("ar_corner", 380, 130, "left")
    L.spot("ar_aisle", 200, CORRIDOR_Y, "up")
    L.d["luggage_slots"]["ar_floor"] = [120, 130]
    for x in (60, 200, 340):
        L.d["lamps"].append([x, 14])
        c.rect(x, 4, 1, 6, "#5a5a68")
        c.ellipse(x, 11, 5, 3, "#c8d478")
    inter(L, "obj_ar_cabinet", 60, 96, "Картотека", "Картотека рейсов", "Ящики с карточками рейсов по годам. Один ящик — «1926» — выдвинут.", radius=30)
    inter(L, "obj_ar_board", 354, 84, "Доска с фотографиями", "Доска с фотографиями", "Снимки пассажиров разных лет, соединённые красной нитью. Кто-то искал одно и то же лицо.", radius=30)
    end_walls(c, W, L)
    L.prop("cctv", 380, 12)
    L.d["cameras"].append({"id": "cam8", "name": "Архивный вагон", "rect": [0, 40, W, 168]})
    L.d["door_messages"] = {"right": "Хвост поезда. За дверью — только туман."}
    c.save("train/archive_bg.png")
    L.save()


# =========================================================================================
# Предметы новых вагонов
# =========================================================================================
def make_props():
    c = Canvas(26, 30)
    c.rrect(1, 6, 24, 22, 5, "#5a1a2a")
    c.rrect(4, 10, 18, 14, 4, "#8a2a3a")
    c.rect(1, 6, 24, 6, "#6a2232")
    c.rect(5, 12, 16, 2, "#a8445a")
    prop("armchair", c)
    c = Canvas(10, 24)
    c.ellipse(5, 4, 4, 2, "#9aa4b4")
    c.rect(4, 5, 2, 16, "#5a5a68")
    c.ellipse(5, 22, 4, 2, "#3a3a44")
    prop("ashtray", c)
    c = Canvas(42, 26)
    c.rect(1, 8, 40, 16, WOOD_D)
    c.rect(1, 6, 40, 4, WOOD)
    c.rect(8, 1, 18, 7, "#3a3a44")
    c.rect(10, 3, 14, 3, "#d9a441")
    c.ellipse(32, 4, 4, 3, "#2a2a2a")
    c.rect(28, 6, 10, 2, "#efe6c8")
    prop("telegraph_desk", c)
    c = Canvas(14, 30)
    c.rect(2, 22, 10, 6, "#3a3a44")
    c.line(7, 22, 4, 2, "#5a5a68")
    c.line(8, 22, 5, 2, "#5a5a68")
    c.ellipse(4, 2, 3, 2, "#c0394b")
    c.rect(1, 24, 12, 2, "#dcecff")
    prop("switch_lever", c)
    c = Canvas(32, 28)
    c.rect(4, 14, 24, 12, "#5e3a26")
    c.rect(4, 12, 24, 3, "#8a5a3c")
    c.ellipse(16, 10, 5, 3, "#3a2a1e")
    c.poly([(16, 9), (24, 1), (30, 4), (20, 11)], "#d9a441")
    c.ellipse(27, 3, 3, 3, "#b08a3a")
    prop("gramophone", c)
    c = Canvas(26, 36)
    c.ellipse(13, 22, 10, 12, "#d9a441")
    c.ellipse(13, 20, 8, 9, "#e8c060")
    c.rect(10, 4, 6, 8, "#b08a3a")
    c.ellipse(13, 4, 4, 2, "#8a6a2a")
    c.rect(22, 22, 4, 2, "#b08a3a")
    c.rect(6, 33, 14, 3, "#5a4030")
    prop("big_samovar", c)
    c = Canvas(14, 12)
    c.rect(2, 3, 10, 8, "#7a7a8c")
    c.rect(1, 2, 12, 2, "#9aa4b4")
    c.rect(4, 4, 6, 2, "#5a3a24")
    prop("tea_bucket", c)
    c = Canvas(80, 28)
    c.rect(1, 6, 78, 20, "#6a3a1e")
    c.rect(1, 4, 78, 4, "#8a5a3c")
    for x in range(6, 76, 12):
        c.ellipse(x + 3, 3, 3, 2, "#d9a441")
    prop("tea_counter", c)
    c = Canvas(56, 30)
    c.poly([(2, 10), (40, 4), (54, 12), (52, 26), (4, 26)], "#141018")
    c.poly([(4, 12), (40, 6), (50, 13), (48, 24), (6, 24)], "#241c2a")
    c.rect(8, 22, 40, 4, "#efe6dc")
    for x in range(10, 46, 4):
        c.vline(x, 22, 25, "#141018")
    prop("grand_piano", c)
    c = Canvas(26, 36)
    c.rect(4, 8, 18, 24, "#9aa4b4")
    c.rect(6, 10, 14, 20, "#c8ccd8")
    c.rect(8, 4, 10, 4, "#7a7a8c")
    c.rect(20, 20, 4, 2, "#5a5a68")
    c.rect(6, 32, 14, 3, "#5a5a68")
    prop("tea_urn", c)
    c = Canvas(18, 22)
    c.rect(3, 12, 12, 9, "#8a4a2a")
    c.rect(2, 11, 14, 2, "#a85a3a")
    for x, y, col in ((9, 5, "#3f9a5a"), (5, 8, "#2f7a4a"), (13, 8, "#2f7a4a"), (9, 1, "#5aa86a")):
        c.ellipse(x, y, 4, 4, col)
    c.set(9, 4, "#e86a8a")
    prop("planter", c)
    c = Canvas(80, 28)
    c.rect(1, 6, 78, 20, "#5e3a26")
    c.rect(1, 4, 78, 4, "#7a5a36")
    for x in range(6, 76, 10):
        c.rect(x, 1, 4, 4, "#cfe6f4")
        c.rect(x + 1, 2, 2, 2, "#7fd18a")
    prop("herb_counter", c)
    c = Canvas(18, 26)
    c.rect(3, 6, 12, 18, "#9aa4b4")
    c.rect(5, 8, 8, 14, "#c8ccd8")
    c.rect(6, 2, 6, 4, "#7a7a8c")
    c.rect(15, 14, 3, 2, "#5a5a68")
    prop("titan", c)
    c = Canvas(34, 30)
    c.rect(1, 2, 32, 26, "#5a5a68")
    for y in (4, 12, 20):
        c.rect(3, y, 28, 6, "#7a7a8c")
        c.rect(14, y + 2, 6, 2, "#d9a441")
    prop("file_cabinet", c)


def main():
    make_props()
    for name, img in PROPS.items():
        img.save(f"props/{name}.png")
    for fn in (v_service, v_luggage, v_workshop, v_smoking, v_telegraph, v_switch, v_platform, v_mirror, v_moon,
               r_tearoom, r_club, r_greenhouse, p_firstclass, p_hardseat, p_platzkart, p_vintage, archive):
        fn()


if __name__ == "__main__":
    main()
