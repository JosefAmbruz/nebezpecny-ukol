extends Node3D

const DEFENSE_TIME_SCALE := 0.18
## Od této části zápasu assassini postupně přitvrzují.
const LATE_PRESSURE_START := 0.6

@export var appearance_pool: AppearancePool = preload("res://src/characters/default_appearance_pool.tres")
@export var total_assassins: int = 8
@export var quest_assassins: int = 4

@export_group("Match Rules (18:00 - 19:00)")
@export var match_duration_seconds: float = 300.0
@export var max_toothbrushes: int = 3
@export var score_assassin_kill: int = 100
@export var score_civilian_penalty: int = -50
@export var score_quest_bonus: int = 300
@export var score_silent_bonus: int = 50
## Každý další assassin v řadě bez chyby přidá k násobiči tuto hodnotu.
@export var combo_step: float = 0.5
@export var max_combo_multiplier: float = 3.0

@export_group("Camera")
@export var camera_half_width: float = 6.0
@export var camera_smooth_speed: float = 6.0
@export var list_zoom_factor: float = 0.65
@export var list_zoom_duration: float = 0.35
@export var list_zoom_x_offset: float = 0.9
@export var assassinate_zoom_factor: float = 0.82
@export var assassinate_focus_y_offset: float = 1.2
@export var assassinate_zoom_return_duration: float = 0.32

@export_group("Audio (Hudba & SFX)")
@export var background_music: AudioStream
@export var sfx_assassin_tag: AudioStream
@export var sfx_brush_break: AudioStream
@export var sfx_quest_progress: AudioStream
@export var sfx_list_toggle: AudioStream
@export var sfx_player_killed: AudioStream

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
var _assassins_eliminated: int = 0
var _broken_toothbrushes: int = 0
var _quest_completed: bool = false
var _kill_streak: int = 0
var _best_streak: int = 0
var _silent_kills: int = 0
var _match_ended: bool = false
var _defense_attacker: NpcBase
var _defense_deadline_ms: int = 0
var _normal_time_scale: float = 1.0
var _defense_window_ms: int = 1500


func _init() -> void:
	var preset := Difficulty.get_preset()
	total_assassins = preset["total_assassins"]
	match_duration_seconds = preset["match_duration_seconds"]
	max_toothbrushes = preset["max_toothbrushes"]
	_defense_window_ms = preset["defense_window_ms"]


func _ready() -> void:
	for child in _levels_root.get_children():
		if child is LevelZone:
			_levels.append(child)
	_player.reaction_grace_time = Difficulty.get_preset()["reaction_grace_time"]
	_player.distractions_left = Difficulty.get_preset()["distractions"]
	NpcBase.late_pressure = 0.0
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
	_director.rival_found_battery.connect(_on_rival_found_battery)
	_player.defense_requested.connect(_start_defense)
	_player.killed_by_assassin.connect(_on_player_killed)
	_player.assassination_spotted.connect(_break_combo)
	_player.distraction_thrown.connect(func(_point: Vector3, left: int) -> void: _game_hud.set_distractions(left))
	_player.interaction_started.connect(_on_player_interaction_started)
	_player.interaction_progress_changed.connect(_on_player_interaction_progress_changed)
	_player.interaction_cancelled.connect(_on_player_interaction_ended)
	_player.interaction_completed.connect(_on_player_interaction_completed)
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

	if _game_hud:
		_game_hud.set_toothbrushes(max_toothbrushes, _broken_toothbrushes)
		_game_hud.set_distractions(_player.distractions_left)

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

	if background_music and (not _active_zone or not _active_zone.music_override):
		AudioManager.play_music(background_music)


func _physics_process(delta: float) -> void:
	if _match_ended or _defense_deadline_ms != 0:
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
	if _defense_deadline_ms != 0:
		if not is_instance_valid(_defense_attacker) or _defense_attacker.state == NpcBase.State.DEAD:
			_finish_defense(true)
			return
		var remaining_ms := _defense_deadline_ms - Time.get_ticks_msec()
		if remaining_ms <= 0:
			_finish_defense(false)
		else:
			_game_hud.set_defense_progress(float(remaining_ms) / _defense_window_ms)
		return
	_update_match_clock(delta)


func _input(event: InputEvent) -> void:
	if _defense_deadline_ms == 0:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_finish_defense(Time.get_ticks_msec() < _defense_deadline_ms)


