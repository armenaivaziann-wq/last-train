class_name CameraSystem
extends Node
## Камеры наблюдения. В режиме просмотра записи пассажиры ставятся туда, где они были
## в выбранный момент (по хронологии дела), а детектив — по записанному следу.
## Экран камер показывает мир через собственные камеры с общим World2D — то есть
## записи отражают реальные события дела, а не отдельные картинки.

var layout: TrainLayout
var investigation: InvestigationManager
var npcs: Dictionary = {}          # id → NPCController
var player: PlayerController
var playback: bool = false
var playback_time: float = 0.0
## Места преступлений (индекс → CrimeScene): до момента убийства на записях их нет.
var crime_scenes: Dictionary = {}
var villain_world: VillainWorld
var _markers_cache: Dictionary = {}


func setup(train_layout: TrainLayout, inv: InvestigationManager, npc_nodes: Dictionary, player_node: PlayerController) -> void:
	layout = train_layout
	investigation = inv
	npcs = npc_nodes
	player = player_node


func cameras() -> Array[Dictionary]:
	return layout.cameras


func begin_playback() -> void:
	playback = true
	investigation.hold("cameras")
	set_time(investigation.clock)


func end_playback() -> void:
	playback = false
	investigation.release("cameras")
	player.visible = true
	for scene: CrimeScene in crime_scenes.values():
		scene.show_at(INF)
	for id: String in npcs:
		var npc: NPCController = npcs[id]
		npc.visible = not npc.dead and npc.condition != "missing"


func set_time(t: float) -> void:
	playback_time = clampf(t, investigation.history_start, investigation.clock)
	for id: String in npcs:
		var npc: NPCController = npcs[id]
		var was_detained: bool = npc.detained
		var was_dead: bool = npc.dead
		npc.detained = false
		npc.dead = false
		npc.visible = not investigation.murders.dead_at(id, playback_time) and not investigation.hidden_at(id, playback_time)
		npc.apply(investigation.timeline.state_at(id, playback_time))
		npc.detained = was_detained
		npc.dead = was_dead
	for scene: CrimeScene in crime_scenes.values():
		scene.show_at(playback_time)
	if villain_world:
		villain_world.apply(playback_time)
	var tr: Array = player.track_at(playback_time)
	if tr.is_empty() or playback_time < investigation.start_time:
		player.visible = false
	else:
		player.visible = true
		player.sprite.play_state("idle", str(tr[2]))
		player.global_position = tr[1]


## Метки движения на шкале: моменты, когда кто-то входит в кадр камеры (минуты).
func motion_markers(cam_id: String) -> Array:
	if _markers_cache.has(cam_id):
		return _markers_cache[cam_id]
	var cam: Dictionary = layout.camera(cam_id)
	var out: Array = []
	if cam.is_empty():
		return out
	for id in investigation.timeline.npc_ids():
		for iv: Array in investigation.timeline.presence(id, cam["rect"], investigation.history_start, investigation.start_time, 2.0 / 60.0):
			if iv[0] > investigation.history_start + 0.05:
				out.append({"t": iv[0], "npc": id})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	_markers_cache[cam_id] = out
	return out


## Кто виден на камере в момент t.
func visible_on(cam_id: String, t: float) -> Array[String]:
	var out: Array[String] = []
	var cam: Dictionary = layout.camera(cam_id)
	for id in investigation.timeline.npc_ids():
		if cam["rect"].has_point(investigation.timeline.position_at(id, t)):
			out.append(id)
	return out
