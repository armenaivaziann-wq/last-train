#!/usr/bin/env python3
"""Персонажи LAST TRAIN: детектив и пассажиры. Кадр 32×40, ноги на строке 37.

Запуск из корня проекта:  python3 tools/gen_characters.py
Пишет assets/sprites/characters/<id>.png (лист анимаций), <id>_shadow-free, и
data/sprite_layout.json (ряды анимаций), assets/sprites/portraits/<id>_<expr>.png (64×64).
"""
import json
import os

from pixelart import Canvas, OUTLINE, ROOT, grid, hexc, mix, shade

FW, FH = 32, 40

# --- персонажи (палитры и детали) ---------------------------------------------------------
CHARACTERS = {
    "detective": dict(
        skin="#f2c9a0", hair="#4a2f2a", hair_style="neat", eyes="#3a2a24",
        top="#9aa4bc", top_style="jacket", trim="#eef3fb", shirt="#f0e6cf", tie="#8c2f3f",
        pants="#2d3350", shoes="#1f1c28", accessories=["magnifier", "notebook", "badge"],
    ),
    "agata": dict(
        skin="#f0c8a8", hair="#c9c9d8", hair_style="bun", eyes="#4a3a5a",
        top="#2f4377", top_style="uniform", trim="#f2c14e", shirt="#f4ede0", tie="#c0394b",
        pants="#2a3766", shoes="#1f1c28", hat="conductor", glasses="small",
        accessories=["scarf"], skirt=True,
    ),
    "professor": dict(
        skin="#efc6a4", hair="#ececf4", hair_style="bald", eyes="#3a3a4a",
        top="#8a6a48", top_style="tweed", trim="#5f4630", shirt="#f2ead8", tie="#3f8a5a",
        pants="#c9b48a", shoes="#4a3324", glasses="round", beard="white", accessories=["book"],
    ),
    "klara": dict(
        skin="#f4cfae", hair="#e6b85c", hair_style="ponytail", eyes="#2f7a78",
        top="#e8b13e", top_style="raincoat", trim="#fff1c4", shirt="#2fa3a0", tie="#2fa3a0",
        pants="#3b5a8c", shoes="#6b4026", hat="beret", hat_color="#2fa3a0",
        accessories=["camera"], freckles=True,
    ),
    "louis": dict(
        skin="#eec3a0", hair="#1e1a2e", hair_style="slick", eyes="#5a2a7a",
        top="#2c2440", top_style="suit", trim="#9b4fd6", shirt="#f4f0ff", tie="#d03a5a",
        pants="#241e36", shoes="#14111c", hat="tophat", hat_color="#241e36",
        mustache="curl", accessories=["cape"], cape="#6b2fa8", cape_in="#d03a5a",
    ),
    "robert": dict(
        skin="#e9b98f", hair="#3a3036", hair_style="slick_grey", eyes="#3a2a24",
        top="#7a4a2a", top_style="longcoat", trim="#a8703f", shirt="#f0ecdf", tie="#2f3f6b",
        pants="#3a3340", shoes="#1f1c28", mustache="small", accessories=["briefcase"],
    ),
    "john": dict(
        skin="#d9a273", hair="#c8642e", hair_style="messy", eyes="#3a5a3a",
        top="#c96a2b", top_style="overalls", trim="#e8954e", shirt="#9cc3e0", tie="#9cc3e0",
        pants="#c96a2b", shoes="#3a2a20", hat="cap", hat_color="#2b6b6b",
        accessories=["wrench"], smudge=True,
    ),
    "nina": dict(
        skin="#f6d6c0", hair="#2a2f5a", hair_style="long", eyes="#2f8a6b",
        top="#2f8a6b", top_style="dress", trim="#7fd6b4", shirt="#2f8a6b", tie="#e8e0f8",
        pants="#2f8a6b", shoes="#2a1e2e", accessories=["violin_case"], skirt=True,
    ),
    "tikhon": dict(
        skin="#e0c4b0", hair="#4f5d55", hair_style="hood", eyes="#9fd8ff",
        top="#4f5d55", top_style="cloak", trim="#6d7d72", shirt="#3a3a3a", tie="#8c2f3f",
        pants="#3a3530", shoes="#2a2420", hat="hood", hat_color="#4f5d55",
        accessories=["scarf_mask", "bindle"],
    ),
}

# Наряды детектива (косметика): меняется верх, лупа и рубашка остаются.
OUTFITS = {
    "detective_coat": dict(top="#3d3a5c", trim="#e8e4f4", top_style="jacket", tie="#5f9ad6"),
    "detective_vest": dict(top="#7a7a3a", trim="#e0d8a0", top_style="jacket", tie="#a0522d"),
    "detective_festive": dict(top="#5b3a8c", trim="#f2c14e", top_style="jacket", tie="#f2c14e"),
}

ROWS_BASE = [
    ("idle_down", 2, 2.0, True), ("idle_up", 2, 2.0, True), ("idle_left", 2, 2.0, True),
    ("walk_down", 4, 8.0, True), ("walk_up", 4, 8.0, True), ("walk_left", 4, 8.0, True),
    ("sit_down", 2, 1.5, True), ("sit_up", 2, 1.5, True), ("sit_left", 2, 1.5, True),
    ("talk_down", 2, 4.0, True),
]
ROWS_HERO = [
    ("inspect", 3, 5.0, False), ("interact", 2, 5.0, False), ("note", 3, 5.0, True),
    ("suspicion", 2, 3.0, True), ("discovery", 2, 4.0, False), ("wrong", 2, 3.0, True),
    ("arrest", 2, 3.0, False), ("victory", 2, 3.0, True),
]


class P:
    """Палитра персонажа с производными тонами."""

    def __init__(self, d):
        self.d = d
        for k, v in d.items():
            setattr(self, k, v)
        self.skin_d = shade(self.skin, -0.18)
        self.skin_l = shade(self.skin, 0.25)
        self.hair_d = shade(self.hair, -0.3)
        self.hair_l = shade(self.hair, 0.3)
        self.top_d = shade(self.top, -0.28)
        self.top_l = shade(self.top, 0.22)
        self.pants_d = shade(self.pants, -0.3)
        self.shoes_l = shade(self.shoes, 0.25)
        self.hat_color = d.get("hat_color", "#2b3a6b")
        self.acc = set(d.get("accessories", []))

    def has(self, a):
        return a in self.acc


