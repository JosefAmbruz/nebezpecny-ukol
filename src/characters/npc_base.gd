class_name NpcBase
extends CharacterBody3D

enum State {
	WANDER,
	LEAN,
	STALK,
	ATTACK,
	FLEE,
	DEAD,
}

signal died(npc: NpcBase, killer: Node3D)
signal fled_level(npc: NpcBase, exit_side: int) # -1 = vlevo, +1 = vpravo

const BALLOON_SCENE: PackedScene = preload("res://src/characters/balloon_visual.tscn")

@export var visuals: CharacterVisuals
@export var interactable: InteractableNpc
@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if visuals and value:
			visuals.appearance = value
@export var is_assassin: bool = false
@export var display_name: String = "NPC"

@export_group("Movement & Bounds")
@export var walk_speed: float = 2.2
@export var flee_speed: float = 6.0
@export var gravity: float = 18.0
@export var level_min_x: float = -13.0
@export var level_max_x: float = 13.0

@export_group("Wander & Lean")
@export var idle_time_range: Vector2 = Vector2(1.2, 3.2)
@export var lean_chance: float = 0.28
@export var lean_duration_range: Vector2 = Vector2(3.0, 6.0)
@export var glance_interval_range: Vector2 = Vector2(1.4, 3.0)

@export_group("Head Look Variety")
@export var camera_glance_interval_range: Vector2 = Vector2(2.5, 6.0)
@export var camera_glance_duration_range: Vector2 = Vector2(0.9, 2.0)
@export var vertical_look_interval_range: Vector2 = Vector2(1.5, 4.0)
@export var vertical_look_range: float = 1.1

@export_group("Assassin AI")
@export var detect_range: float = 6.5
@export var attack_range: float = 1.9
@export var attack_duration: float = 1.8
@export var stalk_trigger_chance_per_sec: float = 0.14
@export var balloon_detect_multiplier: float = 2.5
@export var post_abort_cooldown: float = 4.0

var state: State = State.WANDER
var has_balloon: bool = false:
	set(value):
		has_balloon = value
		_sync_balloon_visual()
var character_data: CharacterData = null

var _balloon_instance: Node3D = null

var _looking_right: bool = true
var _wander_target_x: float = 0.0
var _idle_timer: float = 0.0
var _glance_timer: float = 0.0

var _camera_glance_cooldown: float = 0.0
var _camera_glance_time_left: float = 0.0
var _vertical_look_timer: float = 0.0
var _vertical_look_offset: float = 0.0

var _target_safe_object: SafeObject = null
var _is_leaning: bool = false
var _lean_timer: float = 0.0

var _stalk_target: Node3D = null
var _stalk_pause_timer: float = 0.0
var _attack_elapsed: float = 0.0
var _attack_cooldown: float = 0.0
var _flee_exit_side: int = 1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Layer 1: WorldGeometry

	add_to_group(&"npcs")
	if is_assassin:
		add_to_group(&"assassins")

	if visuals and appearance:
		visuals.appearance = appearance

	_looking_right = randf() > 0.5
	_pick_new_wander_target()
	_reset_glance_timer()
	_camera_glance_cooldown = randf_range(0.8, camera_glance_interval_range.y)
	_vertical_look_timer = randf_range(0.5, vertical_look_interval_range.y)
	_sync_balloon_visual()


func _sync_balloon_visual() -> void:
	if not is_node_ready():
		return
	var anchor := get_node_or_null("BalloonAnchor") as Node3D
	if not anchor:
		return
	if has_balloon and not is_instance_valid(_balloon_instance):
		_balloon_instance = BALLOON_SCENE.instantiate() as Node3D
		anchor.add_child(_balloon_instance)
	elif not has_balloon and is_instance_valid(_balloon_instance):
		_balloon_instance.queue_free()
		_balloon_instance = null


