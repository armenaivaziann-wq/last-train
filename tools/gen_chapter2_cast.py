#!/usr/bin/env python3
"""Пассажиры второй главы (перекраска готовых листов, чтобы стиль совпадал):
  gleb  — охотник Глеб Сыч: зелёная охотничья куртка (из листа Роберта);
  lidia — травница Лидия Мрак: тёмно-лиловое платье, бледная кожа (из листа Веры).

Запуск:  python3 tools/gen_chapter2_cast.py
"""
from pixelart import read_png

CAST = {
    "gleb": ("robert", {
        "#7a4a2a": "#4e5a2c", "#5f3a2c": "#3a4422", "#5a3a24": "#3a4422", "#623c2c": "#3e4826",
        "#a8703f": "#6e7a3c", "#7a5234": "#566232", "#3a3036": "#5a3422", "#2f3f6b": "#8a3a22",
    }),
    "lidia": ("vera", {
        "#7a1f3a": "#2e1f4a", "#c0394b": "#5a3a8a", "#5d1a37": "#22163a", "#912e43": "#43306a",
        "#581a36": "#1e1434", "#8e2d43": "#40306a", "#8a3a4a": "#4a3a6a", "#a25f69": "#6a5a8a",
        "#f6d2bc": "#ece2ea", "#ceafa3": "#c4b6cc", "#ffd27a": "#7fd18a",
    }),
}

for new, (src, mapping) in CAST.items():
    for rel in ("characters/{}.png", "portraits/{}_normal.png", "portraits/{}_wide.png", "bodies/{}.png", "bodies/{}_outline.png"):
        c = read_png("../assets/sprites/" + rel.format(src))
        c.recolor(mapping)
        c.save(rel.format(new))
