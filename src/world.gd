extends Node3D

@export var appearance_pool: AppearancePool = preload("res://src/characters/default_appearance_pool.tres")
@export var total_assassins: int = 8
@export var quest_assassins: int = 4

@export_group("Match Rules (18:00 - 19:00)")
@export var match_duration_seconds: float = 300.0
@export var score_assassin_kill: int = 100
@export var score_civilian_penalty: int = -50
@export var score_quest_bonus: int = 300

@export_group("Camera")
@export var camera_half_width: float = 6.0
@export var camera_smooth_speed: float = 6.0
@export var list_zoom_factor: float = 0.65
@export var list_zoom_duration: float = 0.35
@export var list_zoom_x_offset: float = 0.9

@onready var _player: Player = $Player
@onready var _player_camera: Camera3D = $Player/Camera3D
@onready var _director: OffScreenDirector = $OffScreenDirector
@onready var _active_npcs_container: Node3D = $ActiveNpcs
@onready var _levels_root: Node3D = $Levels
@onready var _assassin_list_ui: AssassinListUI = $AssassinListUI
@onready var _game_hud: GameHud = $GameHud

var assassins: Array[CharacterData] = []
var reserved_signatures: Dictionary = {}

var _levels: Array[LevelZone] = []
var _active_zone: LevelZone = null
var _world_min_x: float = -15.0
var _world_max_x: float = 75.0
var _camera_base_offset: Vector3 = Vector3.ZERO
var _camera_base_size: float = 6.8
var _camera_zoom_tween: Tween = null
var _is_list_open: bool = false

var _elapsed_time: float = 0.0
var _score: int = 0
var _quest_completed: bool = false
var _match_ended: bool = false


func _ready() -> void:
	for child in _levels_root.get_children():
		if child is LevelZone:
			_levels.append(child)
	_levels.sort_custom(func(a: LevelZone, b: LevelZone) -> bool: return a.level_id < b.level_id)

	if not _levels.is_empty():
		_world_min_x = _levels[0].min_x + 0.6
		_world_max_x = _levels[-1].max_x - 0.6

	if _player_camera:
		_camera_base_offset = _player_camera.position
		_camera_base_size = _player_camera.size
		_player_camera.top_level = true
		_player_camera.global_position = _player.global_position + _camera_base_offset

	_director.npc_died.connect(_on_npc_died)
	_director.quest_npc_interacted.connect(_on_quest_npc_interacted)
	_director.level_activated.connect(_on_level_activated)
	_player.killed_by_assassin.connect(_on_player_killed)
	if _assassin_list_ui:
		_assassin_list_ui.list_visibility_changed.connect(_on_assassin_list_visibility_changed)

	_start_match()


func _start_match() -> void:
	set_process(false)
	assassins = CharacterGenerator.generate_assassins(
		appearance_pool,
		total_assassins,
		quest_assassins,
		maxi(1, _levels.size())
	)
	reserved_signatures = CharacterGenerator.collect_reserved_signatures(assassins)

	await PortraitBaker.bake_portraits(self, assassins)

	if _assassin_list_ui:
		_assassin_list_ui.set_assassins(assassins)

	_director.initialize(
		_levels,
		assassins,
		appearance_pool,
		reserved_signatures,
		_active_npcs_container,
		_player.global_position.z
	)

	var start_zone := _director.get_zone_for_x(_player.global_position.x)
	if start_zone:
		_director.activate_level(start_zone.level_id)
	_game_hud.enable_restart()
	set_process(true)


func _physics_process(delta: float) -> void:
	if _match_ended:
		return

	# Omezení pohybu hráče na celkovou šířku 3 levelů
	_player.global_position.x = clampf(_player.global_position.x, _world_min_x, _world_max_x)

	# Detekce přechodu hráče do jiného levelu
	var zone := _director.get_zone_for_x(_player.global_position.x)
	if zone and zone.level_id != _director.active_level_id:
		_director.activate_level(zone.level_id)

	_update_camera_clamp(delta)


func _process(delta: float) -> void:
	if _match_ended:
		return
	_update_match_clock(delta)


func _on_assassin_list_visibility_changed(is_open: bool) -> void:
	_is_list_open = is_open
	_player.set_movement_locked(is_open)

	if not _player_camera:
		return
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()

	var target_size := _camera_base_size * list_zoom_factor if is_open else _camera_base_size
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_zoom_tween.set_ease(Tween.EASE_OUT)
	_camera_zoom_tween.tween_property(_player_camera, "size", target_size, list_zoom_duration)