func apply_character_data(data: CharacterData) -> void:
	character_data = data
	if not data:
		return
	display_name = data.display_name
	is_assassin = data.is_assassin
	has_balloon = data.quest_stage >= CharacterData.QuestStage.HAS_BALLOON
	if data.appearance:
		appearance = data.appearance
	if is_assassin:
		add_to_group(&"assassins")
	elif is_in_group(&"assassins"):
		remove_from_group(&"assassins")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	match state:
		State.WANDER:
			_process_wander(delta)
			if is_assassin:
				_try_acquire_stalk_target(delta)
		State.LEAN:
			_process_lean(delta)
		State.STALK:
			_process_stalk(delta)
		State.ATTACK:
			_process_attack(delta)
		State.FLEE:
			_process_flee(delta)

	velocity.z = 0.0
	move_and_slide()
	_update_head_look_variety(delta)
	_update_visuals()


#region Wander & Lean

func _process_wander(delta: float) -> void:
	if _target_safe_object and is_instance_valid(_target_safe_object):
		var dist_to_safe := _target_safe_object.global_position.x - global_position.x
		if absf(dist_to_safe) <= 0.45:
			if _target_safe_object.can_lean(self):
				_enter_lean(_target_safe_object)
				return
			else:
				_target_safe_object = null
		else:
			_move_horizontally(signf(dist_to_safe), walk_speed)
			return

	if _idle_timer > 0.0:
		velocity.x = 0.0
		_idle_timer -= delta
		_process_periodic_glance(delta)
		if _idle_timer <= 0.0:
			if randf() < lean_chance:
				_target_safe_object = _find_nearby_safe_object()
			if not _target_safe_object:
				_pick_new_wander_target()
		return

	var dist := _wander_target_x - global_position.x
	if absf(dist) <= 0.25:
		velocity.x = 0.0
		_idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
		_reset_glance_timer()
	else:
		_move_horizontally(signf(dist), walk_speed)


func _enter_lean(safe_obj: SafeObject) -> void:
	state = State.LEAN
	_is_leaning = true
	velocity.x = 0.0
	safe_obj.register_occupant(self)
	_lean_timer = randf_range(lean_duration_range.x, lean_duration_range.y)
	_reset_glance_timer()


func _process_lean(delta: float) -> void:
	velocity.x = 0.0
	_lean_timer -= delta
	_process_periodic_glance(delta)
	if _lean_timer <= 0.0:
		_exit_lean()
		state = State.WANDER
		_pick_new_wander_target()


func _exit_lean() -> void:
	_is_leaning = false
	if _target_safe_object and is_instance_valid(_target_safe_object):
		_target_safe_object.unregister_occupant(self)
	_target_safe_object = null


func _pick_new_wander_target() -> void:
	var offset := randf_range(-6.0, 6.0)
	if absf(offset) < 1.5:
		offset = 2.5 if randf() > 0.5 else -2.5
	_wander_target_x = clampf(global_position.x + offset, level_min_x, level_max_x)


func _find_nearby_safe_object() -> SafeObject:
	var candidates: Array[SafeObject] = []
	for node in get_tree().get_nodes_in_group(&"safe_objects"):
		var obj := node as SafeObject
		if not obj or obj.is_passive_immunity or not obj.can_lean(self):
			continue
		if absf(obj.global_position.x - global_position.x) <= 7.0:
			candidates.append(obj)
	if candidates.is_empty():
		return null
	return candidates.pick_random()


func _process_periodic_glance(delta: float) -> void:
	_glance_timer -= delta
	if _glance_timer <= 0.0:
		_looking_right = not _looking_right
		_reset_glance_timer()


func _reset_glance_timer() -> void:
	_glance_timer = randf_range(glance_interval_range.x, glance_interval_range.y)

#endregion


#region Assassin AI (Stalk, Attack, Flee)

func alert_to_stalk(target: Node3D) -> void:
	if not is_assassin or state in [State.DEAD, State.FLEE, State.ATTACK]:
		return
	if _is_leaning:
		_exit_lean()
	_stalk_target = target
	_stalk_pause_timer = 0.0
	state = State.STALK


func _try_acquire_stalk_target(delta: float) -> void:
	if _attack_cooldown > 0.0:
		return

	var potential_targets: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D and _is_valid_attack_target(node):
			potential_targets.append(node)
	for node in get_tree().get_nodes_in_group(&"assassins"):
		if node != self and node is Node3D and _is_valid_attack_target(node):
			potential_targets.append(node)

	for target in potential_targets:
		var dist := absf(target.global_position.x - global_position.x)
		if dist > detect_range:
			continue
		var chance := stalk_trigger_chance_per_sec * delta
		if target.get(&"has_balloon") == true:
			chance *= balloon_detect_multiplier
		if randf() < chance:
			_stalk_target = target
			_stalk_pause_timer = 0.0
			state = State.STALK
			return