# --- части тела --------------------------------------------------------------------------
def legs_front(c, p, lift_l=0, lift_r=0, b=0, sit=False, view="down"):
    if sit:
        c.rect(11, 33, 4, 2, p.pants)
        c.rect(17, 33, 4, 2, p.pants)
        c.rect(11, 35, 4, 2, p.shoes)
        c.rect(17, 35, 4, 2, p.shoes)
        c.rect(11, 35, 4, 1, p.shoes_l)
        c.rect(17, 35, 4, 1, p.shoes_l)
        return
    for x0, lift in ((11, lift_l), (17, lift_r)):
        top = 31 + b
        bot = 35 - lift
        c.rect(x0, top, 4, bot - top + 1, p.pants)
        c.rect(x0 + 3 if x0 == 17 else x0, top, 1, bot - top + 1, p.pants_d)
        c.rect(x0 - (1 if x0 == 11 else 0), 36 - lift, 5, 2, p.shoes)
        if view == "down":
            c.rect(x0 - (1 if x0 == 11 else 0), 36 - lift, 5, 1, p.shoes_l)


def legs_side(c, p, phase, b=0, sit=False):
    """Вид слева. phase 0/2 — ноги вместе, 1/3 — шаг."""
    if sit:
        c.rect(9, 32, 9, 3, p.pants)
        c.rect(9, 34, 9, 1, p.pants_d)
        c.rect(8, 33, 3, 3, p.pants)
        c.rect(6, 36, 5, 2, p.shoes)
        c.rect(6, 36, 5, 1, p.shoes_l)
        return
    top = 31 + b
    if phase in (0, 2):
        c.rect(14, top, 5, 36 - top, p.pants_d)
        c.rect(13, top, 4, 36 - top, p.pants)
        c.rect(11, 36, 7, 2, p.shoes)
        c.rect(11, 36, 6, 1, p.shoes_l)
    else:
        back_x, front_x = (17, 10) if phase == 1 else (16, 11)
        c.rect(back_x, top, 4, 35 - top, p.pants_d)
        c.rect(back_x + 1, 35, 4, 2, shade(p.shoes, -0.2))
        c.rect(front_x, top, 4, 35 - top, p.pants)
        c.rect(front_x - 2, 35, 5, 2, p.shoes)
        c.rect(front_x - 2, 35, 5, 1, p.shoes_l)


def torso_front(c, p, b, back=False):
    y0 = 20 + b
    style = p.top_style
    long_hem = {"longcoat": 34, "dress": 34, "cloak": 35, "raincoat": 32}.get(style, 31)
    if p.d.get("skirt") and style == "uniform":
        long_hem = 33
    # корпус
    c.rect(10, y0, 12, long_hem - y0 + 1, p.top)
    c.rect(10, y0, 1, long_hem - y0 + 1, p.top_d)
    c.rect(21, y0, 1, long_hem - y0 + 1, p.top_d)
    c.rect(11, y0, 10, 1, p.top_l)
    c.rect(10, long_hem, 12, 1, p.top_d)
    if style in ("dress", "cloak", "longcoat") or p.d.get("skirt"):
        # расклёшенный низ
        c.rect(9, long_hem - 3, 1, 3, p.top_d)
        c.rect(22, long_hem - 3, 1, 3, p.top_d)
    if back:
        c.vline(16, y0 + 2, long_hem - 1, p.top_d)
        if style == "jacket":
            c.rect(10, y0, 12, 1, p.trim)
        if style == "overalls":
            c.rect(10, y0, 12, 4, p.shirt)
            c.rect(12, y0, 2, 5, p.top)
            c.rect(18, y0, 2, 5, p.top)
        return
    if style == "jacket":
        c.rect(14, y0 + 1, 4, 4, p.shirt)
        c.rect(15, y0 + 5, 2, 1, p.shirt)
        c.rect(15, y0 + 1, 2, 5, p.tie)
        c.set(13, y0 + 1, p.trim)
        c.set(18, y0 + 1, p.trim)
        c.rect(10, y0, 3, 1, p.trim)
        c.rect(19, y0, 3, 1, p.trim)
        c.line(13, y0 + 2, 14, y0 + 6, p.top_d)
        c.line(18, y0 + 2, 17, y0 + 6, p.top_d)
        c.set(15, y0 + 8, p.top_d)
        c.set(15, y0 + 10, p.top_d)
    elif style == "uniform":
        c.rect(14, y0 + 1, 4, 2, p.shirt)
        for yy in (y0 + 3, y0 + 6, y0 + 9):
            c.set(13, yy, p.trim)
            c.set(18, yy, p.trim)
        c.rect(10, y0 + 1, 12, 1, p.top_l)
        c.vline(16, y0 + 3, long_hem - 1, p.top_d)
    elif style == "tweed":
        c.rect(14, y0 + 1, 4, 5, p.shirt)
        c.rect(14, y0 + 1, 4, 1, p.tie)
        c.set(13, y0 + 1, p.tie)
        c.set(18, y0 + 1, p.tie)
        for xx in range(11, 21, 3):
            for yy in range(y0 + 3, long_hem, 3):
                c.set(xx, yy, p.top_d)
        c.rect(11, y0 + 7, 3, 2, p.trim)
    elif style == "raincoat":
        c.rect(14, y0 + 1, 4, 2, p.shirt)
        c.rect(10, y0, 12, 2, p.trim)
        c.rect(14, y0 + 2, 4, 1, p.shirt)
        c.vline(16, y0 + 3, long_hem - 1, p.top_d)
        c.set(15, y0 + 5, p.trim)
        c.set(15, y0 + 8, p.trim)
        c.rect(10, y0 + 8, 12, 1, p.top_d)
    elif style == "suit":
        c.rect(14, y0 + 1, 4, 6, p.shirt)
        c.rect(14, y0 + 1, 4, 1, p.tie)
        c.set(13, y0 + 1, p.tie)
        c.set(18, y0 + 1, p.tie)
        c.line(13, y0 + 2, 15, y0 + 7, p.top_d)
        c.line(18, y0 + 2, 16, y0 + 7, p.top_d)
    elif style == "longcoat":
        c.rect(14, y0 + 1, 4, 4, p.shirt)
        c.rect(15, y0 + 1, 2, 5, p.tie)
        c.rect(10, y0, 4, 3, p.trim)
        c.rect(18, y0, 4, 3, p.trim)
        c.vline(16, y0 + 6, long_hem - 1, p.top_d)
        c.rect(10, y0 + 9, 12, 1, p.top_d)
        c.set(17, y0 + 7, p.trim)
        c.set(17, y0 + 11, p.trim)
    elif style == "overalls":
        c.rect(10, y0, 12, 4, p.shirt)
        c.rect(10, y0, 12, 1, shade(p.shirt, 0.2))
        c.rect(12, y0, 2, 4, p.top)
        c.rect(18, y0, 2, 4, p.top)
        c.rect(12, y0 + 4, 8, 4, p.top)
        c.rect(13, y0 + 5, 6, 2, p.top_l)
        c.set(12, y0 + 1, "#f2c14e")
        c.set(19, y0 + 1, "#f2c14e")
        c.rect(10, y0 + 8, 12, 1, "#5a3a24")
    elif style == "dress":
        c.rect(14, y0, 4, 2, p.skin)
        c.rect(13, y0 + 2, 6, 1, p.trim)
        c.rect(10, y0 + 6, 12, 1, p.top_d)
        c.set(16, y0 + 2, p.tie)
        for xx in range(11, 21, 2):
            c.set(xx, long_hem - 1, p.trim)
    elif style == "cloak":
        c.rect(10, y0, 12, 3, p.top_l)
        c.vline(16, y0 + 3, long_hem - 1, p.top_d)
        c.rect(12, y0 + 6, 2, 2, shade(p.top, -0.1))
        c.set(18, y0 + 9, "#8c7a5a")
        c.set(19, y0 + 10, "#8c7a5a")


