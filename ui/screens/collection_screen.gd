extends GameScreen
## Коллекции: пассажиры, бестиарий, достижения, гардероб, архив дел.

const TABS: Array = [["people", "Пассажиры"], ["monsters", "Бестиарий"], ["achievements", "Достижения"], ["wardrobe", "Гардероб"], ["archive", "Архив дел"]]

var _tab: String = "people"
var _content: VBoxContainer
var _buttons: Dictionary = {}


func build(_args: Dictionary) -> void:
	var p := Ui.panel()
	var col := Ui.vbox(12)
	col.add_child(Ui.header("Коллекции", "collection", close))
	var tabs := Ui.hbox(8)
	for t: Array in TABS:
		var b := Ui.button(t[1], "", "TabButton", func() -> void: _switch(t[0]), 52)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_buttons[t[0]] = b
	col.add_child(tabs)
	_content = Ui.vbox(10)
	col.add_child(Ui.scroll(_content))
	p.add_child(col)
	safe_margin(p, 30, 18)
	_switch(_tab)


func refresh() -> void:
	_switch(_tab)


func _switch(tab: String) -> void:
	_tab = tab
	for k: String in _buttons:
		_buttons[k].set_pressed_no_signal(k == tab)
	Ui.clear(_content)
	match tab:
		"people":
			var g := Ui.grid(4, 12)
			for id: String in Db.characters:
				if id == "detective":
					continue
				var met: bool = ProgressionManager.has_met(id)
				var card := Ui.panel("CardPanel")
				card.custom_minimum_size = Vector2(270, 0)
				var v := Ui.vbox(6)
				var t := Ui.tex(Db.portrait(id), 96)
				if not met:
					t.modulate = Color(0, 0, 0, 0.85)
				v.add_child(t)
				v.add_child(Ui.label(Db.char_name(id) if met else "???", "", 20))
				v.add_child(Ui.label(str(Db.character(id).get("description", "")) if met else "Познакомьтесь в рейсе.", "DimLabel", 16, true))
				card.add_child(v)
				g.add_child(card)
			_content.add_child(g)
		"monsters":
			# Бестиарий злодеев кампании: истинная форма, способность, контрмера, маскировки.
			for mid: String in Db.monsters:
				var m: Dictionary = Db.monster(mid)
				if m.get("legacy", false):
					continue
				var caught: int = ProgressionManager.monster_caught(mid)
				var card := Ui.panel("CardPanel")
				var h := Ui.hbox(16)
				var t := Ui.tex(Db.villain_portrait(mid), 120)
				if caught == 0:
					t.modulate = Color(0, 0, 0, 0.85)
				h.add_child(t)
				var v := Ui.vbox(4)
				v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				v.add_child(Ui.label(str(m["name"]) if caught > 0 else "??? — " + str(m.get("short", "")), "SubHeaderLabel", 24, true))
				if caught > 0:
					v.add_child(Ui.label(str(m.get("description", m.get("short", ""))), "", 18, true))
					v.add_child(Ui.label("Способность: " + str(m.get("ability", "")), "", 17, true))
					v.add_child(Ui.label("Контрмера: " + str(m.get("counter", "")), "GoldLabel", 17, true))
					v.add_child(Ui.label("Признаки: " + "; ".join(PackedStringArray(m.get("signs", []))), "DimLabel", 16, true))
					v.add_child(Ui.label(str(m.get("bestiary", "")) + "  Поймано: %d" % caught, "SmallLabel", 16, true))
					var dg: Array = ProgressionManager.disguises(mid)
					if not dg.is_empty():
						var row := Ui.hbox(6)
						row.add_child(Ui.label("Маскировки:", "SmallLabel", 16))
						for c in dg:
							var ct := Ui.tex(Db.portrait(str(c)), 40)
							ct.tooltip_text = Db.char_name(str(c))
							ct.mouse_filter = Control.MOUSE_FILTER_PASS
							row.add_child(ct)
						v.add_child(row)
				else:
					v.add_child(Ui.label("Поймайте этого злодея, чтобы открыть запись.", "DimLabel", 18))
				h.add_child(v)
				card.add_child(h)
				_content.add_child(card)
		"achievements":
			for a: Dictionary in Db.prog_list("achievements"):
				var prog: int = mini(ProgressionManager.stat(str(a["stat"])), int(a["goal"]))
				var h := Ui.hbox(12)
				h.add_child(Ui.icon("medal", 40))
				var v := Ui.vbox(2)
				v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var reward_text: String = ""
				if a.has("cosmetic"):
					reward_text = "  · награда: " + str(Db.prog_item("cosmetics", str(a["cosmetic"])).get("name", ""))
				v.add_child(Ui.label("%s — %s%s" % [a["name"], a["text"], reward_text], "", 19, true))
				v.add_child(Ui.progress(prog, int(a["goal"]), "PurpleBar", 12))
				h.add_child(v)
				if ProgressionManager.achievement_claimed(a["id"]):
					h.add_child(Ui.chip("Получено", UiTheme.SUCCESS, "check"))
				else:
					var b := Ui.button("+%d" % int(a["crystals"]), "crystal", "PrimaryButton", func() -> void:
						ProgressionManager.claim_achievement(a["id"])
						refresh(), 50)
					b.disabled = prog < int(a["goal"])
					h.add_child(b)
				_content.add_child(h)
		"wardrobe":
			_content.add_child(Ui.label("Кристаллы: %d. Серый пиджак и лупа — узнаваемый образ детектива." % EconomyManager.crystals(), "DimLabel", 18, true))
			for c: Dictionary in Db.prog_list("cosmetics"):
				var h := Ui.hbox(12)
				h.add_child(Ui.icon("wardrobe" if c["kind"] == "outfit" else "magnifier", 40))
				var l := Ui.label(str(c["name"]), "", 20)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(l)
				var id: String = str(c["id"])
				var slot: String = "outfit" if c["kind"] == "outfit" else "lens"
				if SaveManager.profile["cosmetics"].get(slot) == id:
					h.add_child(Ui.chip("Надето", UiTheme.SUCCESS, "check"))
				elif ProgressionManager.owns_cosmetic(id):
					h.add_child(Ui.button("Надеть", "check", "CyanButton", func() -> void:
						ProgressionManager.equip_cosmetic(id)
						refresh(), 50))
				else:
					var b := Ui.button("%d" % int(c["cost"]), "crystal", "PrimaryButton", func() -> void:
						ProgressionManager.buy_cosmetic(id)
						refresh(), 50)
					b.disabled = not EconomyManager.can_afford("crystals", int(c["cost"]))
					h.add_child(b)
				_content.add_child(h)
		"archive":
			var arch: Array = SaveManager.profile["archive"]
			if arch.is_empty():
				_content.add_child(Ui.label("Завершённых дел пока нет.", "DimLabel", 20))
			for e: Dictionary in arch:
				_content.add_child(Ui.label("%s · «%s» · %s · улик: %d · ошибок: %d · +%d монет" % [e["date"], e["title"],
					"раскрыто" if e["solved"] else "не раскрыто", int(e["clues"]), int(e["mistakes"]), int(e["coins"])], "", 19, true))
