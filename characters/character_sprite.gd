class_name CharacterSprite
extends AnimatedSprite2D
## Спрайт персонажа: анимации из листа (idle/walk/sit по направлениям + особые действия
## детектива). Вправо — зеркальная анимация «влево». Начало координат узла — под ногами.

const FOOT_OFFSET: float = -18.0

var sheet: String = ""
var facing: String = "down"
var _base: String = "idle"


func setup(sheet_id: String) -> void:
	sheet = sheet_id
	sprite_frames = Db.character_frames(sheet_id)
	offset = Vector2(0, FOOT_OFFSET)
	centered = true
	play_state("idle", "down")


## base: idle / walk / sit / talk; facing: down / up / left / right.
func play_state(base: String, dir: String) -> void:
	facing = dir
	_base = base
	var anim: String
	if base == "talk":
		anim = "talk_down" if dir == "down" else "idle_" + _dir_key(dir)
	else:
		anim = "%s_%s" % [base, _dir_key(dir)]
	flip_h = dir == "right"
	if sprite_frames and sprite_frames.has_animation(anim):
		if animation != anim:
			play(anim)
		elif not is_playing():
			play(anim)


## Особая анимация детектива (inspect, note, arrest...). Возвращает false, если её нет.
func play_action(anim: String) -> bool:
	if sprite_frames == null or not sprite_frames.has_animation(anim):
		return false
	flip_h = false
	play(anim)
	return true


func _dir_key(dir: String) -> String:
	return "left" if dir == "right" else dir


static var _shadow_cache: Texture2D


static func shadow_texture() -> Texture2D:
	if _shadow_cache:
		return _shadow_cache
	var img := Image.create(22, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 22:
			var dx: float = (x + 0.5 - 11.0) / 11.0
			var dy: float = (y + 0.5 - 4.0) / 4.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0.04, 0.01, 0.1, 0.55 if dx * dx + dy * dy < 0.5 else 0.38))
	_shadow_cache = ImageTexture.create_from_image(img)
	return _shadow_cache