func _process_stalk(delta: float) -> void:
	if not _is_valid_attack_target(_stalk_target):
		_stalk_target = null
		state = State.WANDER
		_pick_new_wander_target()
		return

	var dist_x := _stalk_target.global_position.x - global_position.x
	var abs_dist := absf(dist_x)

	# Pokud je blízko, cíl není v bezpečí a nedívá se na nás -> zahájíme nenápadný útok kartáčkem
	if abs_dist <= attack_range and not _target_is_safe(_stalk_target) and not _target_is_looking_at_me(_stalk_target):
		_looking_right = dist_x >= 0.0
		_attack_elapsed = 0.0
		state = State.ATTACK
		return

	# Simuluje nenápadnou chůzi (občas krátce zastaví), ale postupně se přibližuje
	if _stalk_pause_timer > 0.0:
		velocity.x = 0.0
		_stalk_pause_timer -= delta
		return

	if abs_dist > attack_range * 0.75:
		_move_horizontally(signf(dist_x), walk_speed * 0.95)
		if randf() < 0.25 * delta:
			_stalk_pause_timer = randf_range(0.4, 1.0)
	else:
		# Čeká kousek za cílem na vhodný okamžik
		velocity.x = 0.0
		_looking_right = dist_x >= 0.0


func _process_attack(delta: float) -> void:
	if not _is_valid_attack_target(_stalk_target):
		_abort_attack()
		return

	var dist_x := _stalk_target.global_position.x - global_position.x
	if absf(dist_x) > attack_range * 1.15:
		state = State.STALK
		return

	# Hráč (nebo jiný assassin) se na nás podíval nebo se opřel -> přerušíme útok a děláme nenápadného
	if _target_is_safe(_stalk_target) or _target_is_looking_at_me(_stalk_target):
		_abort_attack()
		return

	velocity.x = 0.0
	_looking_right = dist_x >= 0.0
	_attack_elapsed += delta

	if _attack_elapsed >= attack_duration:
		if visuals:
			visuals.play_state(&"attack")
		if _stalk_target.has_method(&"on_killed_by_assassin"):
			_stalk_target.call(&"on_killed_by_assassin", self)
		elif _stalk_target.has_method(&"on_interaction_completed"):
			_stalk_target.call(&"on_interaction_completed", self, InteractableNpc.InteractionKind.ASSASSINATE)
		_stalk_target = null
		_attack_elapsed = 0.0
		_attack_cooldown = post_abort_cooldown
		state = State.WANDER
		_pick_new_wander_target()


func _abort_attack() -> void:
	_attack_elapsed = 0.0
	_stalk_target = null
	_attack_cooldown = post_abort_cooldown
	state = State.WANDER
	_pick_new_wander_target()


func _enter_flee() -> void:
	if _is_leaning:
		_exit_lean()
	_stalk_target = null
	_attack_elapsed = 0.0
	state = State.FLEE

	# Vybere nejbližší okraj levelu (napojený level)
	var dist_left := absf(global_position.x - level_min_x)
	var dist_right := absf(level_max_x - global_position.x)
	_flee_exit_side = -1 if dist_left < dist_right else 1


func _process_flee(_delta: float) -> void:
	_move_horizontally(float(_flee_exit_side), flee_speed)
	var reached_left := _flee_exit_side < 0 and global_position.x <= level_min_x + 0.3
	var reached_right := _flee_exit_side > 0 and global_position.x >= level_max_x - 0.3
	if reached_left or reached_right:
		fled_level.emit(self, _flee_exit_side)
		queue_free()

#endregion


#region InteractableNpc Callbacks & Helpers

func is_safe_from_attack() -> bool:
	return _is_leaning or state == State.DEAD


