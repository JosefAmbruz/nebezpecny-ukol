extends Node3D

@export var appearance_pool: AppearancePool = preload("res://src/characters/default_appearance_pool.tres")
@export var total_assassins: int = 8
@export var quest_assassins: int = 4

@export_group("Match Rules (18:00 - 19:00)")
@export var match_duration_seconds: float = 300.0
@export var max_toothbrushes: int = 3
@export var score_assassin_kill: int = 100
@export var score_civilian_penalty: int = -50
@export var score_quest_bonus: int = 300

@export_group("Camera")
@export var camera_half_width: float = 6.0
@export var camera_smooth_speed: float = 6.0
@export var list_zoom_factor: float = 0.65
@export var list_zoom_duration: float = 0.35
@export var list_zoom_x_offset: float = 0.9
@export var assassinate_zoom_factor: float = 0.65
@export var assassinate_focus_y_offset: float = 1.2
@export var assassinate_zoom_return_duration: float = 0.32

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
var _is_assassinating: bool = false
var _assassinate_progress: float = 0.0
var _assassinate_target: Node3D = null
var _assassinate_start_cam_pos: Vector3 = Vector3.ZERO

var _elapsed_time: float = 0.0
var _score: int = 0
var _broken_toothbrushes: int = 0
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
	_player.interaction_started.connect(_on_player_interaction_started)
	_player.interaction_progress_changed.connect(_on_player_interaction_progress_changed)
	_player.interaction_cancelled.connect(_on_player_interaction_ended)
	_player.interaction_completed.connect(_on_player_interaction_completed)
	if _assassin_list_ui:
		_assassin_list_ui.list_visibility_changed.connect(_on_assassin_list_visibility_changed)
	if _game_hud:
		_game_hud.restart_requested.connect(_on_restart_requested)
		_game_hud.menu_requested.connect(_on_menu_requested)

	_start_match()


func _start_match() -> void:
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

	if _game_hud:
		_game_hud.set_toothbrushes(max_toothbrushes, _broken_toothbrushes)

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


func _on_player_interaction_started(target: InteractableNpc, kind: InteractableNpc.InteractionKind) -> void:
	if kind != InteractableNpc.InteractionKind.ASSASSINATE:
		return
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	_is_assassinating = true
	_assassinate_progress = 0.0
	_assassinate_target = target.get_character_root() if target else null
	if _player_camera:
		_assassinate_start_cam_pos = _player_camera.global_position


func _on_player_interaction_progress_changed(progress: float, kind: InteractableNpc.InteractionKind) -> void:
	if not _is_assassinating or kind != InteractableNpc.InteractionKind.ASSASSINATE:
		return
	_assassinate_progress = clampf(progress, 0.0, 1.0)


func _on_player_interaction_completed(_target: InteractableNpc, kind: InteractableNpc.InteractionKind) -> void:
	if kind == InteractableNpc.InteractionKind.ASSASSINATE:
		_on_player_interaction_ended()


func _on_player_interaction_ended() -> void:
	if not _is_assassinating:
		return
	_is_assassinating = false
	_assassinate_progress = 0.0
	_assassinate_target = null

	if not _player_camera or _is_list_open:
		return
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_zoom_tween.set_ease(Tween.EASE_OUT)
	_camera_zoom_tween.tween_property(_player_camera, "size", _camera_base_size, assassinate_zoom_return_duration)


func _update_camera_clamp(delta: float) -> void:
	if not _active_zone or not _player_camera:
		return

	if _is_assassinating and not _is_list_open:
		# Kubická ease-out křivka: rychlý dramatický nástup na oběť, ke konci zpomaluje
		var eased := 1.0 - pow(1.0 - _assassinate_progress, 3.0)
		_player_camera.size = lerpf(_camera_base_size, _camera_base_size * assassinate_zoom_factor, eased)

		if is_instance_valid(_assassinate_target):
			var victim_pos := _assassinate_target.global_position
			var cam_pos := _player_camera.global_position
			cam_pos.x = lerpf(_assassinate_start_cam_pos.x, victim_pos.x, eased)
			cam_pos.y = lerpf(_assassinate_start_cam_pos.y, victim_pos.y + assassinate_focus_y_offset, eased)
			_player_camera.global_position = cam_pos
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
	pos.y = lerpf(pos.y, _player.global_position.y + _camera_base_offset.y, weight)
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
		_game_hud.set_level_name(zone.level_name)


func _on_npc_died(npc: NpcBase, killer: Node3D) -> void:
	if npc.character_data and npc.character_data.is_assassin and _assassin_list_ui:
		_assassin_list_ui.mark_assassin_dead(npc.character_data.id)

	if killer == _player:
		if npc.is_assassin:
			_add_score(score_assassin_kill)
		else:
			_add_score(score_civilian_penalty)
			_broken_toothbrushes += 1
			if _game_hud:
				_game_hud.set_toothbrushes(max_toothbrushes, _broken_toothbrushes)
			if _broken_toothbrushes >= max_toothbrushes:
				_end_match(
					"Zlomil jsi všechny kartáčky!",
					"Omylem jsi vyřadil %d civilisty.\nKonečné skóre: %d" % [_broken_toothbrushes, _score]
				)


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


func _on_player_killed(attacker: Node3D) -> void:
	if _player.visuals:
		_player.visuals.visible = false
	_director.spawn_death_mark(_player.global_position, "Ty (Hráč)", true)

	var killer_name := "neznámý assassin"
	if attacker is NpcBase and not attacker.display_name.is_empty():
		killer_name = attacker.display_name
	_end_match("Byl jsi vyřazen kartáčkem!", "Dostal tě %s.\nKonečné skóre: %d" % [killer_name, _score])


func _add_score(delta_score: int) -> void:
	_score += delta_score
	if _game_hud:
		_game_hud.set_score(_score)


func _end_match(title: String, summary: String) -> void:
	if _match_ended:
		return
	_match_ended = true
	if _player:
		_player.set_movement_locked(true)
	if _assassin_list_ui:
		_assassin_list_ui.set_input_locked(true)
	if _game_hud:
		_game_hud.show_end_screen(title, summary)


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _on_menu_requested() -> void:
	# TODO: Přechod do hlavního menu, až ho kolega dodělá (např. get_tree().change_scene_to_file(...))
	pass
