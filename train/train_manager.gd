class_name TrainManager
extends Node2D
## Поезд: вагоны дела, пейзаж за окнами, земля снаружи (вид сверху), деревья и фонари,
## туннели, дождь, огни станции, мерцание ламп. Поезд «едет» — мир снаружи прокручивается.

const CARRIAGE_SCENES: String = "res://train/carriages/%s.tscn"
const GROUND_SPEED: float = 190.0   # пикселей мира в секунду
const BAND_H: float = 96.0

var layout: TrainLayout
var carriages: Dictionary = {}       # id → Carriage
var interactables: Dictionary = {}   # id → Interactable
var entities: Node2D
var glow_layer: Node2D

var speed_factor: float = 1.0
var _scroll: float = 0.0
var _tunnel: float = 0.0
var _tunnel_target: float = 0.0
var _rain: float = 0.0
var _rain_target: float = 0.0
var _station: float = 0.0
var _station_target: float = 0.0
var _rain_time: float = 0.0
var _window_mat: ShaderMaterial
var _ground_top: Sprite2D
var _ground_bottom: Sprite2D
var _fill_top: ColorRect
var _fill_bottom: ColorRect
var _outside: Node2D
var _trees: Array[Sprite2D] = []
var _rng := RandomNumberGenerator.new()
var _ground_kind: String = "forest"
var _flicker_t: float = 0.0
var modulate_node: CanvasModulate
var _flicker_left: float = 0.0
var _blackout_left: float = 0.0


func build(train_layout: TrainLayout, ground: String, entities_node: Node2D, glow_node: Node2D) -> void:
	layout = train_layout
	entities = entities_node
	glow_layer = glow_node
	_ground_kind = ground
	_rng.seed = 1234
	_build_outside()
	_build_window_strip()
	for cid in layout.carriage_ids:
		var path: String = CARRIAGE_SCENES % cid
		var car: Carriage = (load(path) as PackedScene).instantiate() if ResourceLoader.exists(path) else Carriage.new()
		car.carriage_id = cid
		car.name = cid.capitalize()
		car.position = Vector2(layout.offsets[cid], 0)
		add_child(car)
		car.build(entities, glow_layer)
		carriages[cid] = car
		for id: String in car.interactables:
			interactables[id] = car.interactables[id]


func _build_outside() -> void:
	_outside = Node2D.new()
	_outside.name = "Outside"
	_outside.z_index = -20
	_outside.modulate = Color(0.62, 0.66, 0.9)
	add_child(_outside)
	var w: float = layout.width + 1400.0
	var x0: float = -700.0
	var grass: Color = Color("#14223a") if _ground_kind == "forest" else Color("#9aa4c8")
	_fill_top = ColorRect.new()
	_fill_top.color = grass
	_fill_top.position = Vector2(x0, -900)
	_fill_top.size = Vector2(w, 900 - BAND_H + 1)
	_outside.add_child(_fill_top)
	_fill_bottom = ColorRect.new()
	_fill_bottom.color = grass
	_fill_bottom.position = Vector2(x0, layout.HEIGHT + BAND_H - 1)
	_fill_bottom.size = Vector2(w, 900)
	_outside.add_child(_fill_bottom)
	var tex: Texture2D = Db.texture("world/ground_%s.png" % _ground_kind)
	_ground_top = _band(tex, x0, -BAND_H, w, true)
	_ground_bottom = _band(tex, x0, layout.HEIGHT, w, false)
	for i in 26:
		var t := Sprite2D.new()
		t.texture = Db.texture(_tree_texture())
		_outside.add_child(t)
		_trees.append(t)
		_place_tree(t, x0 + _rng.randf() * w)


func _band(tex: Texture2D, x0: float, y: float, w: float, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, w, BAND_H)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = Vector2(x0, y)
	s.flip_v = flip
	_outside.add_child(s)
	return s


func _tree_texture() -> String:
	if _ground_kind == "snow":
		return "world/tree_top_snow.png"
	return "world/tree_top_%d.png" % _rng.randi_range(0, 1)


func _place_tree(t: Sprite2D, x: float) -> void:
	var top: bool = _rng.randf() < 0.5
	t.position = Vector2(x, _rng.randf_range(-130.0, -46.0) if top else _rng.randf_range(layout.HEIGHT + 46.0, layout.HEIGHT + 130.0))


