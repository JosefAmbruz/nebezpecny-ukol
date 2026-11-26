class_name Player
extends CharacterBody3D

signal interaction_started(target: InteractableNpc, kind: InteractableNpc.InteractionKind)
signal interaction_progress_changed(progress: float, kind: InteractableNpc.InteractionKind)
signal interaction_cancelled
signal interaction_completed(target: InteractableNpc, kind: InteractableNpc.InteractionKind)
signal safe_state_changed(is_safe: bool, can_lean: bool)
signal killed_by_assassin(attacker: Node3D)

const INTERACTABLE_NPC_MASK: int = 1 << 1 # Layer 2: InteractableNPC
const BALLOON_SCENE: PackedScene = preload("res://src/characters/balloon_visual.tscn")

@export var visuals: CharacterVisuals
@export var safe_detector: Area3D

@export_group("Movement")
@export var move_speed: float = 4.5
@export var gravity: float = 18.0

@export_group("Interaction (Kartáček & Quest)")
@export var interact_range: float = 2.0
## Krátké okno pro reakci hráče, aby stihl pustit tlačítko myši, když se NPC otočí.
@export var reaction_grace_time: float = 0.22
@export var raycast_length: float = 100.0

@export_group("Lean / Safe")
@export var lean_cooldown: float = 1.5

var has_balloon: bool = false:
	set(value):
		has_balloon = value
		_sync_balloon_visual()
var has_battery: bool = false
var is_alive: bool = true
var movement_locked: bool = false

var _balloon_instance: Node3D = null

var _cursor_world_point: Vector3 = Vector3.ZERO
var _looking_right: bool = true

var _overlapping_safe_objects: Array[SafeObject] = []
var _current_lean_object: SafeObject = null
var _is_leaning: bool = false
var _lean_time_left: float = 0.0
var _lean_cooldown_left: float = 0.0
var _last_reported_safe: bool = false
var _last_reported_can_lean: bool = false

var _active_target: InteractableNpc = null
var _interact_elapsed: float = 0.0
var _caught_grace_elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 0
	collision_mask = 1 # Layer 1: WorldGeometry

	if visuals:
		visuals.hit_frame.connect(_on_attack_hit)

	if safe_detector:
		safe_detector.area_entered.connect(_on_safe_area_entered)
		safe_detector.area_exited.connect(_on_safe_area_exited)

	_sync_balloon_visual()


func _sync_balloon_visual() -> void:
	if not is_node_ready():
		return
	var anchor: Node3D = visuals.get_balloon_anchor() if visuals else null
	if not anchor:
		anchor = get_node_or_null("BalloonAnchor") as Node3D
	if not anchor:
		return
	if has_balloon and not is_instance_valid(_balloon_instance):
		_balloon_instance = BALLOON_SCENE.instantiate() as Node3D
		anchor.add_child(_balloon_instance)
	elif not has_balloon and is_instance_valid(_balloon_instance):
		_balloon_instance.queue_free()
		_balloon_instance = null


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_update_lean_timers(delta)
	_handle_lean_input()
	_handle_movement(delta)
	_update_gaze_and_visuals()
	_handle_interaction(delta)
	_emit_safe_state_if_changed()


func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	if locked:
		_cancel_interaction()


func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if movement_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_x := Input.get_axis(&"move_left", &"move_right")

	if _is_leaning:
		# Pohybem do strany se hráč může z opření plynule uvolnit
		if absf(input_x) > 0.1:
			_stop_leaning()
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return

	velocity.x = input_x * move_speed
	velocity.z = 0.0
	move_and_slide()


func _update_gaze_and_visuals() -> void:
	if not visuals:
		return

	if _is_leaning:
		visuals.look_forward()
		visuals.play_state(&"lean")
		return

	_cursor_world_point = get_cursor_world_point()
	_looking_right = _cursor_world_point.x >= global_position.x
	visuals.look_at_world_point(_cursor_world_point)

	if absf(velocity.x) > 0.1:
		visuals.set_facing_right(velocity.x > 0.0)
		visuals.play_state(&"run")
	else:
		visuals.set_facing_right(_looking_right)
		visuals.play_state(&"idle")


func _update_lean_timers(delta: float) -> void:
	if _lean_cooldown_left > 0.0:
		_lean_cooldown_left = maxf(0.0, _lean_cooldown_left - delta)

	if _is_leaning and _current_lean_object and _current_lean_object.max_lean_duration > 0.0:
		_lean_time_left -= delta
		if _lean_time_left <= 0.0:
			_stop_leaning()


func _handle_lean_input() -> void:
	if movement_locked:
		return
	if not Input.is_action_just_pressed(&"lean"):
		return

	if _is_leaning:
		_stop_leaning()
		return

	var lean_obj := _get_available_lean_object()
	if lean_obj:
		_start_leaning(lean_obj)


func _start_leaning(safe_obj: SafeObject) -> void:
	_cancel_interaction()
	_is_leaning = true
	_current_lean_object = safe_obj
	_lean_time_left = safe_obj.max_lean_duration
	safe_obj.register_occupant(self)


func _stop_leaning() -> void:
	if not _is_leaning:
		return
	_is_leaning = false
	if _current_lean_object:
		_current_lean_object.unregister_occupant(self)
		_current_lean_object = null
	_lean_cooldown_left = lean_cooldown


