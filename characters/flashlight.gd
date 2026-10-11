class_name Flashlight
extends Node2D
## Фонарик детектива: конус света в сторону взгляда и слабое пятно вокруг героя. Работает
## только в темноте (туннель или ночь без света). Свет — настоящие 2D-источники: в тёмном
## вагоне освещено только то, что попало в луч.

const RANGE: float = 170.0
const HALF_ANGLE: float = deg_to_rad(36.0)

var on: bool = false
var _cone: PointLight2D
var _halo: PointLight2D
static var _cone_tex: Texture2D
static var _halo_tex: Texture2D


func _ready() -> void:
	_cone = PointLight2D.new()
	_cone.texture = _cone_texture()
	_cone.offset = Vector2(RANGE / 2.0, 0)
	_cone.energy = 1.35
	_cone.color = Color(1.0, 0.93, 0.75)
	_cone.position = Vector2(0, -16)
	add_child(_cone)
	_halo = PointLight2D.new()
	_halo.texture = _halo_texture()
	_halo.energy = 0.55
	_halo.color = Color(1.0, 0.93, 0.8)
	_halo.position = Vector2(0, -14)
	add_child(_halo)
	set_on(false)


func set_on(v: bool) -> void:
	on = v
	_cone.enabled = v
	_halo.enabled = v


func aim(facing: String) -> void:
	_cone.rotation = {"right": 0.0, "left": PI, "up": -PI / 2.0, "down": PI / 2.0}.get(facing, 0.0)


## Попадает ли точка мира в луч.
func lights(world_pos: Vector2) -> bool:
	if not on:
		return false
	var origin: Vector2 = _cone.global_position
	var d: Vector2 = world_pos - origin
	if d.length() < 26.0:
		return true
	if d.length() > RANGE:
		return false
	return absf(angle_difference(_cone.rotation, d.angle())) <= HALF_ANGLE


static func _cone_texture() -> Texture2D:
	if _cone_tex:
		return _cone_tex
	var w: int = int(RANGE)
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		for x in w:
			var p := Vector2(x, y - w / 2.0)
			var r: float = p.length() / float(w)
			var a: float = absf(p.angle())
			if r <= 1.0 and a <= HALF_ANGLE:
				var k: float = (1.0 - r) * clampf((HALF_ANGLE - a) / 0.18, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, k))
	_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex


static func _halo_texture() -> Texture2D:
	if _halo_tex:
		return _halo_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var r: float = Vector2(x - 32, y - 32).length() / 32.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - r, 0.0, 1.0) * 0.8))
	_halo_tex = ImageTexture.create_from_image(img)
	return _halo_tex
