#!/usr/bin/env python3
"""Ассеты места преступления (казуальный пиксель-арт, без натурализма): небольшие тёмно-красные
пятна, обрывок ткани, следы обуви, билет на полу, рассыпанный сахар, опрокинутая чашка.

Запуск:  python3 tools/gen_crime.py
"""
from pixelart import Canvas, noise_rng, shade

BLOOD = "#6e1626"
BLOOD_L = "#9a2438"


def blood(i):
    rng = noise_rng(100 + i)
    c = Canvas(18, 10)
    for _ in range(5):
        x, y = rng.uniform(5, 13), rng.uniform(3, 7)
        c.ellipse(x, y, rng.uniform(2, 4), rng.uniform(1.4, 2.4), BLOOD)
    c.set(6, 3, BLOOD_L)
    c.set(7, 3, BLOOD_L)
    if i == 1:
        c.set(16, 8, BLOOD)
        c.set(2, 1, BLOOD)
    return c


def main():
    for i in range(3):
        blood(i).save(f"crime/blood_{i}.png")
    # обрывок коричневой ткани с пуговицей
    c = Canvas(12, 10)
    c.poly([(1, 2), (9, 0), (11, 6), (6, 9), (2, 8)], "#7a4a2a")
    c.line(2, 3, 9, 1, "#a8703f")
    c.ellipse(6, 5, 1.6, 1.6, "#d9a441")
    c.outline()
    c.save("crime/fabric_scrap.png")
    # цепочка следов обуви
    c = Canvas(40, 16)
    for i, (x, y) in enumerate(((3, 10), (12, 4), (21, 10), (30, 4))):
        col = (60, 40, 70, 170)
        c.ellipse(x + 2, y + 1.5, 2.6, 1.6, col, blend=True)
        c.ellipse(x + 5.5, y + 1.5, 1.3, 1.3, col, blend=True)
    c.save("crime/footprints.png")
    # билет на полу
    c = Canvas(12, 8)
    c.rect(0, 0, 12, 8, "#ffd27a")
    c.rect(0, 0, 12, 2, "#c0394b")
    c.vline(8, 2, 7, "#c0882a")
    c.outline()
    c.save("crime/floor_ticket.png")
    # рассыпанный сахар
    rng = noise_rng(7)
    c = Canvas(18, 10)
    for _ in range(26):
        c.set(rng.randint(1, 16), rng.randint(1, 8), rng.choice(("#ffffff", "#e8e4f4")))
    c.save("crime/sugar.png")
    # опрокинутая чашка с кофе
    c = Canvas(14, 10)
    c.ellipse(9, 6, 4.5, 2.5, "#5a3020")
    c.ellipse(5, 5, 3, 2.4, "#ffffff")
    c.ellipse(5, 5, 1.6, 1.2, "#a0602a")
    c.outline()
    c.save("crime/cup_spill.png")


if __name__ == "__main__":
    main()
