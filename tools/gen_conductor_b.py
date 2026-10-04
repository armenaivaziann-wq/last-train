#!/usr/bin/env python3
"""Сменная проводница Зоя (дело 8 «Два проводника»): та же форма, что у Агаты, но тёмные
волосы и голубой шарф вместо красного — издалека их легко спутать, вблизи — нет.

Запуск:  python3 tools/gen_conductor_b.py
"""
from pixelart import read_png

MAP = {
    "#c9c9d8": "#5a3a2a", "#c0c0d0": "#4a2e22", "#d9d6d7": "#6e4a36", "#8b889d": "#3a241a",
    "#c0394b": "#3f8fc0", "#e05a6a": "#5ab8f0",
}

for rel in ("characters/{}.png", "portraits/{}_normal.png", "portraits/{}_wide.png", "bodies/{}.png", "bodies/{}_outline.png"):
    c = read_png("../assets/sprites/" + rel.format("agata"))
    c.recolor(MAP)
    c.save(rel.format("zoya"))