def arms_front(c, p, b, sl=0, sr=0, hide_l=False, hide_r=False):
    """Руки по бокам; sl/sr — смещение кисти (вперёд = -1)."""
    y0 = 21 + b
    sleeve = p.shirt if p.top_style == "overalls" else p.top
    sleeve_d = shade(sleeve, -0.25)
    if p.top_style == "dress":
        sleeve = p.skin
        sleeve_d = p.skin_d
    for x0, s, hide in ((7, sl, hide_l), (22, sr, hide_r)):
        if hide:
            continue
        h = 8 + s
        c.rect(x0, y0, 3, h, sleeve)
        c.rect(x0 if x0 == 7 else x0 + 2, y0, 1, h, sleeve_d)
        c.rect(x0, y0 + h, 3, 2, p.skin)
        c.rect(x0, y0 + h + 1, 3, 1, p.skin_d)
        if p.top_style == "jacket":
            c.rect(x0, y0 + h - 1, 3, 1, p.shirt)
        if p.top_style == "suit":
            c.rect(x0, y0 + h, 3, 2, "#f4f0ff")


def head_front(c, p, b, expr="normal", mouth="small"):
    y = 4 + b
    c.rrect(7, y, 18, 17, 6, p.skin)
    c.rect(8, y + 13, 16, 3, p.skin)
    c.rect(9, y + 15, 14, 1, p.skin_d)
    # уши
    c.rect(6, y + 9, 1, 3, p.skin_d)
    c.rect(25, y + 9, 1, 3, p.skin_d)
    face_features(c, p, y, expr, mouth)


def face_features(c, p, y, expr, mouth):
    ey = y + 10
    if expr in ("normal", "wide", "brow"):
        h = 3 if expr != "wide" else 4
        for ex in (10, 19):
            c.rect(ex, ey - (1 if expr == "wide" else 0), 3, h, OUTLINE)
            c.rect(ex + 1, ey + h - 2 - (1 if expr == "wide" else 0), 2, 1, p.eyes)
            c.set(ex, ey - (1 if expr == "wide" else 0), "#ffffff")
    elif expr == "happy":
        for ex in (10, 19):
            c.rect(ex, ey + 1, 3, 1, OUTLINE)
            c.set(ex, ey + 2, OUTLINE)
            c.set(ex + 2, ey + 2, OUTLINE)
    elif expr == "narrow":
        for ex in (10, 19):
            c.rect(ex, ey + 1, 3, 1, OUTLINE)
            c.set(ex + 1, ey + 2, p.eyes)
    elif expr == "down":
        for ex in (10, 19):
            c.rect(ex, ey + 2, 3, 1, OUTLINE)
    elif expr == "closed":
        for ex in (10, 19):
            c.rect(ex, ey + 1, 3, 1, OUTLINE)
    # брови
    bc = shade(p.hair, -0.35) if p.hair_style not in ("bald",) else "#b8b8c8"
    if p.hair_style == "hood":
        bc = "#3a3530"
    if expr == "brow":
        c.rect(10, ey - 3, 3, 1, bc)
        c.rect(19, ey - 2, 3, 1, bc)
        c.set(21, ey - 3, bc)
    elif expr in ("down",):
        c.rect(10, ey - 1, 3, 1, bc)
        c.rect(19, ey - 1, 3, 1, bc)
        c.set(12, ey - 2, bc)
        c.set(19, ey - 2, bc)
    else:
        c.rect(10, ey - 2, 3, 1, bc)
        c.rect(19, ey - 2, 3, 1, bc)
    # румянец
    if p.hair_style != "hood":
        c.set(9, ey + 4, mix(p.skin, "#ff6a8a", 0.45))
        c.set(22, ey + 4, mix(p.skin, "#ff6a8a", 0.45))
    if p.d.get("freckles"):
        for fx in (11, 13, 18, 20):
            c.set(fx, ey + 4, shade(p.skin, -0.25))
    if p.d.get("smudge"):
        c.set(20, ey + 5, "#5a4a4a")
        c.set(21, ey + 5, "#5a4a4a")
    my = y + 15
    if mouth == "small":
        c.rect(15, my, 2, 1, "#8a3a4a")
    elif mouth == "open":
        c.rect(15, my - 1, 2, 2, "#5a1a2a")
        c.set(15, my, "#e86a7a")
    elif mouth == "smile":
        c.set(14, my - 1, "#8a3a4a")
        c.rect(15, my, 2, 1, "#8a3a4a")
        c.set(17, my - 1, "#8a3a4a")
    elif mouth == "wavy":
        c.set(14, my, "#8a3a4a")
        c.set(15, my - 1, "#8a3a4a")
        c.set(16, my, "#8a3a4a")
        c.set(17, my - 1, "#8a3a4a")
    elif mouth == "flat":
        c.rect(14, my, 4, 1, "#8a3a4a")
    # очки, усы, борода
    gl = p.d.get("glasses")
    if gl == "round":
        for ex in (9, 18):
            c.frame(ex, ey - 1, 5, 5, "#e0b64a")
        c.rect(14, ey + 1, 4, 1, "#e0b64a")
    elif gl == "small":
        for ex in (10, 19):
            c.frame(ex - 1, ey, 5, 4, "#c0c0d0")
        c.rect(14, ey + 1, 4, 1, "#c0c0d0")
    must = p.d.get("mustache")
    if must == "curl":
        c.rect(13, my - 1, 6, 1, "#1e1a2e")
        c.set(12, my - 2, "#1e1a2e")
        c.set(19, my - 2, "#1e1a2e")
    elif must == "small":
        c.rect(14, my - 1, 4, 1, p.hair)
    if p.d.get("beard") == "white":
        c.rect(12, my - 1, 8, 1, "#f4f4fa")
        c.rect(11, my, 10, 2, "#f4f4fa")
        c.rect(12, my + 2, 8, 1, "#dcdce8")
        c.rect(15, my, 2, 1, "#8a3a4a")
    if "scarf_mask" in p.acc:
        c.rect(8, y + 13, 16, 4, "#8c2f3f")
        c.rect(8, y + 13, 16, 1, "#b04a5a")
        c.set(12, y + 15, "#6a1f2f")
        c.set(19, y + 15, "#6a1f2f")


