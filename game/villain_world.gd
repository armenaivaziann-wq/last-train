class_name VillainWorld
extends Node2D
## Видимые проявления способностей злодея в мире. Обновляется по времени дела —
## живому или времени записи камеры (поэтому записи совпадают с тем, что видел игрок).
##   • облик перевёртыша на его спрайте;
##   • отражения в зеркалах вагонов (у зеркальника отражения нет);
##   • лишний чемодан мимика, переползающий между местами в туннелях;
##   • неправильная тень теневика.

const MIRROR_REACH_X: float = 26.0

var game: Game
var hooks: VillainHooks
var _mirrors: Array = []   # [{pos: Vector2 (центр стекла), sprite: Sprite2D}]
var _bag: Sprite2D
var _bag_it: Interactable


func setup(g: Game) -> void:
	game = g
	hooks = g.investigation.hooks
	z_index = 1
	for cid in g.layout.carriage_ids:
		for p: Dictionary in Db.layout(cid).get("props", []):
			if p["sprite"] == "mirror":
				var center := Vector2(g.layout.offsets[cid] + float(p["pos"][0]), float(p["pos"][1]) + 1.0)
				var s := Sprite2D.new()
				s.position = center
				s.scale = Vector2(0.42, 0.42)
				s.modulate = Color(0.75, 0.9, 1.0, 0.7)
				s.visible = false
				add_child(s)
				_mirrors.append({"pos": center, "sprite": s})
	if hooks.villain == "mimic":
		_bag = Sprite2D.new()
		_bag.texture = Db.texture("props/suitcase_brown.png")
		g.entities.add_child(_bag)
		_bag_it = Interactable.new()
		_bag_it.interact_id = "obj_mimic_bag"
		_bag_it.label = "Осмотреть чемодан"
		_bag_it.kind = Interactable.Kind.OBJECT
		_bag_it.radius = 22.0
		_bag.add_child(_bag_it)
	if hooks.villain == "shadow":
		var npc: NPCController = g.npcs.get(hooks.culprit)
		if npc:
			npc.shadow_wrong = true


## Применить состояние способностей на момент t.
func apply(t: float) -> void:
	if hooks.villain == "shapeshifter":
		var npc: NPCController = game.npcs.get(hooks.culprit)
		if npc:
			npc.set_look(hooks.disguise_at(t))
	if _bag:
		var at: Array = hooks.mimic_at(t)
		if not at.is_empty():
			_bag.position = Vector2(game.layout.offsets[at[0]] + float(at[1][0]), float(at[1][1]))
			_bag.offset = Vector2(0, -_bag.texture.get_height() / 2.0)


func _process(_delta: float) -> void:
	_update_mirrors()


## Отражение ближайшего человека, стоящего у зеркала (уменьшенная копия кадра).
func _update_mirrors() -> void:
	for m: Dictionary in _mirrors:
		var spr: Sprite2D = m["sprite"]
		var best: Node2D = null
		var bd: float = INF
		var people: Array = game.npcs.values()
		people.append(game.player)
		for n: Node2D in people:
			if not n.visible:
				continue
			var d: Vector2 = n.global_position - m["pos"]
			if absf(d.x) < MIRROR_REACH_X and d.y > 40.0 and d.y < 120.0 and d.length() < bd:
				bd = d.length()
				best = n
		var show: bool = best != null
		if best is NPCController and not hooks.has_reflection((best as NPCController).npc_id):
			show = false
		spr.visible = show
		if show:
			var cs: CharacterSprite = best.sprite if best is NPCController else (best as PlayerController).sprite
			spr.texture = cs.sprite_frames.get_frame_texture(cs.animation, cs.frame)
			spr.flip_h = not cs.flip_h