func is_looking_at(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	var target_is_right := target.global_position.x >= global_position.x
	return target_is_right == _looking_right


func on_caught_assassination_attempt(_attacker: Node3D) -> void:
	if state == State.DEAD:
		return
	if is_assassin:
		_enter_flee()
	# Civilista po vyplašení chodí normálně dál


func on_interaction_completed(actor: Node3D, kind: InteractableNpc.InteractionKind) -> void:
	if state == State.DEAD:
		return
	if kind == InteractableNpc.InteractionKind.ASSASSINATE:
		if _is_leaning:
			_exit_lean()
		state = State.DEAD
		velocity = Vector3.ZERO
		if interactable:
			interactable.monitorable = false
		died.emit(self, actor)
		if not is_assassin and actor and actor.is_in_group(&"player"):
			_alert_nearby_assassins(actor)
		queue_free()


func _alert_nearby_assassins(player_node: Node3D, max_count: int = 3) -> void:
	var assassins: Array[NpcBase] = []
	for node in get_tree().get_nodes_in_group(&"assassins"):
		var npc := node as NpcBase
		if npc and npc != self and npc.state != State.DEAD and npc.state != State.FLEE:
			assassins.append(npc)

	assassins.sort_custom(func(a: NpcBase, b: NpcBase) -> bool:
		return absf(a.global_position.x - global_position.x) < absf(b.global_position.x - global_position.x)
	)

	var alerted := 0
	for npc in assassins:
		if alerted >= max_count:
			break
		npc.alert_to_stalk(player_node)
		alerted += 1


func _is_valid_attack_target(target: Variant) -> bool:
	if not is_instance_valid(target) or not (target is Node3D):
		return false
	if target is Player:
		return target.is_alive
	if target is NpcBase:
		return target.state != State.DEAD and target.state != State.FLEE
	return false


func _target_is_safe(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method(&"is_safe_from_attack"):
		return target.call(&"is_safe_from_attack")
	return false


func _target_is_looking_at_me(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method(&"is_looking_at"):
		return target.call(&"is_looking_at", self)
	return false


func _move_horizontally(dir: float, speed: float) -> void:
	velocity.x = dir * speed
	if absf(dir) > 0.01:
		_looking_right = dir > 0.0


func _update_head_look_variety(delta: float) -> void:
	if state in [State.ATTACK, State.FLEE, State.DEAD]:
		_camera_glance_time_left = 0.0
		_vertical_look_offset = 0.0
		return

	if _camera_glance_time_left > 0.0:
		_camera_glance_time_left -= delta
		if _camera_glance_time_left <= 0.0:
			_camera_glance_cooldown = randf_range(
				camera_glance_interval_range.x,
				camera_glance_interval_range.y
			)
	else:
		_camera_glance_cooldown -= delta
		if _camera_glance_cooldown <= 0.0:
			_camera_glance_time_left = randf_range(
				camera_glance_duration_range.x,
				camera_glance_duration_range.y
			)

	_vertical_look_timer -= delta
	if _vertical_look_timer <= 0.0:
		# Občas se podívá rovně, občas nahoru nebo dolů
		_vertical_look_offset = 0.0 if randf() < 0.4 else randf_range(-vertical_look_range, vertical_look_range)
		_vertical_look_timer = randf_range(
			vertical_look_interval_range.x,
			vertical_look_interval_range.y
		)


func _update_visuals() -> void:
	if not visuals:
		return

	var look_point: Vector3
	if _camera_glance_time_left > 0.0:
		# Přirozený pohled směrem do kamery, aby byl obličej dobře čitelný
		var subtle_x := 0.35 if _looking_right else -0.35
		look_point = global_position + Vector3(subtle_x, 1.25 + _vertical_look_offset * 0.5, 4.0)
	else:
		var look_offset_x := 3.0 if _looking_right else -3.0
		look_point = global_position + Vector3(look_offset_x, 1.25 + _vertical_look_offset, 0.8)

	visuals.look_at_world_point(look_point)

	if _is_leaning:
		visuals.play_state(&"lean")
	elif absf(velocity.x) > 0.1:
		visuals.set_facing_right(velocity.x > 0.0)
		visuals.play_state(&"run")
	else:
		visuals.set_facing_right(_looking_right)
		visuals.play_state(&"idle")

#endregion