func _exit_tree() -> void:
	NpcBase.late_pressure = 0.0
	if _defense_deadline_ms != 0:
		Engine.time_scale = _normal_time_scale


func _start_defense(attacker: NpcBase) -> void:
	if _match_ended or _defense_deadline_ms != 0:
		if attacker != _defense_attacker and attacker.visuals:
			attacker.visuals.cancel_attack_windup()
		return
	_defense_attacker = attacker
	_defense_deadline_ms = Time.get_ticks_msec() + _defense_window_ms
	_normal_time_scale = Engine.time_scale
	Engine.time_scale *= DEFENSE_TIME_SCALE
	_player.set_movement_locked(true)
	_assassin_list_ui.hide()
	$InteractionIndicator.hide()
	attacker.set_physics_process(false)
	if attacker.visuals:
		attacker.visuals.play_attack_windup(_player, _player_camera.global_position.z - 2.0)
	var focus_x := lerpf(attacker.global_position.x, _player.global_position.x, 0.2)
	var camera_tween := _zoom_camera(_camera_base_size * 0.48, 0.28).set_parallel()
	camera_tween.tween_property(_player_camera, "global_position:x", focus_x, 0.28)
	camera_tween.tween_property(_player_camera, "global_position:y", _player.global_position.y + 1.15, 0.28)
	_game_hud.show_defense_prompt()


func _finish_defense(defended: bool) -> void:
	var attacker := _defense_attacker
	var attacker_active := is_instance_valid(attacker) and attacker.state != NpcBase.State.DEAD
	defended = defended or not attacker_active or _player.is_safe_from_attack()
	_defense_attacker = null
	_defense_deadline_ms = 0
	Engine.time_scale = _normal_time_scale
	_game_hud.finish_defense_prompt(defended)
	if attacker_active:
		attacker.set_physics_process(true)
		if defended:
			attacker.stun_after_defense(_player)
		if attacker.visuals:
			if defended:
				attacker.visuals.cancel_attack_windup()
			else:
				attacker.visuals.play_attack(_player)

	if defended:
		_assassin_list_ui.show()
		$InteractionIndicator.show()
		_on_assassin_list_visibility_changed(_is_list_open)
	else:
		_player.on_killed_by_assassin(attacker)


func _on_assassin_list_visibility_changed(is_open: bool) -> void:
	_is_list_open = is_open
	_player.set_movement_locked(is_open)
	AudioManager.play_sfx(sfx_list_toggle)

	if not _player_camera:
		return
	var target_size := _camera_base_size * list_zoom_factor if is_open else _camera_base_size
	_zoom_camera(target_size, list_zoom_duration)


func _zoom_camera(target_size: float, duration: float) -> Tween:
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()

	_camera_zoom_tween = create_tween().set_ignore_time_scale(true)
	_camera_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_zoom_tween.set_ease(Tween.EASE_OUT)
	_camera_zoom_tween.tween_property(_player_camera, "size", target_size, duration)
	return _camera_zoom_tween


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
		var cursor_point := _player.get_cursor_world_point()
		# Kubická ease-out křivka: rychlý dramatický nástup na oběť, ke konci zpomaluje
		var eased := 1.0 - pow(1.0 - _assassinate_progress, 3.0)
		_player_camera.size = lerpf(_camera_base_size, _camera_base_size * assassinate_zoom_factor, eased)

		if is_instance_valid(_assassinate_target):
			var victim_pos := _assassinate_target.global_position
			var cam_pos := _player_camera.global_position
			cam_pos.x = lerpf(_assassinate_start_cam_pos.x, victim_pos.x, eased)
			cam_pos.y = lerpf(_assassinate_start_cam_pos.y, victim_pos.y + assassinate_focus_y_offset, eased)
			_player_camera.global_position = cam_pos
		_player_camera.global_position += cursor_point - _player.get_cursor_world_point()
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
	var was_calm := NpcBase.late_pressure == 0.0
	NpcBase.late_pressure = clampf((progress - LATE_PRESSURE_START) / (1.0 - LATE_PRESSURE_START), 0.0, 1.0)
	if _game_hud:
		_game_hud.set_clock_progress(progress)
		if was_calm and NpcBase.late_pressure > 0.0:
			_game_hud.show_event("Blíží se 19:00. Assassini znervózněli a útočí odvážněji.")

	if _elapsed_time >= match_duration_seconds:
		_end_match("Čas vypršel (19:00)", "Tvoje konečné skóre: %d" % _score)


