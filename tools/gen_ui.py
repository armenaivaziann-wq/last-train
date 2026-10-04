#!/usr/bin/env python3
"""Пиксельные иконки интерфейса LAST TRAIN (24×24, выводятся ×2–×3) и элементы управления.

Запуск:  python3 tools/gen_ui.py
"""
import math

from pixelart import Canvas, OUTLINE, mix, shade, soft_glow

GOLD = "#f2c14e"
GOLD_D = "#c0882a"
GOLD_L = "#fff1a8"
CYAN = "#5ad6ff"
CYAN_D = "#2a8ac8"
PURPLE = "#9b5cf6"
PURPLE_D = "#6a2fc8"
PINK = "#ff5aa8"
WHITE = "#f4f0ff"
PAPER = "#f4ead8"
RED = "#ff4a5a"
GREEN = "#4ae08a"

ICONS = {}


def star(c, cx, cy, ro, ri, col, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        r = ro if i % 2 == 0 else ri
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    c.poly(pts, col)


def icon(name):
    def deco(fn):
        c = Canvas(24, 24)
        fn(c)
        c.outline()
        ICONS[name] = c
        return fn
    return deco


@icon("coin")
def _(c):
    c.ellipse(12, 12, 9, 9, GOLD_D)
    c.ellipse(11.5, 11.5, 8, 8, GOLD)
    c.ellipse(12, 12, 5.5, 5.5, GOLD_D)
    c.ellipse(11.5, 11.5, 5, 5, GOLD)
    c.rect(11, 8, 2, 8, GOLD_D)
    c.rect(7, 6, 2, 2, GOLD_L)
    c.set(6, 9, GOLD_L)


@icon("crystal")
def _(c):
    c.poly([(12, 2), (20, 9), (12, 22), (4, 9)], PURPLE_D)
    c.poly([(12, 3), (18, 9), (12, 20), (12, 9)], PURPLE)
    c.poly([(12, 3), (6, 9), (12, 9)], "#c8a0ff")
    c.poly([(6, 9), (12, 9), (12, 20)], "#7a3ae0")
    c.set(10, 6, WHITE)
    c.set(9, 7, WHITE)


@icon("reputation")
def _(c):
    c.poly([(12, 2), (21, 6), (19, 16), (12, 22), (5, 16), (3, 6)], "#2a6ac8")
    c.poly([(12, 4), (19, 7), (17.5, 15), (12, 20), (6.5, 15), (5, 7)], "#4a9aff")
    star(c, 12, 12, 5.5, 2.4, GOLD)
    c.set(8, 6, WHITE)


@icon("star")
def _(c):
    star(c, 12, 12.5, 10, 4.2, GOLD)
    star(c, 11.5, 12, 6, 2.5, GOLD_L)


@icon("clock")
def _(c):
    c.ellipse(12, 12, 10, 10, GOLD_D)
    c.ellipse(12, 12, 8.5, 8.5, WHITE)
    for a in range(12):
        ang = a / 12 * math.tau
        c.set(12 + math.cos(ang) * 7, 12 + math.sin(ang) * 7, "#8a8aa8")
    c.line(12, 12, 12, 6, "#2a2a4a")
    c.line(12, 12, 16, 14, "#2a2a4a")
    c.set(12, 12, RED)


@icon("journal")
def _(c):
    c.rrect(4, 3, 16, 19, 2, "#7a2236")
    c.rect(6, 3, 14, 17, "#a8344e")
    c.rect(4, 3, 3, 19, "#5a1a2a")
    c.rect(9, 7, 8, 5, PAPER)
    c.hline(10, 15, 9, "#8a8aa8")
    c.rect(17, 3, 2, 8, GOLD)
    c.poly([(17, 11), (19, 11), (18, 9)], "#a8344e")
    c.rect(8, 15, 9, 1, GOLD)


@icon("cctv")
def _(c):
    c.rect(2, 4, 4, 8, "#5a6478")
    c.rect(4, 7, 5, 3, "#5a6478")
    c.rrect(7, 5, 13, 8, 2, "#d8dce8")
    c.rect(8, 6, 11, 2, WHITE)
    c.rect(18, 6, 4, 6, "#2a2a3a")
    c.set(20, 8, CYAN)
    c.set(10, 10, RED)
    c.poly([(19, 14), (23, 22), (13, 22)], (90, 214, 255, 120))


@icon("map")
def _(c):
    c.poly([(2, 5), (8, 3), (16, 5), (22, 3), (22, 20), (16, 22), (8, 20), (2, 22)], "#e8d8a8")
    c.poly([(8, 3), (16, 5), (16, 22), (8, 20)], "#d0bc88")
    for i in range(6):
        c.set(5 + i * 3, 15 - (i % 2) * 3, RED)
    c.ellipse(18, 9, 2.5, 2.5, RED)
    c.set(18, 9, WHITE)


@icon("magnifier")
def _(c):
    c.line(15, 15, 21, 21, "#3b2a24")
    c.line(16, 15, 21, 20, "#5a3a2a")
    c.line(15, 16, 20, 21, "#5a3a2a")
    c.ellipse(10, 10, 8, 8, "#c9d2de")
    c.ellipse(10, 10, 6, 6, "#8fd8ff")
    c.ellipse(9, 9, 3, 3, "#bfeaff")
    c.set(7, 7, WHITE)
    c.set(6, 8, WHITE)


@icon("hand")
def _(c):
    c.rrect(7, 9, 11, 12, 3, "#f2c9a0")
    for i, h in enumerate((7, 5, 4, 6)):
        c.rrect(7 + i * 3, 9 - h, 3, h + 3, 1, "#f2c9a0")
    c.rrect(3, 11, 5, 3, 1, "#f2c9a0")
    c.vline(10, 6, 9, "#d8a880")
    c.vline(13, 4, 9, "#d8a880")
    c.vline(16, 5, 9, "#d8a880")


@icon("talk")
def _(c):
    c.rrect(2, 3, 20, 14, 5, WHITE)
    c.poly([(6, 15), (11, 15), (5, 21)], WHITE)
    for x in (7, 12, 17):
        c.ellipse(x, 10, 1.6, 1.6, "#5a5a8a")


@icon("ticket")
def _(c):
    c.rrect(2, 6, 20, 12, 2, "#ffd27a")
    c.ellipse(2, 12, 2, 2, (0, 0, 0, 0))
    c.ellipse(22, 12, 2, 2, (0, 0, 0, 0))
    for y in range(7, 18, 2):
        c.set(15, y, "#c0882a")
    c.rect(5, 9, 8, 2, "#c0394b")
    c.hline(5, 12, 13, "#8a6a3a")
    c.hline(5, 10, 15, "#8a6a3a")
    c.rect(17, 10, 3, 4, "#c0394b")


@icon("suitcase")
def _(c):
    c.rrect(2, 7, 20, 14, 3, "#8a5a3c")
    c.rect(3, 8, 18, 2, "#a8744c")
    c.rect(8, 3, 8, 5, "#5a3426")
    c.rect(10, 5, 4, 3, (0, 0, 0, 0))
    c.rect(2, 13, 20, 2, "#5a3426")
    c.rect(6, 12, 3, 4, GOLD)
    c.rect(15, 12, 3, 4, GOLD)


@icon("document")
def _(c):
    c.rect(5, 2, 14, 20, PAPER)
    c.poly([(14, 2), (19, 7), (14, 7)], "#d8c8a8")
    for y in (9, 12, 15, 18):
        c.hline(8, 16, y, "#9a9ab8")
    c.rect(7, 4, 5, 3, "#c0394b")


@icon("idcard")
def _(c):
    c.rrect(1, 5, 22, 15, 2, "#d8e4f4")
    c.rect(1, 5, 22, 4, "#2f4377")
    c.rect(3, 11, 6, 7, "#9aa8c8")
    c.ellipse(6, 13, 2, 2, "#f2c9a0")
    c.rect(4, 15, 4, 3, "#5a6a8a")
    for y in (12, 15, 17):
        c.hline(11, 20, y, "#7a8aa8")
    c.set(20, 7, GOLD)


@icon("footprint")
def _(c):
    c.ellipse(8, 14, 3.5, 5, "#8a94c8")
    c.ellipse(8, 7, 3, 2.5, "#8a94c8")
    c.ellipse(16, 10, 3.5, 5, "#aab4e8")
    c.ellipse(16, 3.5, 3, 2.5, "#aab4e8")
    c.ellipse(16, 20, 2, 1.5, "#aab4e8")


@icon("item")
def _(c):
    c.poly([(12, 3), (21, 7), (21, 17), (12, 21), (3, 17), (3, 7)], "#c08a4a")
    c.poly([(12, 3), (21, 7), (12, 11), (3, 7)], "#e8b06a")
    c.poly([(12, 11), (21, 7), (21, 17), (12, 21)], "#9a6a3a")
    c.line(7, 5, 16, 9, "#ffe0a0")


@icon("video")
def _(c):
    c.rrect(2, 5, 20, 15, 2, "#2a3048")
    c.rect(4, 7, 16, 11, "#0e2a2e")
    for y in range(8, 18, 2):
        c.hline(5, 18, y, "#1a4a4a")
    c.poly([(10, 9), (16, 12.5), (10, 16)], CYAN)
    c.set(19, 6, RED)


@icon("testimony")
def _(c):
    c.rrect(1, 2, 18, 13, 4, "#c8e8ff")
    c.poly([(4, 13), (9, 13), (3, 19)], "#c8e8ff")
    c.rect(5, 6, 10, 1, "#5a6a9a")
    c.rect(5, 9, 7, 1, "#5a6a9a")
    c.rrect(13, 12, 10, 10, 4, PINK)
    c.rect(17, 14, 2, 4, WHITE)
    c.set(17, 19, WHITE)
    c.set(18, 19, WHITE)


@icon("contradiction")
def _(c):
    c.poly([(13, 1), (5, 13), (11, 13), (9, 23), (19, 9), (13, 9), (16, 1)], GOLD)
    c.poly([(13, 2), (7, 12), (11, 12), (13, 4)], GOLD_L)


@icon("train")
def _(c):
    c.rrect(2, 5, 20, 13, 3, "#3a4a8a")
    c.rect(3, 6, 18, 2, "#5a6ab0")
    for x in (4, 10, 16):
        c.rect(x, 9, 4, 4, "#ffd27a")
    c.rect(2, 15, 20, 2, "#2a3466")
    c.ellipse(6, 19, 2.5, 2.5, "#2a2a3a")
    c.ellipse(18, 19, 2.5, 2.5, "#2a2a3a")
    c.rect(1, 21, 22, 1, "#8a94a8")


@icon("quest")
def _(c):
    c.rect(5, 3, 14, 18, PAPER)
    c.rect(3, 2, 18, 3, "#c8a878")
    c.rect(3, 19, 18, 3, "#c8a878")
    for y, ok in ((8, True), (12, True), (16, False)):
        c.rect(7, y - 1, 3, 3, GREEN if ok else "#9a9ab8")
        c.hline(11, 16, y, "#8a8aa8")


@icon("trophy")
def _(c):
    c.rect(7, 3, 10, 9, GOLD)
    c.ellipse(12, 11, 5, 4, GOLD)
    c.rect(4, 4, 3, 5, GOLD_D)
    c.rect(17, 4, 3, 5, GOLD_D)
    c.rect(11, 14, 2, 4, GOLD_D)
    c.rect(7, 18, 10, 3, "#8a5a3c")
    c.rect(8, 4, 2, 6, GOLD_L)


@icon("collection")
def _(c):
    c.rrect(2, 5, 12, 16, 2, "#6a4ad6")
    c.rrect(6, 3, 12, 16, 2, "#8a6af6")
    c.rrect(10, 6, 12, 16, 2, "#c8b8ff")
    c.ellipse(16, 13, 3, 3, PURPLE_D)
    c.set(15, 12, GOLD)
    c.set(17, 12, GOLD)


@icon("wardrobe")
def _(c):
    c.rect(4, 13, 16, 2, "#2a2a3a")
    c.rrect(7, 4, 10, 10, 3, "#3a3a52")
    c.rect(7, 11, 10, 2, "#c0394b")
    c.rect(8, 5, 3, 4, "#5a5a7a")


@icon("gear")
def _(c):
    for a in range(8):
        ang = a / 8 * math.tau
        c.ellipse(12 + math.cos(ang) * 8, 12 + math.sin(ang) * 8, 2.6, 2.6, "#aab4c8")
    c.ellipse(12, 12, 8, 8, "#aab4c8")
    c.ellipse(12, 12, 6, 6, "#c8d0e0")
    c.ellipse(12, 12, 3, 3, "#3a3a52")


@icon("pause")
def _(c):
    c.rrect(5, 4, 5, 16, 1, WHITE)
    c.rrect(14, 4, 5, 16, 1, WHITE)


@icon("play")
def _(c):
    c.poly([(6, 3), (20, 12), (6, 21)], WHITE)


@icon("ffwd")
def _(c):
    c.poly([(2, 5), (12, 12), (2, 19)], WHITE)
    c.poly([(11, 5), (21, 12), (11, 19)], WHITE)


@icon("rewind")
def _(c):
    c.poly([(22, 5), (12, 12), (22, 19)], WHITE)
    c.poly([(13, 5), (3, 12), (13, 19)], WHITE)


@icon("flag")
def _(c):
    c.rect(5, 2, 2, 20, "#c8d0e0")
    c.poly([(7, 3), (20, 6), (7, 12)], PINK)
    c.poly([(7, 3), (14, 4.5), (7, 7)], "#ff8ac8")


@icon("close")
def _(c):
    c.line(5, 5, 18, 18, WHITE)
    c.line(6, 5, 19, 18, WHITE)
    c.line(18, 5, 5, 18, WHITE)
    c.line(19, 5, 6, 18, WHITE)


@icon("back")
def _(c):
    c.poly([(3, 12), (11, 4), (11, 9), (20, 9), (20, 15), (11, 15), (11, 20)], WHITE)


@icon("check")
def _(c):
    c.poly([(3, 12), (7, 8), (10, 12), (18, 3), (22, 7), (10, 20)], GREEN)


@icon("lock")
def _(c):
    c.ring(12, 9, 6, 3.5, "#aab4c8")
    c.rect(4, 10, 16, 12, GOLD_D)
    c.rect(5, 11, 14, 10, GOLD)
    c.rect(11, 14, 2, 4, "#5a3a24")


@icon("home")
def _(c):
    c.poly([(12, 2), (22, 11), (2, 11)], "#c0394b")
    c.rect(5, 11, 14, 11, PAPER)
    c.rect(10, 15, 4, 7, "#8a5a3c")
    c.rect(15, 13, 3, 3, CYAN)


@icon("music")
def _(c):
    c.rect(9, 3, 2, 14, WHITE)
    c.rect(17, 2, 2, 13, WHITE)
    c.rect(9, 3, 10, 3, WHITE)
    c.ellipse(7, 18, 3.5, 2.6, WHITE)
    c.ellipse(15, 16, 3.5, 2.6, WHITE)


@icon("sound")
def _(c):
    c.rect(2, 9, 5, 6, WHITE)
    c.poly([(6, 9), (12, 3), (12, 21), (6, 15)], WHITE)
    for r in (4, 8):
        for a in range(-40, 41, 4):
            ang = math.radians(a)
            c.set(13 + math.cos(ang) * r, 12 + math.sin(ang) * r, WHITE)


@icon("vibration")
def _(c):
    c.rrect(8, 3, 9, 18, 2, "#aab4c8")
    c.rect(9, 5, 7, 12, "#3a4a6a")
    for x in (4, 20):
        c.vline(x, 8, 15, WHITE)
    c.vline(2, 10, 13, WHITE)
    c.vline(22, 10, 13, WHITE)


@icon("flashlight")
def _(c):
    c.rect(3, 9, 11, 6, "#3a3a52")
    c.rect(13, 7, 4, 10, "#aab4c8")
    c.poly([(17, 8), (23, 3), (23, 21), (17, 16)], (255, 236, 150, 180))
    c.rect(5, 10, 2, 1, "#c8d0e0")


@icon("recorder")
def _(c):
    c.rrect(5, 2, 14, 20, 3, "#3a3a52")
    c.rect(7, 4, 10, 6, "#9aa4b4")
    for y in (5, 7, 9):
        c.hline(8, 15, y, "#5a6478")
    c.ellipse(12, 15, 3, 3, RED)
    c.set(11, 14, "#ffb0b8")


@icon("scanner")
def _(c):
    c.rrect(3, 3, 18, 18, 4, "#2a3048")
    c.rect(5, 5, 14, 10, "#0e2a2e")
    c.line(5, 10, 18, 10, CYAN)
    c.poly([(8, 8), (10, 6), (12, 12), (14, 7), (16, 10)], (0, 0, 0, 0))
    for x, y in ((6, 10), (8, 8), (10, 12), (12, 7), (14, 11), (16, 9), (18, 10)):
        c.set(x, y, GREEN)
    c.rect(8, 17, 8, 2, PURPLE)


@icon("badge")
def _(c):
    c.poly([(12, 2), (15, 8), (22, 8), (17, 13), (19, 21), (12, 17), (5, 21), (7, 13), (2, 8), (9, 8)], GOLD)
    c.ellipse(12, 12, 3.5, 3.5, GOLD_D)
    c.set(11, 11, GOLD_L)
    c.poly([(12, 3), (14, 8), (12, 8)], GOLD_L)


@icon("guard")
def _(c):
    c.poly([(12, 2), (21, 6), (19, 16), (12, 22), (5, 16), (3, 6)], "#c0394b")
    c.poly([(12, 4), (19, 7), (17.5, 15), (12, 20), (6.5, 15), (5, 7)], "#ff6a7a")
    c.rect(11, 7, 2, 7, WHITE)
    c.rect(11, 16, 2, 2, WHITE)


@icon("verify")
def _(c):
    c.poly([(12, 2), (21, 6), (19, 16), (12, 22), (5, 16), (3, 6)], "#2a8ac8")
    c.poly([(12, 4), (19, 7), (17.5, 15), (12, 20), (6.5, 15), (5, 7)], CYAN)
    c.poly([(7, 12), (9, 10), (11, 12), (16, 7), (18, 9), (11, 16)], WHITE)


@icon("hourglass")
def _(c):
    c.rect(5, 2, 14, 2, "#8a5a3c")
    c.rect(5, 20, 14, 2, "#8a5a3c")
    c.poly([(6, 4), (18, 4), (12, 12), (18, 20), (6, 20), (12, 12)], "#c8e8ff")
    c.poly([(8, 6), (16, 6), (12, 11)], GOLD)
    c.poly([(12, 15), (16, 19), (8, 19)], GOLD)


@icon("bestiary")
def _(c):
    c.ellipse(12, 13, 9, 9, PURPLE_D)
    c.ellipse(12, 12, 8, 8, PURPLE)
    c.poly([(5, 7), (4, 1), (9, 5)], PURPLE)
    c.poly([(19, 7), (20, 1), (15, 5)], PURPLE)
    c.ellipse(9, 11, 2.5, 3, GOLD_L)
    c.ellipse(15, 11, 2.5, 3, GOLD_L)
    c.set(9, 11, OUTLINE)
    c.set(15, 11, OUTLINE)
    c.rect(9, 16, 6, 1, OUTLINE)
    c.set(10, 17, WHITE)
    c.set(13, 17, WHITE)


@icon("passenger")
def _(c):
    c.ellipse(12, 8, 5, 5, "#f2c9a0")
    c.rrect(7, 3, 10, 4, 2, "#4a2f2a")
    c.rrect(5, 14, 14, 9, 4, "#8a93a6")
    c.rect(11, 14, 2, 5, "#8c2f3f")


@icon("medal")
def _(c):
    c.poly([(7, 1), (11, 1), (13, 9), (9, 9)], "#2a6ac8")
    c.poly([(17, 1), (13, 1), (11, 9), (15, 9)], RED)
    c.ellipse(12, 15, 7, 7, GOLD_D)
    c.ellipse(12, 15, 5.5, 5.5, GOLD)
    star(c, 12, 15, 4, 1.7, GOLD_L)


@icon("event")
def _(c):
    c.poly([(12, 2), (16, 9), (22, 9), (18, 14), (20, 22), (12, 18), (4, 22), (6, 14), (2, 9), (8, 9)], "#e8803a")
    c.ellipse(12, 12, 4, 4, "#ffc86a")
    c.line(12, 18, 12, 23, "#8a5a3c")


@icon("arrow_right")
def _(c):
    c.poly([(4, 9), (13, 9), (13, 4), (21, 12), (13, 20), (13, 15), (4, 15)], WHITE)


@icon("question")
def _(c):
    c.ellipse(12, 12, 10, 10, "#5a4ab8")
    c.rect(9, 6, 6, 2, WHITE)
    c.rect(14, 7, 2, 4, WHITE)
    c.rect(11, 11, 4, 2, WHITE)
    c.rect(11, 13, 2, 2, WHITE)
    c.rect(11, 16, 2, 2, WHITE)


@icon("link")
def _(c):
    c.ring(8, 14, 5, 3, CYAN)
    c.ring(16, 10, 5, 3, CYAN)
    c.line(9, 12, 15, 12, WHITE)


@icon("lab")
def _(c):
    c.rect(9, 2, 6, 2, "#c8d0e0")
    c.rect(10, 4, 4, 6, "#c8e8ff")
    c.poly([(10, 10), (14, 10), (20, 21), (4, 21)], "#c8e8ff")
    c.poly([(7, 16), (17, 16), (20, 21), (4, 21)], GREEN)
    c.set(10, 18, WHITE)
    c.set(13, 17, WHITE)


@icon("eye")
def _(c):
    c.ellipse(12, 12, 10, 6, WHITE)
    c.ellipse(12, 12, 5, 5, CYAN_D)
    c.ellipse(12, 12, 2.5, 2.5, OUTLINE)
    c.set(10, 10, WHITE)


@icon("siren")
def _(c):
    c.rect(4, 18, 16, 4, "#3a3a52")
    c.rrect(6, 6, 12, 13, 5, RED)
    c.rect(8, 8, 3, 6, "#ffb0b8")
    for a, (dx, dy) in enumerate(((-8, -2), (8, -2), (0, -8))):
        c.line(12 + dx * 0.8, 10 + dy * 0.8, 12 + dx, 10 + dy, GOLD)


def joystick():
    base = Canvas(64, 64)
    base.ellipse(32, 32, 31, 31, (30, 26, 70, 150))
    base.ring(32, 32, 31, 29, (110, 200, 255, 200))
    base.ring(32, 32, 22, 21, (110, 200, 255, 70))
    for a in range(4):
        ang = a * math.pi / 2
        x, y = 32 + math.cos(ang) * 25, 32 + math.sin(ang) * 25
        base.ellipse(x, y, 2, 2, (180, 230, 255, 180))
    base.save("ui/joystick_base.png")
    knob = Canvas(32, 32)
    knob.ellipse(16, 16, 15, 15, (60, 50, 140, 230))
    knob.ellipse(16, 16, 13, 13, (130, 110, 230, 240))
    knob.ellipse(14, 13, 6, 5, (190, 180, 255, 240))
    knob.ring(16, 16, 15, 14, (190, 230, 255, 255))
    knob.save("ui/joystick_knob.png")


def main():
    for name, c in ICONS.items():
        c.save(f"icons/{name}.png")
    joystick()
    soft_glow(64, "#9b5cf6", 1.5, 200).save("ui/glow_purple.png")
    soft_glow(64, "#5ad6ff", 1.5, 200).save("ui/glow_cyan.png")
    soft_glow(64, "#ffd27a", 1.5, 220).save("ui/glow_gold.png")
    # пиксельная искорка
    sp = Canvas(9, 9)
    sp.rect(4, 0, 1, 9, "#fff4c0")
    sp.rect(0, 4, 9, 1, "#fff4c0")
    sp.rect(3, 3, 3, 3, "#ffffff")
    sp.save("ui/sparkle.png")
    # «!» над подозрительным
    ex = Canvas(14, 20)
    ex.ellipse(7, 8, 6.5, 7.5, "#ff4a6a")
    ex.rect(6, 3, 3, 8, "#ffffff")
    ex.rect(6, 12, 3, 3, "#ffffff")
    ex.poly([(4, 14), (10, 14), (7, 19)], "#ff4a6a")
    ex.outline()
    ex.save("ui/exclaim.png")
    # маркер интерактивного объекта (стрелка)
    ar = Canvas(11, 9)
    ar.poly([(0, 0), (11, 0), (5.5, 8)], "#5ad6ff")
    ar.poly([(2, 1), (9, 1), (5.5, 6)], "#c8f0ff")
    ar.save("ui/marker.png")
    # иконка-облачко над NPC (фон пузыря)
    bub = Canvas(16, 16)
    bub.rrect(0, 0, 16, 13, 4, "#f4f0ff")
    bub.poly([(5, 12), (10, 12), (6, 16)], "#f4f0ff")
    bub.outline()
    bub.save("ui/bubble.png")
    act_icons()
    ring = Canvas(30, 12)
    ring.ellipse(15, 6, 14, 5.5, "#ffd86b")
    ring.ellipse(15, 6, 11.5, 3.6, (0, 0, 0, 0))
    for x in (2, 27):
        ring.set(x, 6, "#fff4c0")
    ring.save("ui/target_ring.png")




def act_icons():
    """Маленькие значки занятий NPC (рисуются в облачке над головой, 10×10)."""
    def mk():
        return Canvas(10, 10)
    ic = {}
    c = mk(); c.rect(1, 2, 8, 6, "#3f6b8a"); c.rect(1, 2, 4, 6, "#f4ead8"); c.rect(5, 2, 4, 6, "#e8dcc0"); c.vline(5, 2, 7, "#5a3a24"); ic["read"] = c
    c = mk(); c.rect(2, 3, 5, 5, "#ffffff"); c.rect(3, 4, 3, 2, "#a0602a"); c.rect(7, 4, 2, 2, "#ffffff"); c.set(3, 1, "#c8c8d8"); c.set(5, 0, "#c8c8d8"); ic["eat"] = c
    c = mk(); c.rect(5, 1, 1, 7, "#5a2fc8"); c.rect(5, 1, 3, 1, "#5a2fc8"); c.ellipse(3.5, 7.5, 2, 1.6, "#5a2fc8"); ic["music"] = c
    c = mk(); c.rect(1, 1, 6, 8, "#ffffff"); c.rect(3, 2, 6, 8, "#f4f0ff"); c.frame(3, 2, 6, 8, "#5a5a8a"); c.set(5, 5, "#d03a5a"); c.set(6, 6, "#d03a5a"); ic["cards"] = c
    c = mk(); c.rect(1, 3, 8, 5, "#2a2a34"); c.rect(3, 2, 3, 1, "#2a2a34"); c.ellipse(5, 5.5, 1.6, 1.6, "#5ad6ff"); c.set(8, 3, "#ffe08a"); ic["photo"] = c
    c = mk(); c.line(2, 8, 7, 3, "#7a8494"); c.rect(6, 1, 3, 3, "#9aa4b4"); c.set(7, 2, (0, 0, 0, 0)); ic["repair"] = c
    c = mk(); c.rect(1, 1, 4, 1, "#5a6ab0"); c.line(4, 2, 1, 5, "#5a6ab0"); c.rect(1, 5, 4, 1, "#5a6ab0"); c.rect(6, 5, 3, 1, "#8a9ad0"); c.set(8, 6, "#8a9ad0"); c.set(7, 7, "#8a9ad0"); c.rect(6, 8, 3, 1, "#8a9ad0"); ic["sleep"] = c
    c = mk(); [c.ellipse(x, 5, 1.2, 1.2, "#5a5a8a") for x in (2, 5, 8)]; ic["dots"] = c
    ic["talk"] = ic["dots"]
    c = mk(); c.line(2, 8, 7, 3, "#f2c14e"); c.line(3, 8, 8, 3, "#d9a441"); c.set(1, 9, "#3a2a24"); ic["write"] = c
    c = mk(); c.ellipse(3, 6, 2, 2, "#8fd8ff"); c.ellipse(7, 4, 1.6, 1.6, "#bfeaff"); c.ellipse(6, 8, 1, 1, "#8fd8ff"); ic["wash"] = c
    c = mk(); c.ellipse(5, 5, 4, 4, "#fff4c0"); c.ellipse(6.5, 4, 3, 3, (0, 0, 0, 0)); ic["window"] = c
    c = mk(); c.ellipse(5, 6, 2.5, 3, "#8fd8ff"); c.set(5, 2, "#8fd8ff"); c.set(4, 5, "#ffffff"); ic["sweat"] = c
    c = mk(); c.rect(4, 1, 2, 5, "#ff4a6a"); c.rect(4, 7, 2, 2, "#ff4a6a"); ic["exclaim"] = c
    c = mk(); c.rect(1, 3, 8, 4, "#ffd27a"); c.rect(6, 3, 1, 4, "#c0882a"); c.rect(2, 4, 3, 1, "#c0394b"); ic["ticket"] = c
    c = mk(); c.ring(4, 4, 3.4, 2, "#c9d2de"); c.ellipse(4, 4, 2, 2, "#8fd8ff"); c.line(6, 6, 8, 8, "#3b2a24"); ic["look"] = c
    c = mk(); c.rect(1, 3, 8, 6, "#8a5a3c"); c.rect(3, 1, 4, 2, "#5a3426"); c.rect(1, 5, 8, 1, "#5a3426"); ic["suitcase"] = c
    c = mk(); c.rect(4, 1, 2, 3, "#ff4a6a"); c.ellipse(5, 6, 3, 3, "#ffd27a"); c.set(4, 6, "#3a2a24"); ic["coffee"] = ic["eat"]
    c = mk(); c.ellipse(5, 5, 4, 4, "#9ad86a"); c.rect(3, 4, 1, 1, OUTLINE); c.rect(6, 4, 1, 1, OUTLINE); c.line(3, 7, 6, 7, OUTLINE); c.set(8, 2, "#c8f0ff"); ic["sick"] = c
    for name, img in ic.items():
        img.save(f"acts/{name}.png")


if __name__ == "__main__":
    main()
