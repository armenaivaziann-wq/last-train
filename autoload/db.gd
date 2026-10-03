extends Node
## Игровые данные (JSON в res://data) и кэш ресурсов: иконки, портреты, анимации персонажей.
## Логика игры обращается к данным только через этот узел.

const DATA_DIR: String = "res://data/"
const SPRITES: String = "res://assets/sprites/"

var characters: Dictionary = {}
var monsters: Dictionary = {}
var progression: Dictionary = {}
var sprite_layout: Dictionary = {}

var _cases: Dictionary = {}
var _layouts: Dictionary = {}
var _textures: Dictionary = {}
var _frames: Dictionary = {}


func _ready() -> void:
	characters = load_json("characters.json")
	monsters = load_json("monsters.json")
	progression = load_json("progression.json")
	sprite_layout = load_json("sprite_layout.json")


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
