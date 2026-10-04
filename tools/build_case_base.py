#!/usr/bin/env python3
"""Собирает data/cases/_base.json — «базовый состав» для генератора дел кампании:
поезд, расписания пассажиров, документы, багаж и секреты невиновных из дела 1, но без улик
конкретного преступления (их генератор добавляет сам для каждого злодея и seed).

Запуск:  python3 tools/build_case_base.py
"""
import collections
import copy
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OD = collections.OrderedDict

src = json.load(open(os.path.join(ROOT, "data/cases/case_01.json")), object_pairs_hook=OD)
b = OD()
for k in ("carriages", "ground", "history_start", "start", "arrival", "seconds_per_minute", "player_start",
          "min_key_clues", "max_wrong", "verifications", "rewards", "suspects", "barks", "luggage_world",
          "wrong_reactions", "events", "murders"):
    b[k] = copy.deepcopy(src[k])

# Расписания: убираем ночную вылазку Хейла из дела 1 — в сгенерированном деле её нет.
b["schedules"] = copy.deepcopy(src["schedules"])
b["schedules"]["robert"] = [["01:20", "bay3_l1", "read"], ["01:30", "rb3_l1", "eat"], ["01:35:30", "rest_coffee", "coffee"],
                            ["01:36:30", "rb3_l1", "eat"], ["02:02", "bay3_l1", "read"], ["02:07", "vest_window", "window"],
                            ["02:10", "vest_door", "wait"]]
b["schedules"]["agata"] = [e if e[2] != "shocked" else [e[0], e[1], "write"] for e in b["schedules"]["agata"]]

# Документы: без улик преступления дела 1.
docs = copy.deepcopy(src["documents"])
docs["robert"].pop("hotspots", None)
docs["robert"].pop("on_open", None)
docs["robert"]["hotspots"] = []
b["documents"] = docs

lug = copy.deepcopy(src["luggage"])
for it in lug["klara"]["items"]:
    if it["name"] == "Фотоаппарат":
        it.pop("hotspot", None)
        it["text"] = "Последние кадры — огни ночных станций и пассажиры за чаем."
lug["robert"]["items"] = [it for it in lug["robert"]["items"] if it.get("requires_upgrade") != "baggage"]
b["luggage"] = lug

b["objects"] = OD([
    ("obj_register", {"title": "Журнал вагона", "kind": "document", "fields": [["Раздел", "Постоянные пассажиры"],
        ["Состояние", "Все страницы на месте"], ["Последняя запись ремонта", "Дж. Гаек, 01:35"]], "hotspots": []}),
    ("obj_coffee", {"title": "Кофейный автомат", "kind": "document", "fields": [["Последний чек", "01:36"],
        ["Напиток", "Кофе двойной"], ["Оплата", "Жетон: вагон 1"]], "hotspots": []}),
    ("obj_trash", {"title": "Мусорная корзина", "kind": "item", "text": "Салфетки и фантики. Ничего интересного.", "hotspots": []}),
    ("obj_rack", copy.deepcopy(src["objects"]["obj_rack"])),
])

keep_clues = ["d_louis_name", "d_klara_press", "d_tikhon_noticket", "d_nina_lessons", "d_john_pass", "i_prof_book",
              "i_louis_rabbit", "i_robert_photo", "i_john_key", "i_nina_note", "i_tikhon_poems", "s_louis_stage",
              "s_klara_secret", "s_tikhon_confess", "s_agata_regular", "s_agata_tea", "s_agata_daughter",
              "s_agata_tikhon", "s_agata_john", "s_klara_louis", "s_john_coffee", "s_nina_liza", "s_robert_intro"]
# Улики убийств создаются во время игры для каждой жертвы (MurderDirector) — в базе их нет.
b["clues"] = OD((k, copy.deepcopy(src["clues"][k])) for k in keep_clues)
# В деле 1 у этих улик есть время/связи с конкретным преступлением — делаем нейтральными.
b["clues"]["s_john_coffee"]["points_to"] = []

keep_topics = {
    "agata": ["regulars", "robert", "tikhon", "john_key"], "robert": ["who"], "professor": ["who"],
    "klara": ["who", "press", "louis"], "louis": ["who", "name", "rabbit"], "john": ["who", "coffee", "key"],
    "nina": ["who", "liza"], "tikhon": ["who", "ticket"], "vera": ["who", "robert"], "orlov": ["who"], "mark": ["who"],
}
dl = OD()
for who, d in src["dialogues"].items():
    dl[who] = OD([("greet", d["greet"]), ("topics", [copy.deepcopy(t) for t in d["topics"] if t["id"] in keep_topics.get(who, [])])])
b["dialogues"] = dl
b["deductions"] = []
b["key_clues"] = []
b["truth"] = []
b["camera_clues"] = []

json.dump(b, open(os.path.join(ROOT, "data/cases/_base.json"), "w"), ensure_ascii=False, indent=1)
print("  data/cases/_base.json")