func _get_available_lean_object() -> SafeObject:
	if _lean_cooldown_left > 0.0:
		return null
	for obj in _overlapping_safe_objects:
		if is_instance_valid(obj) and obj.can_lean(self):
			return obj
	return null


func _is_in_passive_immunity_zone() -> bool:
	for obj in _overlapping_safe_objects:
		if is_instance_valid(obj) and obj.is_passive_immunity:
			return true
	return false


func is_safe_from_attack() -> bool:
	return _is_leaning or _is_in_passive_immunity_zone()


func is_looking_right() -> bool:
	return _looking_right


## Vrací true, pokud se hráč dívá směrem k danému uzlu (odvrácení útoku NPC assassina).
func is_looking_at(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	var target_is_right := target.global_position.x >= global_position.x
	return target_is_right == _looking_right


func _handle_interaction(delta: float) -> void:
	if _is_leaning or movement_locked:
		_cancel_interaction()
		return

	if Input.is_action_just_pressed(&"interact"):
		var hovered := _pick_npc_under_cursor()
		var blocked_by_immunity := (
			hovered != null
			and hovered.interaction_kind == InteractableNpc.InteractionKind.ASSASSINATE
			and _is_in_passive_immunity_zone()
		)
		if hovered and not blocked_by_immunity and _is_within_interact_range(hovered) and hovered.can_be_interacted_by(self):
			_active_target = hovered
			_interact_elapsed = 0.0
			_caught_grace_elapsed = 0.0
			interaction_started.emit(_active_target, _active_target.interaction_kind)
			interaction_progress_changed.emit(0.0, _active_target.interaction_kind)

	if not _active_target:
		return

	if not Input.is_action_pressed(&"interact"):
		_cancel_interaction()
		return

	if (
		not is_instance_valid(_active_target)
		or not _is_within_interact_range(_active_target)
		or not _active_target.can_be_interacted_by(self)
		or (_active_target.interaction_kind == InteractableNpc.InteractionKind.ASSASSINATE and _is_in_passive_immunity_zone())
	):
		_cancel_interaction()
		return

	# Kontrola, zda se cíl neotočil směrem k hráči
	if _active_target.is_looking_at(self):
		_caught_grace_elapsed += delta
		if _caught_grace_elapsed >= reaction_grace_time:
			_active_target.notify_caught_attempt(self)
			_cancel_interaction()
		return
	else:
		_caught_grace_elapsed = 0.0

	_interact_elapsed += delta
	var duration := maxf(0.05, _active_target.interaction_duration)
	var progress := clampf(_interact_elapsed / duration, 0.0, 1.0)
	interaction_progress_changed.emit(progress, _active_target.interaction_kind)

	if _interact_elapsed >= duration:
		var completed_target := _active_target
		var completed_kind := completed_target.interaction_kind
		_active_target = null
		_interact_elapsed = 0.0
		_caught_grace_elapsed = 0.0

		if completed_kind == InteractableNpc.InteractionKind.ASSASSINATE and visuals:
			visuals.play_state(&"attack")

		completed_target.complete_interaction(self)
		interaction_completed.emit(completed_target, completed_kind)


func _cancel_interaction() -> void:
	if not _active_target:
		return
	_active_target = null
	_interact_elapsed = 0.0
	_caught_grace_elapsed = 0.0
	interaction_cancelled.emit()


func _is_within_interact_range(target: InteractableNpc) -> bool:
	var root := target.get_character_root()
	return absf(root.global_position.x - global_position.x) <= interact_range


func _pick_npc_under_cursor() -> InteractableNpc:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return null

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * raycast_length

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, INTERACTABLE_NPC_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null

	return result.get("collider") as InteractableNpc


func on_killed_by_assassin(attacker: Node3D) -> void:
	if not is_alive or is_safe_from_attack():
		return
	is_alive = false
	_cancel_interaction()
	_stop_leaning()
	killed_by_assassin.emit(attacker)


func _on_attack_hit() -> void:
	# Rezerva pro zvuk/efekt ťuknutí kartáčkem přesně na snímku animace
	pass


func _on_safe_area_entered(area: Area3D) -> void:
	var safe_obj := area as SafeObject
	if safe_obj and safe_obj not in _overlapping_safe_objects:
		_overlapping_safe_objects.append(safe_obj)


func _on_safe_area_exited(area: Area3D) -> void:
	var safe_obj := area as SafeObject
	if safe_obj:
		_overlapping_safe_objects.erase(safe_obj)
		if safe_obj == _current_lean_object:
			_stop_leaning()


func _emit_safe_state_if_changed() -> void:
	var now_safe := is_safe_from_attack()
	var now_can_lean := (not _is_leaning) and (_get_available_lean_object() != null)
	if now_safe != _last_reported_safe or now_can_lean != _last_reported_can_lean:
		_last_reported_safe = now_safe
		_last_reported_can_lean = now_can_lean
		safe_state_changed.emit(now_safe, now_can_lean)


## Vrátí pozici kurzoru promítnutou na rovinu postavy
func get_cursor_world_point(camera_z_offset: float = 1.5) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return global_position + Vector3.FORWARD

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	# Svislá rovina kolmá na osu Z (předpokládá kameru na +Z hledící do -Z)
	var target_z := global_position.z + camera_z_offset
	var plane := Plane(Vector3.BACK, target_z)

	var hit_point = plane.intersects_ray(ray_origin, ray_dir)
	if hit_point != null:
		return hit_point

	return global_position + Vector3(0.0, 0.0, camera_z_offset)