def hair_front(c, p, b, back=False):
    y = 4 + b
    h, hd, hl = p.hair, p.hair_d, p.hair_l
    st = p.hair_style
    if st == "neat":
        c.rrect(6, y - 1, 20, 9, 5, h)
        c.rect(6, y + 4, 3, 7, h)
        c.rect(23, y + 4, 3, 6, h)
        if back:
            c.rrect(6, y - 1, 20, 16, 6, h)
            c.rect(8, y + 13, 16, 2, hd)
            c.rect(10, y + 1, 6, 1, hl)
        else:
            c.rect(9, y + 6, 6, 2, h)
            c.rect(16, y + 6, 8, 1, h)
            c.set(15, y + 7, hd)
            c.rect(10, y + 1, 5, 1, hl)
            c.set(19, y + 2, hl)
            c.set(16, y - 2, h)
            c.set(17, y - 3, h)
            c.set(15, y + 4, hd)
    elif st == "bun":
        c.rrect(6, y, 20, 8, 5, h)
        c.rect(6, y + 4, 2, 8, h)
        c.rect(24, y + 4, 2, 8, h)
        c.ellipse(16, y - 1, 4, 3, h)
        c.rect(14, y - 2, 4, 1, hl)
        if back:
            c.rrect(6, y, 20, 15, 6, h)
            c.ellipse(16, y + 6, 5, 4, hl)
            c.ellipse(16, y + 6, 3, 2, h)
        else:
            c.rect(9, y + 5, 14, 2, h)
            c.rect(10, y + 2, 4, 1, hl)
            c.rect(18, y + 2, 4, 1, hl)
    elif st == "bald":
        c.rect(6, y + 7, 3, 6, h)
        c.rect(23, y + 7, 3, 6, h)
        c.set(5, y + 8, h)
        c.set(26, y + 8, h)
        c.rect(11, y + 1, 4, 2, p.skin_l)
        if back:
            c.rect(7, y + 10, 18, 4, h)
    elif st == "ponytail":
        c.rrect(6, y, 20, 9, 5, h)
        c.rect(6, y + 4, 3, 9, h)
        c.rect(23, y + 4, 3, 9, h)
        if back:
            c.rrect(6, y, 20, 15, 6, h)
            c.rect(14, y + 13, 4, 8, h)
            c.rect(15, y + 13, 1, 8, hl)
            c.rect(14, y + 11, 4, 1, "#2fa3a0")
        else:
            c.rect(9, y + 5, 14, 2, h)
            c.set(12, y + 7, h)
            c.set(19, y + 7, h)
            c.rect(24, y + 9, 3, 8, h)
            c.rect(10, y + 2, 4, 1, hl)
    elif st in ("slick", "slick_grey"):
        c.rrect(6, y, 20, 8, 5, h)
        c.rect(6, y + 4, 2, 6, h)
        c.rect(24, y + 4, 2, 6, h)
        if st == "slick_grey":
            c.rect(6, y + 6, 2, 3, "#9a96a8")
            c.rect(24, y + 6, 2, 3, "#9a96a8")
        if back:
            c.rrect(6, y, 20, 14, 6, h)
            c.rect(9, y + 3, 14, 1, hl)
        else:
            c.rect(9, y + 5, 10, 2, h)
            c.rect(19, y + 5, 4, 1, h)
            c.rect(9, y + 2, 12, 1, hl)
    elif st == "messy":
        c.rrect(6, y, 20, 8, 5, h)
        c.rect(6, y + 4, 2, 6, h)
        c.rect(24, y + 4, 2, 6, h)
        for xx in (8, 12, 16, 20):
            c.set(xx, y + 7, h)
            c.set(xx + 1, y + 8, h)
        if back:
            c.rrect(6, y, 20, 15, 6, h)
            for xx in (8, 12, 17, 21):
                c.set(xx, y + 15, h)
    elif st == "long":
        c.rrect(6, y, 20, 9, 5, h)
        c.rect(5, y + 4, 4, 18, h)
        c.rect(23, y + 4, 4, 18, h)
        c.rect(5, y + 4, 1, 18, hd)
        c.rect(26, y + 4, 1, 18, hd)
        if back:
            c.rrect(6, y, 20, 24, 6, h)
            c.vline(12, y + 8, y + 22, hd)
            c.vline(19, y + 8, y + 22, hd)
            c.rect(10, y + 2, 4, 1, hl)
        else:
            c.rect(9, y + 5, 7, 3, h)
            c.rect(17, y + 5, 6, 2, h)
            c.rect(10, y + 2, 4, 1, hl)
            c.set(22, y + 3, "#e8e0f8")
            c.set(21, y + 3, "#b8b0d8")
    elif st == "hood":
        pass


def hat_front(c, p, b, back=False):
    y = 4 + b
    hat = p.d.get("hat")
    hc = p.hat_color
    if hat == "conductor":
        c.rect(6, y - 1, 20, 6, hc)
        c.rect(6, y - 1, 20, 1, shade(hc, 0.25))
        c.rect(6, y + 4, 20, 1, "#c0394b")
        if not back:
            c.rect(7, y + 5, 18, 2, shade(hc, -0.35))
            c.rect(14, y + 1, 4, 3, "#f2c14e")
            c.set(15, y + 2, "#fff4c0")
    elif hat == "tophat":
        c.rect(5, y + 3, 22, 3, hc)
        c.rect(9, y - 9, 14, 13, hc)
        c.rect(9, y - 9, 14, 1, shade(hc, 0.3))
        c.rect(9, y + 0, 14, 2, p.trim)
        c.rect(10, y - 8, 2, 7, shade(hc, 0.18))
    elif hat == "beret":
        c.ellipse(15, y + 1, 10, 4, hc)
        c.rect(8, y + 1, 14, 1, shade(hc, 0.25))
        c.set(16, y - 3, hc)
        c.rect(6, y + 4, 20, 1, shade(hc, -0.3))
    elif hat == "cap":
        c.rrect(6, y - 1, 20, 7, 4, hc)
        c.rect(8, y, 6, 1, shade(hc, 0.25))
        if back:
            c.rect(10, y + 5, 12, 2, shade(hc, -0.3))
        else:
            c.rect(14, y + 1, 4, 2, "#e8954e")
    elif hat == "hood":
        c.rrect(5, y - 1, 22, 20, 8, hc)
        c.rect(5, y + 12, 22, 8, hc)
        c.rect(5, y - 1, 22, 1, shade(hc, 0.2))
        if not back:
            c.rrect(9, y + 5, 14, 13, 5, shade(hc, -0.5))
            c.rect(10, y + 9, 12, 6, p.skin)
            c.rect(10, y + 9, 12, 1, p.skin_d)
            # глаза под капюшоном светятся бледно
            c.rect(11, y + 10, 3, 2, OUTLINE)
            c.rect(18, y + 10, 3, 2, OUTLINE)
            c.set(12, y + 10, p.eyes)
            c.set(19, y + 10, p.eyes)
            c.rect(9, y + 14, 14, 4, "#8c2f3f")
            c.rect(9, y + 14, 14, 1, "#b04a5a")
        else:
            c.vline(16, y + 2, y + 18, shade(hc, -0.25))