func _update_camera_clamp(delta: float) -> void:
	if not _active_zone or not _player_camera:
		return

	var target_world_x: float
	if _is_list_open:
		target_world_x = _player.global_position.x + list_zoom_x_offset
	else:
		var min_cam_x := _active_zone.min_x + camera_half_width
		var max_cam_x := _active_zone.max_x - camera_half_width
		target_world_x = (
			(_active_zone.min_x + _active_zone.max_x) * 0.5
			if min_cam_x > max_cam_x
			else clampf(_player.global_position.x, min_cam_x, max_cam_x)
		)

	var weight := 1.0 - exp(-camera_smooth_speed * delta)
	var pos := _player_camera.global_position
	pos.x = lerpf(pos.x, target_world_x, weight)
	pos.y = _player.global_position.y + _camera_base_offset.y
	pos.z = _player.global_position.z + _camera_base_offset.z
	_player_camera.global_position = pos


func _update_match_clock(delta: float) -> void:
	_elapsed_time += delta
	var progress := clampf(_elapsed_time / maxf(1.0, match_duration_seconds), 0.0, 1.0)
	if _game_hud:
		_game_hud.set_clock_progress(progress)

	if _elapsed_time >= match_duration_seconds:
		_end_match("Čas vypršel (19:00)", "Tvoje konečné skóre: %d" % _score)


func _on_level_activated(zone: LevelZone) -> void:
	_active_zone = zone
	if _game_hud:
		_game_hud.set_level(zone.level_name, zone.level_id)


func _on_npc_died(npc: NpcBase, killer: Node3D) -> void:
	if npc.character_data and npc.character_data.is_assassin and _assassin_list_ui:
		_assassin_list_ui.mark_assassin_dead(npc.character_data.id)

	var points := score_assassin_kill if npc.is_assassin else score_civilian_penalty
	if killer == _player:
		_add_score(points)
		if npc.visuals:
			npc.visuals.show_score_popup(points)
	elif killer is NpcBase and killer.character_data and killer.character_data.is_assassin:
		killer.character_data.has_killed = true
		killer.character_data.kill_score += points


func _on_quest_npc_interacted(_npc: QuestNpc, actor: Node3D, role: QuestNpc.Role) -> void:
	if actor != _player:
		return

	match role:
		QuestNpc.Role.MADRINA_METTICULOSA:
			if not _player.has_balloon:
				_player.has_balloon = true
		QuestNpc.Role.PADRINO_MORETTI:
			if _player.has_balloon and not _player.has_battery:
				_player.has_battery = true
		QuestNpc.Role.PADRINO_PACATO:
			if _player.has_balloon and _player.has_battery and not _quest_completed:
				_quest_completed = true
				_player.has_balloon = false
				_player.has_battery = false
				_add_score(score_quest_bonus)

	if _game_hud:
		_game_hud.set_quest_state(_player.has_balloon, _player.has_battery, _quest_completed)


func _on_player_killed(attacker: Node3D, death_animation: Tween) -> void:
	var killer_name := "neznámý assassin"
	if attacker is NpcBase and not attacker.display_name.is_empty():
		killer_name = attacker.display_name
	if attacker is NpcBase and attacker.character_data and attacker.character_data.is_assassin:
		attacker.character_data.has_killed = true
		attacker.character_data.kill_score += score_assassin_kill
	_end_match("Byl jsi zabit", "Dostal tě %s.\nKonečné skóre: %d" % [killer_name, _score], death_animation)


func _format_leaderboard() -> String:
	var ranking: Array[Dictionary] = [{"name": "Ty", "score": _score}]
	for assassin in assassins:
		if assassin.has_killed:
			var score := assassin.kill_score
			if assassin.quest_stage == CharacterData.QuestStage.COMPLETED:
				score += score_quest_bonus
			ranking.append({"name": assassin.display_name, "score": score})
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] == b["score"]:
			return a["name"] < b["name"]
		return a["score"] > b["score"]
	)

	var rows := PackedStringArray()
	for i in range(ranking.size()):
		var entry := ranking[i]
		rows.append("%d. %s — %d" % [i + 1, entry["name"], entry["score"]])
	return "\n".join(rows)


func _add_score(delta_score: int) -> void:
	_score += delta_score
	if _game_hud:
		_game_hud.set_score(_score)


func _end_match(title: String, summary: String, death_animation: Tween = null) -> void:
	if _match_ended:
		return
	_match_ended = true
	_player.set_movement_locked(true)
	_assassin_list_ui.hide()
	$InteractionIndicator.hide()
	get_tree().paused = true
	if death_animation:
		await death_animation.finished
	if _game_hud:
		_game_hud.show_end_screen(title, summary, _format_leaderboard())
