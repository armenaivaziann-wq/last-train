extends Node
## Игровые данные (JSON в res://data) и кэш ресурсов: иконки, портреты, анимации персонажей.
## Логика игры обращается к данным только через этот узел.

const DATA_DIR: String = "res://data/"
const SPRITES: String = "res://assets/sprites/"

var characters: Dictionary = {}
var monsters: Dictionary = {}
var progression: Dictionary = {}
var sprite_layout: Dictionary = {}
var campaign: Dictionary = {}

var _cases: Dictionary = {}
var _layouts: Dictionary = {}
var _textures: Dictionary = {}
var _frames: Dictionary = {}


func _ready() -> void:
	characters = load_json("characters.json")
	monsters = load_json("monsters.json")
	progression = load_json("progression.json")
	sprite_layout = load_json("sprite_layout.json")
	campaign = load_json("campaign.json")


func load_json(rel_path: String) -> Dictionary:
	var path: String = DATA_DIR + rel_path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Нет файла данных: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Ошибка JSON: " + path)
	return {}


func case_data(case_id: String) -> Dictionary:
	if not _cases.has(case_id):
		_cases[case_id] = load_json("cases/%s.json" % case_id)
	return _cases[case_id]


func has_case(case_id: String) -> bool:
	return case_id != "" and FileAccess.file_exists(DATA_DIR + "cases/%s.json" % case_id)


## Данные дела для запуска: статичный файл (с выбором варианта по seed) или дело,
## собранное генератором из шаблона злодея ("gen:<уровень или злодей>"). Всегда копия.
func resolve_case(case_ref: String, seed_value: int) -> Dictionary:
	if case_ref.begins_with("gen:"):
		return CaseGenerator.generate(case_ref.substr(4), seed_value)
	var d: Dictionary = case_data(case_ref).duplicate(true)
	# Авторское дело кампании: своя история поверх общего поезда.
	if d.has("extends"):
		d = CaseBuilder.extend(case_data(str(d["extends"])), d)
	CaseVariants.apply(d, seed_value)
	if d.has("excursions") or d.has("auto_cameras"):
		CaseBuilder.finish(d)
	return d


# --- кампания -------------------------------------------------------------------------------
func levels() -> Array:
	return campaign.get("levels", [])


func level(id: String) -> Dictionary:
	for l: Dictionary in levels():
		if l["id"] == id:
			return l
	return {}


func next_level(id: String) -> Dictionary:
	var ls: Array = levels()
	for i in ls.size():
		if ls[i]["id"] == id and i + 1 < ls.size():
			return ls[i + 1]
	return {}


## Ссылка на дело уровня: свой файл дела или генератор.
func level_case_ref(lvl: Dictionary) -> String:
	var c: String = str(lvl.get("case", "gen"))
	return "gen:" + str(lvl["id"]) if c == "gen" else c


func deadline_minutes() -> float:
	return float(campaign.get("deadline_minutes", 20))


func villain_frames(id: String) -> SpriteFrames:
	var key: String = "villain_" + id
	if _frames.has(key):
		return _frames[key]
	var tex: Texture2D = texture("villains/%s.png" % id)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row: Array in [["idle", 0, 2.0], ["menace", 1, 5.0]]:
		frames.add_animation(row[0])
		frames.set_animation_speed(row[0], row[2])
		for i in 2:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * 32, int(row[1]) * 40, 32, 40)
			frames.add_frame(row[0], atlas)
	_frames[key] = frames
	return frames


func villain_portrait(id: String) -> Texture2D:
	var p: String = "portraits/villain_%s.png" % id
	return texture(p) if ResourceLoader.exists(SPRITES + p) else monster_portrait(id)


func layout(carriage_id: String) -> Dictionary:
	if not _layouts.has(carriage_id):
		_layouts[carriage_id] = load_json("layout/%s.json" % carriage_id)
	return _layouts[carriage_id]


func character(id: String) -> Dictionary:
	return characters.get(id, {})


func char_name(id: String) -> String:
	return str(character(id).get("name", id))


func monster(id: String) -> Dictionary:
	return monsters.get(id, {})


func prog_list(key: String) -> Array:
	return progression.get(key, [])


func prog_item(key: String, id: String) -> Dictionary:
	for item: Dictionary in prog_list(key):
		if item.get("id", "") == id:
			return item
	return {}


# --- время дела ----------------------------------------------------------------------------
## "01:39:30" → минуты от полуночи (99.5).
static func parse_time(text: String) -> float:
	var parts: PackedStringArray = text.split(":")
	var minutes: float = float(parts[0]) * 60.0 + float(parts[1])
	if parts.size() > 2:
		minutes += float(parts[2]) / 60.0
	return minutes


## Минуты от полуночи → "01:39" (или "01:39:30" с секундами).
static func format_time(minutes: float, with_seconds: bool = false) -> String:
	var total_seconds: int = int(floor(minutes * 60.0 + 0.0001))
	var h: int = (total_seconds / 3600) % 24
	var m: int = (total_seconds / 60) % 60
	var s: int = total_seconds % 60
	if with_seconds:
		return "%02d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [h, m]


# --- ресурсы -------------------------------------------------------------------------------
func texture(rel_path: String) -> Texture2D:
	if not _textures.has(rel_path):
		var path: String = SPRITES + rel_path
		_textures[rel_path] = load(path) if ResourceLoader.exists(path) else null
		if _textures[rel_path] == null:
			push_warning("Нет текстуры: " + path)
	return _textures[rel_path]


func icon(name: String) -> Texture2D:
	return texture("icons/%s.png" % name)


func portrait(id: String, expr: String = "normal") -> Texture2D:
	var path: String = "portraits/%s_%s.png" % [id, expr]
	if ResourceLoader.exists(SPRITES + path):
		return texture(path)
	return texture("portraits/%s_normal.png" % id)


func monster_portrait(id: String) -> Texture2D:
	return texture("portraits/monster_%s.png" % id)


## Анимации персонажа из листа assets/sprites/characters/<sheet>.png по data/sprite_layout.json.
func character_frames(sheet: String) -> SpriteFrames:
	if _frames.has(sheet):
		return _frames[sheet]
	var tex: Texture2D = texture("characters/%s.png" % sheet)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var fw: int = int(sprite_layout.get("frame_w", 32))
	var fh: int = int(sprite_layout.get("frame_h", 40))
	var rows: Dictionary = sprite_layout.get("rows", {})
	for anim_name: String in rows:
		var row: Dictionary = rows[anim_name]
		var y: int = int(row["row"]) * fh
		if tex == null or y + fh > tex.get_height():
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(row["fps"]))
		frames.set_animation_loop(anim_name, bool(row["loop"]))
		for i in int(row["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * fw, y, fw, fh)
			frames.add_frame(anim_name, atlas)
	_frames[sheet] = frames
	return frames


func monster_frames(id: String) -> SpriteFrames:
	var key: String = "monster_" + id
	if _frames.has(key):
		return _frames[key]
	var tex: Texture2D = texture("monsters/%s.png" % id)
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 5.0)
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * 48, 0, 48, 48)
		frames.add_frame(&"default", atlas)
	_frames[key] = frames
	return frames