def back_items(c, p, b, view):
    """Предметы за спиной (рисуются до корпуса в виде спереди и после — в виде сзади)."""
    if p.has("violin_case"):
        if view == "down":
            c.rect(22, 15 + b, 4, 14, "#5a2e24")
            c.rect(23, 14 + b, 2, 1, "#5a2e24")
        elif view == "up":
            c.rrect(12, 17 + b, 8, 17, 3, "#5a2e24")
            c.rect(13, 18 + b, 6, 1, "#8a4a34")
            c.rect(15, 22 + b, 2, 8, "#3a1e18")
            c.set(16, 25 + b, "#f2c14e")
        else:
            c.rrect(18, 16 + b, 6, 16, 2, "#5a2e24")
            c.rect(19, 17 + b, 1, 13, "#8a4a34")
    if p.has("bindle"):
        if view == "up":
            c.rrect(11, 20 + b, 10, 9, 3, "#8c7a5a")
            c.rect(12, 21 + b, 8, 1, "#b8a47a")
            c.set(14, 24 + b, "#5a4a34")
        elif view == "left":
            c.rrect(18, 20 + b, 6, 9, 2, "#8c7a5a")
    if p.has("cape"):
        cp, ci = p.d["cape"], p.d["cape_in"]
        if view == "up":
            c.rect(8, 20 + b, 16, 14 - b, cp)
            c.rect(8, 33, 16, 1, shade(cp, -0.3))
            c.vline(16, 21 + b, 33, shade(cp, -0.2))
        elif view == "down":
            c.rect(8, 21 + b, 2, 12, ci)
            c.rect(22, 21 + b, 2, 12, ci)
        else:
            c.rect(17, 20 + b, 6, 14 - b, cp)
            c.rect(17, 20 + b, 1, 14 - b, ci)


def front_items(c, p, b, view, pose=None):
    if view == "down":
        if p.has("badge"):
            c.rect(12, 23 + b, 2, 1, "#f2c14e")
            c.set(12, 22 + b, "#fff4c0")
        if p.has("notebook"):
            c.rect(18, 26 + b, 3, 3, "#7a2236")
            c.rect(18, 26 + b, 3, 1, "#a8344e")
        if p.has("camera"):
            c.line(11, 21 + b, 14, 25 + b, "#2a2a2a")
            c.line(20, 21 + b, 17, 25 + b, "#2a2a2a")
            c.rect(13, 25 + b, 6, 4, "#2a2a34")
            c.rect(13, 25 + b, 6, 1, "#5a5a6a")
            c.rect(15, 26 + b, 2, 2, "#8fd8ff")
            c.set(15, 26 + b, "#ffffff")
        if p.has("scarf"):
            c.rect(11, 20 + b, 10, 2, "#c0394b")
            c.rect(17, 22 + b, 2, 4, "#c0394b")
            c.rect(11, 20 + b, 10, 1, "#e05a6a")
        if p.has("wrench"):
            c.rect(20, 28 + b, 2, 5, "#9aa4b4")
            c.rect(19, 32 + b, 4, 2, "#9aa4b4")
            c.set(20, 33 + b, "#5a6474")
        if p.has("book") and not (pose and pose.get("no_hand_items")):
            c.rect(23, 27 + b, 4, 5, "#3f6b8a")
            c.rect(23, 27 + b, 4, 1, "#7fb0d0")
            c.rect(26, 27 + b, 1, 5, "#f4ead8")
        if p.has("briefcase") and not (pose and pose.get("no_hand_items")):
            c.rect(22, 30 + b, 7, 6, "#5a3a24")
            c.rect(22, 30 + b, 7, 1, "#7a5234")
            c.rect(24, 29 + b, 3, 1, "#3a2416")
            c.set(23, 31 + b, "#f2c14e")
            c.set(27, 31 + b, "#f2c14e")
        if p.has("magnifier") and not (pose and pose.get("no_hand_items")):
            magnifier(c, 4, 24 + b, 3)
            c.set(6, 28 + b, "#3b2a24")
            c.set(7, 29 + b, "#3b2a24")
    elif view == "left":
        if p.has("camera"):
            c.rect(9, 25 + b, 4, 4, "#2a2a34")
            c.set(9, 26 + b, "#8fd8ff")
        if p.has("scarf"):
            c.rect(11, 20 + b, 8, 2, "#c0394b")
            c.rect(10, 22 + b, 2, 3, "#c0394b")
        if p.has("wrench"):
            c.rect(16, 28 + b, 2, 5, "#9aa4b4")


def magnifier(c, cx, cy, r, glow=False):
    c.ring(cx + 0.5, cy + 0.5, r + 0.6, r - 0.6, "#c9d2de")
    c.ellipse(cx + 0.5, cy + 0.5, r - 0.6, r - 0.6, "#bfeaff" if glow else "#8fd8ff")
    c.set(cx - 1, cy - 1, "#ffffff")
    if r >= 4:
        c.set(cx - 2, cy - 1, "#ffffff")
        c.set(cx - 1, cy - 2, "#ffffff")
    c.set(cx + r - 1, cy + r - 1, "#7a8494")


def arm_side(c, p, b, swing, behind=False):
    """Одна рука в профиль; swing −2..2 (вперёд — отрицательный)."""
    sleeve = p.shirt if p.top_style == "overalls" else p.top
    if p.top_style == "dress":
        sleeve = p.skin
    col = shade(sleeve, -0.3) if behind else sleeve
    skin = p.skin_d if behind else p.skin
    x = 14 + swing
    c.rect(x, 21 + b, 3, 7, col)
    c.rect(x, 28 + b, 3, 2, skin)
    if p.top_style == "suit" and not behind:
        c.rect(x, 28 + b, 3, 2, "#f4f0ff")


