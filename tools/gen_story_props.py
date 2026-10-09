#!/usr/bin/env python3
"""Предметы авторских дел кампании: бокал, тележка с напитками, дорожный сундук, ящик
механика, записка, ключ, перерезанный трос, кукла-марионетка, пузырёк, карманные часы,
бирка, свисток, лампа.

Запуск:  python3 tools/gen_story_props.py
"""
from pixelart import Canvas, noise_rng, shade


def glass():
    c = Canvas(8, 12)
    c.rect(2, 0, 4, 6, "#cfe6f4")
    c.rect(3, 2, 2, 3, "#c0394b")
    c.vline(4, 6, 9, "#cfe6f4")
    c.hline(1, 6, 10, "#cfe6f4")
    c.outline()
    return c


def cart():
    c = Canvas(30, 26)
    c.rect(2, 8, 26, 3, "#8a6a4a")
    c.rect(2, 18, 26, 3, "#8a6a4a")
    c.vline(3, 8, 22, "#5a4030")
    c.vline(26, 8, 22, "#5a4030")
    for i, col in enumerate(("#c0394b", "#5ab8f0", "#e8c060", "#7fd18a")):
        c.rect(5 + i * 5, 3, 3, 5, col)
        c.rect(5 + i * 5, 2, 3, 1, "#cfe6f4")
    c.rect(6, 15, 4, 3, "#cfe6f4")
    c.rect(14, 15, 4, 3, "#cfe6f4")
    c.ellipse(5, 23, 2, 2, "#222222")
    c.ellipse(25, 23, 2, 2, "#222222")
    c.outline()
    return c


def trunk():
    c = Canvas(30, 20)
    c.rect(1, 4, 28, 15, "#6a4a2a")
    c.rect(1, 2, 28, 4, "#7d5a34")
    c.hline(1, 28, 6, "#3e2a18")
    for x in (6, 23):
        c.vline(x, 2, 18, "#b08a3a")
    c.rect(13, 7, 4, 4, "#d9a441")
    c.set(15, 9, "#222222")
    for x in range(3, 28, 4):
        c.set(x, 14, "#3e2a18")
    c.outline()
    return c


def toolbox():
    c = Canvas(18, 12)
    c.rect(1, 4, 16, 7, "#b8402e")
    c.rect(1, 3, 16, 2, "#d9583e")
    c.frame(6, 0, 6, 4, "#555555")
    c.hline(1, 16, 8, "#7a2a1e")
    c.outline()
    return c


def note():
    c = Canvas(10, 8)
    c.rect(0, 0, 10, 8, "#efe6c8")
    for y in (2, 4, 6):
        c.hline(1, 8, y, "#7a6a8a")
    c.set(9, 0, "#c8bc98")
    c.outline()
    return c


def key():
    c = Canvas(12, 6)
    c.ring(3, 3, 2.6, 1.2, "#d9a441")
    c.hline(5, 11, 3, "#d9a441")
    c.vline(9, 3, 5, "#d9a441")
    c.vline(11, 3, 5, "#d9a441")
    c.outline()
    return c


def cable():
    c = Canvas(20, 10)
    c.line(0, 6, 8, 4, "#444444")
    c.line(12, 4, 19, 7, "#444444")
    for x, y in ((8, 3), (8, 5), (9, 4), (11, 3), (11, 5), (12, 5)):
        c.set(x, y, "#d9a441")
    c.outline()
    return c


def puppet():
    c = Canvas(12, 18)
    c.vline(3, 0, 5, "#cfe6f4")
    c.vline(8, 0, 5, "#cfe6f4")
    c.ellipse(5.5, 7, 2.5, 2.5, "#f0c8a0")
    c.rect(3, 9, 6, 6, "#7a3a8a")
    c.vline(4, 15, 17, "#222222")
    c.vline(7, 15, 17, "#222222")
    c.set(4, 7, "#222222")
    c.set(7, 7, "#222222")
    c.outline()
    return c


def vial():
    c = Canvas(6, 10)
    c.rect(2, 0, 2, 2, "#8a6a4a")
    c.rect(1, 2, 4, 7, "#cfe6f4")
    c.rect(1, 5, 4, 4, "#7fd18a")
    c.outline()
    return c


def watch():
    c = Canvas(10, 12)
    c.ring(5, 7, 4, 3, "#d9a441")
    c.ellipse(5, 7, 3, 3, "#efe6c8")
    c.vline(5, 5, 7, "#222222")
    c.hline(5, 6, 7, "#222222")
    c.rect(4, 1, 2, 2, "#d9a441")
    c.outline()
    return c


def tag():
    c = Canvas(10, 7)
    c.poly([(2, 0), (9, 0), (9, 6), (2, 6), (0, 3)], "#e8c060")
    c.set(2, 3, "#222222")
    c.hline(4, 8, 2, "#7a5a2a")
    c.hline(4, 7, 4, "#7a5a2a")
    c.outline()
    return c


def drag_marks():
    c = Canvas(44, 10)
    for x in range(2, 42):
        c.blend(x, 3, (60, 40, 70, 130))
        c.blend(x, 7, (60, 40, 70, 130))
    return c


def powder():
    rng = noise_rng(31)
    c = Canvas(16, 10)
    for _ in range(30):
        c.set(rng.randint(1, 14), rng.randint(1, 8), rng.choice(("#f4f0ff", "#d8d0f0", "#e8e0ff")))
    return c


def frost():
    rng = noise_rng(55)
    c = Canvas(22, 18)
    for _ in range(40):
        x, y = rng.randint(1, 20), rng.randint(1, 16)
        c.blend(x, y, (220, 240, 255, 200))
    for cx, cy in ((7, 7), (15, 10)):
        for d in range(1, 5):
            for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d), (d - 1, d - 1), (1 - d, d - 1)):
                c.blend(cx + dx, cy + dy, (235, 248, 255, 230 - d * 30))
    return c


def knot():
    c = Canvas(10, 10)
    c.line(1, 8, 8, 1, "#7fd18a")
    c.line(1, 1, 8, 8, "#5a3a8a")
    c.ellipse(4.5, 4.5, 2, 2, "#6a4c2c")
    c.set(0, 9, "#7fd18a")
    c.set(9, 9, "#5a3a8a")
    c.outline()
    return c


def fur():
    rng = noise_rng(77)
    c = Canvas(14, 10)
    for _ in range(22):
        x, y = rng.randint(1, 11), rng.randint(2, 8)
        c.line(x, y, x + rng.randint(1, 3), y - rng.randint(0, 2), rng.choice(("#8a8a8a", "#6a6a6a", "#5a4a3a")))
    return c


def main():
    glass().save("crime/glass.png")
    cart().save("props/drink_cart.png")
    trunk().save("props/trunk.png")
    toolbox().save("crime/toolbox.png")
    note().save("crime/note.png")
    key().save("crime/key.png")
    cable().save("crime/cable.png")
    puppet().save("crime/puppet.png")
    vial().save("crime/vial.png")
    watch().save("crime/watch.png")
    tag().save("crime/tag.png")
    drag_marks().save("crime/drag_marks.png")
    powder().save("crime/powder.png")
    frost().save("crime/frost.png")
    knot().save("crime/knot.png")
    fur().save("crime/fur.png")


if __name__ == "__main__":
    main()
