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

	_director.npc_died.connect(_on_npc_died)
	_director.quest_npc_interacted.connect(_on_quest_npc_interacted)
	_director.level_activated.connect(_on_level_activated)
	_player.killed_by_assassin.connect(_on_player_killed)

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


func _process(delta: float) -> void:
	if _match_ended:
		return

	# Omezení pohybu hráče na celkovou šířku 3 levelů
	_player.global_position.x = clampf(_player.global_position.x, _world_min_x, _world_max_x)

	# Detekce přechodu hráče do jiného levelu
	var zone := _director.get_zone_for_x(_player.global_position.x)
	if zone and zone.level_id != _director.active_level_id:
		_director.activate_level(zone.level_id)

	_update_camera_clamp(delta)
	_update_match_clock(delta)


func _update_camera_clamp(delta: float) -> void:
	if not _active_zone or not _player_camera:
		return

	var min_cam_x := _active_zone.min_x + camera_half_width
	var max_cam_x := _active_zone.max_x - camera_half_width
	var target_world_x := (
		(_active_zone.min_x + _active_zone.max_x) * 0.5
		if min_cam_x > max_cam_x
		else clampf(_player.global_position.x, min_cam_x, max_cam_x)
	)
	var desired_local_x := target_world_x - _player.global_position.x
	_player_camera.position.x = lerpf(
		_player_camera.position.x,
		desired_local_x,
		clampf(camera_smooth_speed * delta, 0.0, 1.0)
	)


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
	if _game_hud:
		_game_hud.show_end_screen(title, summary)