def torso_side(c, p, b):
    y0 = 20 + b
    long_hem = {"longcoat": 34, "dress": 34, "cloak": 35, "raincoat": 32}.get(p.top_style, 31)
    if p.d.get("skirt") and p.top_style == "uniform":
        long_hem = 33
    c.rect(11, y0, 10, long_hem - y0 + 1, p.top)
    c.rect(20, y0, 1, long_hem - y0 + 1, p.top_d)
    c.rect(11, y0, 9, 1, p.top_l)
    c.rect(11, long_hem, 10, 1, p.top_d)
    if p.top_style in ("dress", "cloak", "longcoat") or p.d.get("skirt"):
        c.rect(10, long_hem - 3, 1, 3, p.top_d)
    if p.top_style in ("jacket", "suit", "longcoat", "tweed"):
        c.rect(11, y0 + 1, 2, 4, p.shirt)
        c.set(11, y0 + 1, p.tie)
        c.set(11, y0 + 2, p.tie)
        if p.top_style == "jacket":
            c.rect(12, y0, 3, 1, p.trim)
    if p.top_style == "overalls":
        c.rect(11, y0, 10, 4, p.shirt)
        c.rect(12, y0, 2, 4, p.top)
        c.rect(11, y0 + 8, 10, 1, "#5a3a24")
    if p.top_style == "uniform":
        c.set(12, y0 + 3, p.trim)
        c.set(12, y0 + 6, p.trim)


def head_side(c, p, b, expr="normal", mouth="small"):
    y = 4 + b
    c.rrect(8, y, 17, 17, 6, p.skin)
    c.set(7, y + 11, p.skin)  # нос
    c.set(7, y + 12, p.skin_d)
    c.rect(18, y + 9, 2, 3, p.skin_d)
    ey = y + 10
    if expr == "happy":
        c.rect(10, ey + 1, 3, 1, OUTLINE)
    elif expr in ("narrow", "down", "closed"):
        c.rect(10, ey + 1, 3, 1, OUTLINE)
    else:
        c.rect(10, ey, 3, 3, OUTLINE)
        c.rect(11, ey + 1, 2, 1, p.eyes)
        c.set(10, ey, "#ffffff")
    bc = shade(p.hair, -0.35) if p.hair_style != "bald" else "#b8b8c8"
    c.rect(10, ey - 2, 3, 1, bc)
    if p.hair_style != "hood":
        c.set(12, ey + 4, mix(p.skin, "#ff6a8a", 0.45))
    c.rect(9, y + 15, 2, 1, "#8a3a4a")
    if p.d.get("glasses") == "round":
        c.frame(9, ey - 1, 5, 5, "#e0b64a")
    elif p.d.get("glasses") == "small":
        c.frame(9, ey, 5, 4, "#c0c0d0")
    if p.d.get("mustache") == "curl":
        c.rect(7, y + 14, 4, 1, "#1e1a2e")
        c.set(6, y + 13, "#1e1a2e")
    elif p.d.get("mustache") == "small":
        c.rect(8, y + 14, 3, 1, p.hair)
    if p.d.get("beard") == "white":
        c.rect(8, y + 13, 7, 4, "#f4f4fa")
        c.rect(9, y + 17, 5, 1, "#dcdce8")
    if "scarf_mask" in p.acc:
        c.rect(7, y + 13, 12, 4, "#8c2f3f")


def hair_side(c, p, b, top_only=False):
    y = 4 + b
    if top_only:
        c.rrect(8, y - 1, 18, 9, 5, p.hair)
        c.rect(15, y + 4, 10, 5, p.hair)
        c.rect(11, y + 1, 5, 1, p.hair_l)
        return
    h, hd, hl = p.hair, p.hair_d, p.hair_l
    st = p.hair_style
    if st == "neat":
        c.rrect(8, y - 1, 18, 9, 5, h)
        c.rect(14, y + 4, 12, 10, h)
        c.rect(17, y + 9, 3, 3, p.skin_d)
        c.rect(9, y + 6, 5, 1, h)
        c.rect(11, y + 1, 5, 1, hl)
        c.set(14, y - 2, h)
    elif st == "bun":
        c.rrect(8, y, 18, 8, 5, h)
        c.rect(15, y + 4, 10, 10, h)
        c.ellipse(24, y + 3, 3, 3, h)
        c.rect(17, y + 9, 2, 3, p.skin_d)
        c.rect(11, y + 2, 5, 1, hl)
    elif st == "bald":
        c.rect(17, y + 7, 7, 7, h)
        c.rect(12, y + 1, 4, 2, p.skin_l)
    elif st == "ponytail":
        c.rrect(8, y, 18, 9, 5, h)
        c.rect(15, y + 4, 10, 10, h)
        c.rect(24, y + 6, 4, 10, h)
        c.rect(25, y + 6, 1, 10, hl)
        c.rect(17, y + 9, 2, 3, p.skin_d)
        c.rect(11, y + 2, 5, 1, hl)
    elif st in ("slick", "slick_grey"):
        c.rrect(8, y, 18, 8, 5, h)
        c.rect(15, y + 4, 10, 9, h)
        if st == "slick_grey":
            c.rect(16, y + 7, 3, 3, "#9a96a8")
        c.rect(17, y + 9, 2, 3, p.skin_d)
        c.rect(10, y + 2, 10, 1, hl)
    elif st == "messy":
        c.rrect(8, y, 18, 8, 5, h)
        c.rect(15, y + 4, 10, 10, h)
        c.set(9, y + 7, h)
        c.set(25, y + 13, h)
        c.rect(17, y + 9, 2, 3, p.skin_d)
    elif st == "long":
        c.rrect(8, y, 18, 9, 5, h)
        c.rect(14, y + 4, 12, 20, h)
        c.rect(25, y + 4, 1, 20, hd)
        c.rect(17, y + 9, 2, 3, p.skin_d)
        c.rect(11, y + 2, 5, 1, hl)


def hat_side(c, p, b):
    y = 4 + b
    hat = p.d.get("hat")
    hc = p.hat_color
    if hat == "conductor":
        c.rect(8, y - 1, 18, 6, hc)
        c.rect(8, y - 1, 18, 1, shade(hc, 0.25))
        c.rect(8, y + 4, 18, 1, "#c0394b")
        c.rect(4, y + 5, 7, 2, shade(hc, -0.35))
        c.rect(9, y + 1, 3, 3, "#f2c14e")
    elif hat == "tophat":
        c.rect(6, y + 3, 21, 3, hc)
        c.rect(10, y - 9, 13, 13, hc)
        c.rect(10, y - 9, 13, 1, shade(hc, 0.3))
        c.rect(10, y + 0, 13, 2, p.trim)
    elif hat == "beret":
        c.ellipse(17, y + 1, 10, 4, hc)
        c.rect(9, y + 1, 14, 1, shade(hc, 0.25))
    elif hat == "cap":
        c.rrect(8, y - 1, 18, 7, 4, hc)
        c.rect(22, y + 4, 6, 2, shade(hc, -0.3))
    elif hat == "hood":
        c.rrect(7, y - 1, 21, 21, 8, hc)
        c.rect(6, y + 7, 9, 12, shade(hc, -0.5))
        c.rect(7, y + 9, 7, 6, p.skin)
        c.rect(8, y + 10, 2, 2, OUTLINE)
        c.set(8, y + 10, p.eyes)
        c.rect(6, y + 14, 9, 4, "#8c2f3f")
        c.rect(14, y + 3, 1, 15, shade(hc, 0.15))


