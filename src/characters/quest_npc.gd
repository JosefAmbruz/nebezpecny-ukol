class_name QuestNpc
extends CharacterBody3D

enum Role {
	PADRINO_PACATO,      # Level 1: fixní pozice na startu, imunita, odevzdání questu
	MADRINA_METTICULOSA, # Level 2: chodí po levelu s balónky, dává balónek
	PADRINO_MORETTI,     # Level 3: chodí po levelu, dává AAA baterku
}

signal quest_interacted(npc: QuestNpc, actor: Node3D, role: Role)

const BALLOON_SCENE: PackedScene = preload("res://src/characters/balloon_visual.tscn")
const DEFAULT_HAT_SCENE: PackedScene = preload("res://assets/hair/bowler_hat.tscn")

@export var role: Role = Role.PADRINO_PACATO
@export var display_name: String = "Padrino Pacato"
@export var visuals: CharacterVisuals
@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if visuals and value:
			visuals.appearance = value
			if not value.headwear_scene and default_hat_scene:
				visuals.set_headwear(default_hat_scene)
@export var default_hat_scene: PackedScene = DEFAULT_HAT_SCENE
@export var interactable: InteractableNpc
@export var immunity_zone: SafeObject
@export var balloon_bunch: Node3D

@export_group("Movement")
@export var walk_speed: float = 1.6
@export var gravity: float = 18.0
@export var level_min_x: float = -13.0
@export var level_max_x: float = 13.0

@export_group("Audio (Dabing)")
@export var voice_on_interact: AudioStream

@onready var _voice_player: AudioStreamPlayer3D = get_node_or_null("VoicePlayer") as AudioStreamPlayer3D

var _looking_right: bool = true
var _wander_target_x: float = 0.0
var _idle_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Layer 1: WorldGeometry
	add_to_group(&"quest_npcs")

	if interactable:
		interactable.interaction_kind = InteractableNpc.InteractionKind.QUEST

	if visuals:
		if appearance:
			visuals.appearance = appearance
		if (not appearance or not appearance.headwear_scene) and default_hat_scene:
			visuals.set_headwear(default_hat_scene)

	_configure_by_role()
	$NameMarker.text = display_name
	_pick_new_wander_target()


func _configure_by_role() -> void:
	match role:
		Role.PADRINO_PACATO:
			display_name = "Padrino Pacato"
			if immunity_zone:
				immunity_zone.is_passive_immunity = true
				immunity_zone.monitorable = true
			_set_balloon_bunch_visible(false)
		Role.MADRINA_METTICULOSA:
			display_name = "Madrina Metticulosa"
			if immunity_zone:
				immunity_zone.monitorable = false
			_set_balloon_bunch_visible(true)
		Role.PADRINO_MORETTI:
			display_name = "Padrino Moretti"
			if immunity_zone:
				immunity_zone.monitorable = false
			_set_balloon_bunch_visible(false)


func _set_balloon_bunch_visible(show_balloons: bool) -> void:
	if not balloon_bunch:
		return
	for child in balloon_bunch.get_children():
		child.queue_free()
	if not show_balloons:
		return
	var offsets := [
		Vector3(-0.35, 0.1, 0.0),
		Vector3(0.0, 0.25, -0.05),
		Vector3(0.35, 0.05, 0.05),
	]
	for offset in offsets:
		var b := BALLOON_SCENE.instantiate() as Node3D
		b.position = offset
		balloon_bunch.add_child(b)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if role == Role.PADRINO_PACATO:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if visuals:
			visuals.look_forward()
			visuals.play_state(&"idle")
		return

	if _idle_timer > 0.0:
		velocity.x = 0.0
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_pick_new_wander_target()
	else:
		var dist := _wander_target_x - global_position.x
		if absf(dist) <= 0.25:
			velocity.x = 0.0
			_idle_timer = randf_range(1.5, 3.0)
		else:
			var dir := signf(dist)
			velocity.x = dir * walk_speed
			_looking_right = dir > 0.0

	velocity.z = 0.0
	move_and_slide()

	if visuals:
		var look_x := 2.5 if _looking_right else -2.5
		visuals.look_at_world_point(global_position + Vector3(look_x, 1.25, 2.0))
		if absf(velocity.x) > 0.1:
			visuals.set_facing_right(velocity.x > 0.0)
			visuals.play_state(&"run", velocity.x)
		else:
			visuals.play_state(&"idle")


func _pick_new_wander_target() -> void:
	_wander_target_x = randf_range(level_min_x + 2.0, level_max_x - 2.0)


func can_be_interacted_by(actor: Node3D) -> bool:
	if actor is Player:
		match role:
			Role.MADRINA_METTICULOSA:
				return not actor.has_balloon
			Role.PADRINO_MORETTI:
				return actor.has_balloon and not actor.has_battery
			Role.PADRINO_PACATO:
				return actor.has_balloon and actor.has_battery
	return false


func on_interaction_completed(actor: Node3D, _kind: InteractableNpc.InteractionKind) -> void:
	if voice_on_interact and _voice_player:
		AudioManager.play_voice_3d(_voice_player, voice_on_interact)
	quest_interacted.emit(self, actor, role)