func _build_window_strip() -> void:
	var strip := ColorRect.new()
	strip.name = "WindowLandscape"
	strip.position = Vector2(0, 8)
	strip.size = Vector2(layout.width, 48)
	strip.z_index = -5
	_window_mat = ShaderMaterial.new()
	_window_mat.shader = load("res://train/window_landscape.gdshader")
	_window_mat.set_shader_parameter("sky_tex", Db.texture("world/window_sky.png"))
	_window_mat.set_shader_parameter("mountains_tex", Db.texture("world/window_mountains.png"))
	_window_mat.set_shader_parameter("forest_tex", Db.texture("world/window_forest.png"))
	_window_mat.set_shader_parameter("near_tex", Db.texture("world/window_near.png"))
	_window_mat.set_shader_parameter("tunnel_tex", Db.texture("world/window_tunnel.png"))
	_window_mat.set_shader_parameter("station_tex", Db.texture("world/window_station.png"))
	_window_mat.set_shader_parameter("rain_tex", Db.texture("world/rain_glass.png"))
	_window_mat.set_shader_parameter("rect_size", strip.size)
	strip.material = _window_mat
	add_child(strip)


# --- атмосфера ------------------------------------------------------------------------------
func set_tunnel(on: bool) -> void:
	_tunnel_target = 1.0 if on else 0.0


func set_rain(on: bool) -> void:
	_rain_target = 1.0 if on else 0.0


func set_station(on: bool) -> void:
	_station_target = 1.0 if on else 0.0


## Свет мигает (1–2 секунды), поезд продолжает ехать.
func flicker(duration: float = 1.5) -> void:
	_flicker_left = duration


## Короткая темнота (свет погас).
func blackout(duration: float = 0.7) -> void:
	_blackout_left = duration


func in_tunnel() -> bool:
	return _tunnel > 0.5


func _process(delta: float) -> void:
	var step: float = GROUND_SPEED * speed_factor * delta
	_scroll += step
	_tunnel = move_toward(_tunnel, _tunnel_target, delta * 2.0)
	_rain = move_toward(_rain, _rain_target, delta * 0.5)
	_station = move_toward(_station, _station_target, delta * 0.4)
	_rain_time += delta
	var sx: float = floor(_scroll)
	_ground_top.region_rect.position.x = sx
	_ground_bottom.region_rect.position.x = sx
	var tunnel_k: float = _tunnel
	_outside.modulate = Color(0.62, 0.66, 0.9).lerp(Color(0.08, 0.07, 0.12), tunnel_k)
	for t in _trees:
		t.position.x -= step
		t.visible = tunnel_k < 0.5
		if t.position.x < -720.0:
			_place_tree(t, layout.width + 680.0 + _rng.randf() * 60.0)
	_window_mat.set_shader_parameter("scroll", _scroll)
	_window_mat.set_shader_parameter("tunnel", _tunnel)
	_window_mat.set_shader_parameter("rain", _rain)
	_window_mat.set_shader_parameter("station", _station)
	_window_mat.set_shader_parameter("rain_time", _rain_time)
	_update_lights(delta)


func _update_lights(delta: float) -> void:
	_flicker_t += delta
	for car: Carriage in carriages.values():
		for i in car.lamp_glows.size():
			var g: Sprite2D = car.lamp_glows[i]
			var flick: float = 1.0
			if _tunnel > 0.3:
				flick = 0.75 + 0.25 * sin(_flicker_t * 13.0 + i * 1.7) * sin(_flicker_t * 3.1 + i)
			g.modulate.a = 0.55 * flick * (0.8 + 0.4 * _tunnel)
		for i in car.window_glows.size():
			var w: Sprite2D = car.window_glows[i]
			var trees: float = 0.85 + 0.15 * sin(_scroll * 0.05 + i * 2.3)
			w.modulate.a = 0.45 * trees * (1.0 - _tunnel) * (1.0 - 0.4 * _rain) + 0.25 * _station
	if modulate_node:
		var col: Color = Color(1.0, 0.97, 1.0).lerp(Color(0.4, 0.36, 0.58), _tunnel)
		if _flicker_left > 0.0:
			_flicker_left -= delta
			if fmod(_flicker_t * 9.0, 1.0) < 0.35:
				col = col.darkened(0.55)
		if _blackout_left > 0.0:
			_blackout_left -= delta
			col = Color(0.16, 0.14, 0.26)
		modulate_node.color = col