# --- сборка кадров ----------------------------------------------------------------------
def frame_down(p, b=0, lift_l=0, lift_r=0, sl=0, sr=0, sit=False, expr="normal", mouth="small",
               extra=None, pose=None):
    c = Canvas(FW, FH)
    sb = 3 if sit else 0
    back_items(c, p, b + sb, "down")
    legs_front(c, p, lift_l, lift_r, b, sit=sit)
    torso_front(c, p, b + sb)
    arms_front(c, p, b + sb, sl, sr, hide_l=pose and pose.get("hide_l"), hide_r=pose and pose.get("hide_r"))
    if p.d.get("hair_style") == "long":
        hair_front(c, p, b + sb)
    head_front(c, p, b + sb, expr, mouth)
    if p.d.get("hair_style") != "long":
        hair_front(c, p, b + sb)
    else:
        # чёлка поверх лица
        y = 4 + b + sb
        c.rrect(6, y, 20, 8, 5, p.hair)
        c.rect(9, y + 5, 7, 3, p.hair)
        c.rect(17, y + 5, 6, 2, p.hair)
        c.rect(10, y + 2, 4, 1, p.hair_l)
        c.set(22, y + 3, "#e8e0f8")
    hat_front(c, p, b + sb)
    front_items(c, p, b + sb, "down", pose)
    if extra:
        extra(c, b + sb)
    return c.outline()


def frame_up(p, b=0, lift_l=0, lift_r=0, sl=0, sr=0, sit=False):
    c = Canvas(FW, FH)
    sb = 3 if sit else 0
    if not sit:
        legs_front(c, p, lift_l, lift_r, b, view="up")
    else:
        c.rect(11, 34, 4, 2, p.shoes)
        c.rect(17, 34, 4, 2, p.shoes)
    torso_front(c, p, b + sb, back=True)
    arms_front(c, p, b + sb, sl, sr)
    c.rrect(7, 4 + b + sb, 18, 17, 6, p.skin_d)
    c.rect(6, 13 + b + sb, 1, 3, p.skin_d)
    c.rect(25, 13 + b + sb, 1, 3, p.skin_d)
    hair_front(c, p, b + sb, back=True)
    if p.hair_style == "bald":
        c.rrect(7, 4 + b + sb, 18, 12, 6, p.skin)
        c.rect(7, 14 + b + sb, 18, 4, p.hair)
    hat_front(c, p, b + sb, back=True)
    back_items(c, p, b + sb, "up")
    if p.has("magnifier"):
        magnifier(c, 4, 25 + b + sb, 3)
    if p.has("briefcase"):
        c.rect(3, 30 + b, 7, 6, "#5a3a24")
        c.rect(3, 30 + b, 7, 1, "#7a5234")
    return c.outline()


def frame_left(p, b=0, phase=0, swing=0, sit=False, expr="normal"):
    c = Canvas(FW, FH)
    sb = 3 if sit else 0
    back_items(c, p, b + sb, "left")
    arm_side(c, p, b + sb, -swing + 2, behind=True)
    legs_side(c, p, phase, b, sit=sit)
    torso_side(c, p, b + sb)
    if p.hair_style == "long":
        hair_side(c, p, b + sb)
    head_side(c, p, b + sb, expr)
    hair_side(c, p, b + sb, top_only=(p.hair_style == "long"))
    hat_side(c, p, b + sb)
    front_items(c, p, b + sb, "left")
    arm_side(c, p, b + sb, swing - 1)
    hx = 14 + swing - 1
    if p.has("magnifier"):
        magnifier(c, hx - 1, 30 + b + sb, 3)
    if p.has("briefcase"):
        c.rect(hx - 2, 30 + b + sb, 7, 6, "#5a3a24")
        c.rect(hx - 2, 30 + b + sb, 7, 1, "#7a5234")
        c.set(hx - 1, 31 + b + sb, "#f2c14e")
    if p.has("book"):
        c.rect(hx - 1, 27 + b + sb, 4, 5, "#3f6b8a")
    return c.outline()


def base_rows(p):
    rows = []
    rows.append([frame_down(p, 0), frame_down(p, 1)])
    rows.append([frame_up(p, 0), frame_up(p, 1)])
    rows.append([frame_left(p, 0), frame_left(p, 1)])
    rows.append([
        frame_down(p, 0),
        frame_down(p, -1, lift_l=1, sl=1, sr=-1),
        frame_down(p, 0),
        frame_down(p, -1, lift_r=1, sl=-1, sr=1),
    ])
    rows.append([
        frame_up(p, 0),
        frame_up(p, -1, lift_l=1, sl=-1, sr=1),
        frame_up(p, 0),
        frame_up(p, -1, lift_r=1, sl=1, sr=-1),
    ])
    rows.append([
        frame_left(p, 0, phase=0, swing=0),
        frame_left(p, -1, phase=1, swing=-2),
        frame_left(p, 0, phase=2, swing=0),
        frame_left(p, -1, phase=3, swing=2),
    ])
    rows.append([frame_down(p, 0, sit=True), frame_down(p, 1, sit=True)])
    rows.append([frame_up(p, 0, sit=True), frame_up(p, 1, sit=True)])
    rows.append([frame_left(p, 0, sit=True), frame_left(p, 1, sit=True)])
    rows.append([frame_down(p, 0, mouth="open", sr=-2), frame_down(p, 0, mouth="small", sr=0)])
    return rows