func _on_level_activated(zone: LevelZone) -> void:
	_active_zone = zone
	if _game_hud:
		_game_hud.set_level(zone.level_name, zone.level_id)
	AudioManager.play_ambient(zone.ambient_stream)
	AudioManager.set_ambient_oneshots(zone.ambient_oneshots)
	if zone.music_override:
		AudioManager.play_music(zone.music_override)
	elif background_music:
		AudioManager.play_music(background_music)


func _on_rival_found_battery(data: CharacterData, zone: LevelZone) -> void:
	if not _match_ended and zone:
		_game_hud.show_rival_battery(data.display_name, zone.level_name)


func _on_npc_died(npc: NpcBase, killer: Node3D) -> void:
	if npc.character_data and npc.character_data.is_assassin and _assassin_list_ui:
		_assassin_list_ui.mark_assassin_dead(npc.character_data.id)

	var points := score_assassin_kill if npc.is_assassin else score_civilian_penalty
	if killer == _player:
		AudioManager.play_sfx(sfx_assassin_tag if npc.is_assassin else sfx_brush_break)
		var notes := PackedStringArray()
		if npc.is_assassin:
			_kill_streak += 1
			_best_streak = maxi(_best_streak, _kill_streak)
			if _kill_streak > 1:
				points = roundi(points * _combo_multiplier(_kill_streak))
				notes.append("Kombo ×%s" % _format_multiplier(_combo_multiplier(_kill_streak)))
			if npc.witness_count == 0:
				points += score_silent_bonus
				_silent_kills += 1
				notes.append("Tiše +%d" % score_silent_bonus)
		else:
			_kill_streak = 0
		_add_score(points)
		if npc.visuals:
			npc.visuals.show_score_popup(points, " · ".join(notes))
		if npc.is_assassin:
			_assassins_eliminated += 1
		else:
			_broken_toothbrushes += 1
			_game_hud.set_toothbrushes(max_toothbrushes, _broken_toothbrushes)
			if _broken_toothbrushes >= max_toothbrushes:
				_end_match("Zlomil jsi všechny kartáčky!", "Omylem jsi vyřadil %d civilisty.\nKonečné skóre: %d" % [_broken_toothbrushes, _score])
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
				AudioManager.play_sfx(sfx_quest_progress)
		QuestNpc.Role.PADRINO_MORETTI:
			if _player.has_balloon and not _player.has_battery:
				_player.has_battery = true
				AudioManager.play_sfx(sfx_quest_progress)
		QuestNpc.Role.PADRINO_PACATO:
			if _player.has_balloon and _player.has_battery and not _quest_completed:
				_quest_completed = true
				_player.has_balloon = false
				_player.has_battery = false
				AudioManager.play_sfx(sfx_quest_progress)
				_add_score(score_quest_bonus)

	if _game_hud:
		_game_hud.set_quest_state(_player.has_balloon, _player.has_battery, _quest_completed)


func _on_player_killed(attacker: Node3D, death_animation: Tween) -> void:
	AudioManager.play_sfx(sfx_player_killed)
	_director.spawn_death_mark(_player.global_position, "Ty (Hráč)", true)

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
	_refresh_score_hud()


func _break_combo() -> void:
	_kill_streak = 0
	_refresh_score_hud()


## Násobič pro n-tého assassina v řadě: 1. ×1, 2. ×1.5, 3. ×2, ...
func _combo_multiplier(streak: int) -> float:
	return minf(1.0 + combo_step * maxi(0, streak - 1), max_combo_multiplier)


func _format_multiplier(multiplier: float) -> String:
	return ("%.1f" % multiplier).trim_suffix(".0")


func _refresh_score_hud() -> void:
	if not _game_hud:
		return
	# HUD ukazuje násobič, který dostane příští likvidace
	var combo := "" if _kill_streak == 0 else "Další ×%s" % _format_multiplier(_combo_multiplier(_kill_streak + 1))
	_game_hud.set_score(_score, combo)


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
		var results := "%s\nVyřazení assassini: %d\nTiché likvidace: %d\nNejdelší kombo: %d\nZasažení civilisté: %d\nÚkol: %s" % [
			summary, _assassins_eliminated, _silent_kills, _best_streak, _broken_toothbrushes, "splněn" if _quest_completed else "nesplněn"
		]
		_game_hud.show_end_screen(title, results, _format_leaderboard())