def hero_rows(p):
    nh = {"no_hand_items": True}
    rows = []

    def lens_at(x, y, r=3, glow=False, sparkle=False):
        def f(c, b):
            c.set(x + r, y + r + 1, "#3b2a24")
            c.set(x + r + 1, y + r + 2, "#3b2a24")
            magnifier(c, x, y + b, r, glow)
            if sparkle:
                for dx, dy in ((-r - 2, 0), (r + 2, 0), (0, -r - 2)):
                    c.set(x + dx, y + b + dy, "#fff4c0")
                c.set(x - r - 3, y + b, "#f2c14e")
        return f

    def raised_hand(x, y):
        def f(c, b):
            c.rect(x, y + b, 3, 2, p.skin)
        return f

    def sleeve_up(x, y):
        def f(c, b):
            c.rect(x, y + b, 3, 22 - y, p.top)
            c.rect(x, y + b, 1, 22 - y, p.top_d)
        return f

    def combo(*fs):
        def f(c, b):
            for g in fs:
                g(c, b)
        return f

    # осмотр: поднимает лупу к глазу
    rows.append([
        frame_down(p, 1, expr="normal", pose=dict(nh, hide_l=True), extra=combo(lens_at(7, 20), raised_hand(8, 23))),
        frame_down(p, 2, expr="wide", pose=dict(nh, hide_l=True), extra=combo(raised_hand(12, 21), lens_at(11, 15, 4, True))),
        frame_down(p, 2, expr="wide", pose=dict(nh, hide_l=True), extra=combo(raised_hand(12, 21), lens_at(11, 15, 4, True, True))),
    ])
    # взаимодействие: тянется руками вперёд
    def reach(c, b):
        c.rect(12, 30 + b, 3, 2, p.skin)
        c.rect(17, 30 + b, 3, 2, p.skin)
    rows.append([
        frame_down(p, 1, pose=dict(nh, hide_l=True, hide_r=True), extra=reach),
        frame_down(p, 0, pose=nh),
    ])

    # запись в блокнот
    def notebook(px, py):
        def f(c, b):
            c.rect(12, 25 + b, 7, 6, "#7a2236")
            c.rect(13, 25 + b, 5, 5, "#f4ead8")
            c.hline(14, 16, 27 + b, "#9a9ab0")
            c.hline(14, 17, 28 + b, "#9a9ab0")
            c.rect(px, py + b, 1, 3, "#f2c14e")
            c.set(px, py + 3 + b, "#3a2a24")
        return f
    rows.append([
        frame_down(p, 1, expr="down", pose=dict(nh, hide_l=True, hide_r=True), extra=notebook(17, 24)),
        frame_down(p, 1, expr="down", pose=dict(nh, hide_l=True, hide_r=True), extra=notebook(15, 25)),
        frame_down(p, 1, expr="down", pose=dict(nh, hide_l=True, hide_r=True), extra=notebook(16, 24)),
    ])
    # подозрение: бровь вверх, рука у подбородка
    def chin(c, b):
        c.line(23, 22 + b, 20, 20 + b, p.top)
        c.line(23, 23 + b, 20, 21 + b, p.top)
        c.line(22, 23 + b, 19, 21 + b, p.top)
        c.rect(17, 19 + b, 3, 2, p.skin)
    rows.append([
        frame_down(p, 0, expr="brow", mouth="flat", pose=dict(hide_r=True), extra=chin),
        frame_down(p, 1, expr="brow", mouth="flat", pose=dict(hide_r=True), extra=chin),
    ])
    # находка: лупа над головой, искры
    rows.append([
        frame_down(p, -1, expr="wide", mouth="smile", pose=dict(nh, hide_l=True), extra=combo(sleeve_up(7, 14), lens_at(4, 8, 4, True), raised_hand(6, 13))),
        frame_down(p, -1, expr="happy", mouth="smile", pose=dict(nh, hide_l=True), extra=combo(sleeve_up(7, 13), lens_at(4, 7, 4, True, True), raised_hand(6, 12))),
    ])

    # ошибка: голова опущена, капля пота
    def sweat(c, b):
        c.set(25, 7 + b, "#8fd8ff")
        c.rect(25, 8 + b, 2, 2, "#8fd8ff")
        c.set(25, 8 + b, "#ffffff")
    rows.append([
        frame_down(p, 1, expr="down", mouth="wavy", extra=sweat),
        frame_down(p, 2, expr="down", mouth="wavy", extra=sweat),
    ])

    # задержание: показывает значок
    def badge(c, b):
        c.rect(22, 25 + b, 4, 3, p.top)
        c.rect(25, 24 + b, 2, 2, p.skin)
        c.poly([(26, 20 + b), (30, 23 + b), (29, 28 + b), (23, 28 + b), (22, 23 + b)], "#f2c14e")
        c.set(26, 23 + b, "#fff4c0")
        c.set(25, 22 + b, "#fff4c0")
        c.rect(25, 25 + b, 2, 1, "#c08a2a")
    rows.append([
        frame_down(p, 0, expr="narrow", mouth="flat", pose=dict(nh, hide_r=True), extra=badge),
        frame_down(p, 1, expr="normal", mouth="smile", pose=dict(nh, hide_r=True), extra=combo(badge, lambda c, b: c.set(30, 20 + b, "#ffffff"))),
    ])

    # победа: кулак вверх
    def fist(c, b):
        c.rect(22, 12 + b, 3, 9, p.top)
        c.rect(22, 10 + b, 3, 3, p.skin)
    rows.append([
        frame_down(p, 0, expr="happy", mouth="smile", pose=dict(hide_r=True), extra=fist),
        frame_down(p, -1, expr="happy", mouth="open", pose=dict(hide_r=True), extra=fist),
    ])
    return rows


# --- портреты 64×64 ---------------------------------------------------------------------
def portrait(p, expr="normal"):
    """Портрет-бюст: рисуем кадр «вниз» и укрупняем голову ×2 с доработкой деталей."""
    base = frame_down(p, 0, expr=expr, mouth={"smile": "smile", "happy": "smile", "wide": "open",
                                               "down": "wavy", "brow": "flat"}.get(expr, "small"),
                      pose={"no_hand_items": True})
    c = Canvas(64, 64)
    # берём верхнюю часть кадра (голова + плечи) 28×27 и масштабируем ×2
    src = base.sub(2, -6, 28, 32)
    big = src.scaled(2)
    c.blit(big, 4, 0)
    # блики в глазах и мягкая подсветка щеки (детали в полном разрешении)
    return c


def build_sheet(cid, p, hero=False):
    rows = base_rows(p)
    if hero:
        rows += hero_rows(p)
    sheet = grid(rows)
    sheet.save(f"characters/{cid}.png")
    return sheet


def main():
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    for cid, d in CHARACTERS.items():
        p = P(d)
        build_sheet(cid, p, hero=(cid == "detective"))
        exprs = ["normal"]
        if cid == "detective":
            exprs = ["normal", "brow", "wide", "smile", "down", "happy"]
        else:
            exprs = ["normal", "wide"]
        for e in exprs:
            portrait(p, e).save(f"portraits/{cid}_{e}.png")
    for oid, over in OUTFITS.items():
        d = dict(CHARACTERS["detective"])
        d.update(over)
        build_sheet(oid, P(d), hero=True)
        portrait(P(d), "normal").save(f"portraits/{oid}_normal.png")
    layout = {"frame_w": FW, "frame_h": FH, "foot_y": 38, "rows": {}}
    for i, (name, n, fps, loop) in enumerate(ROWS_BASE + ROWS_HERO):
        layout["rows"][name] = {"row": i, "frames": n, "fps": fps, "loop": loop}
    with open(os.path.join(ROOT, "data", "sprite_layout.json"), "w") as f:
        json.dump(layout, f, ensure_ascii=False, indent=1)
    print("  data/sprite_layout.json")


if __name__ == "__main__":
    main()
