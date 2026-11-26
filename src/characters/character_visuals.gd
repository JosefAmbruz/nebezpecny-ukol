# character_visuals.gd
class_name CharacterVisuals
extends Node3D

signal action_finished(action_name: StringName)
signal hit_frame

const ATTACK_CONTACT_TIME := 0.12

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			_apply_appearance()

@export var head_turn_speed: float = 12.0
@export var max_head_yaw: float = deg_to_rad(75.0)
@export var max_head_pitch: float = deg_to_rad(35.0)

@onready var head_pivot: Node3D = $HeadPivot
@onready var head_mesh: MeshInstance3D = $HeadPivot/HeadMesh
@onready var ear_r: Sprite3D = $HeadPivot/EarR
@onready var ear_l: Sprite3D = $HeadPivot/EarR2
@onready var body_sprite: Sprite3D = $BodySprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var _toothbrush: MeshInstance3D = $Toothbrush

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _facing_right: bool = true
var _attack_tween: Tween

func _ready() -> void:
	# Zajistí, že každá instance postavy má vlastní kopii materiálu hlavy
	if head_mesh.material_override:
		head_mesh.material_override = head_mesh.material_override.duplicate()
	_apply_appearance()

func _process(delta: float) -> void:
	# Plynulé dotáčení hlavy k cílovému úhlu
	head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, _target_yaw, head_turn_speed * delta)
	head_pivot.rotation.x = lerp_angle(head_pivot.rotation.x, _target_pitch, head_turn_speed * delta)


func _apply_appearance() -> void:
	if not appearance:
		return
	
	var mat := head_mesh.get_active_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = appearance.skin_color
		mat.albedo_texture = appearance.face_texture

	if ear_r:
		ear_r.modulate = appearance.skin_color
	if ear_l:
		ear_l.modulate = appearance.skin_color

## Natočí hlavu směrem ke světové pozici (např. kurzor, hráč, podezřelý zvuk)
func look_at_world_point(world_point: Vector3) -> void:
	var local_dir := to_local(world_point) - head_pivot.position
	if local_dir.length_squared() < 0.001:
		return
	var raw_yaw := atan2(local_dir.x, local_dir.z)
	var raw_pitch := -atan2(local_dir.y, Vector2(local_dir.x, local_dir.z).length())
	
	_target_yaw = clamp(raw_yaw, -max_head_yaw, max_head_yaw)
	_target_pitch = clamp(raw_pitch, -max_head_pitch, max_head_pitch)

## Natočí hlavu přímo směrem do kamery (např. při opření)
func look_forward() -> void:
	_target_yaw = 0.0
	_target_pitch = 0.0

## Nastaví směr těla (pro 2D sidescroller vlevo/vpravo)
func set_facing_right(right: bool) -> void:
	if _facing_right == right:
		return
	_facing_right = right
	body_sprite.flip_h = not right

func play_state(anim_name: StringName) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func play_attack(target: Node3D) -> void:
	var right := target.global_position.x >= global_position.x
	set_facing_right(right)
	var direction := 1.0 if right else -1.0
	if _attack_tween:
		_attack_tween.kill()

	var hand := global_position + Vector3(direction * 0.28, 0.56, 0.44)
	var swipe_start := target.global_position + Vector3(direction * -0.48, 0.78, 0.58)
	var swipe_end := swipe_start + Vector3(direction * 0.52, -0.10, 0.0)
	_toothbrush.global_position = hand
	_toothbrush.rotation_degrees = Vector3(0.0, 0.0 if right else 180.0, direction * 28.0)
	_toothbrush.show()

	_attack_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_attack_tween.tween_property(_toothbrush, "global_position", swipe_start, 0.06)
	_attack_tween.parallel().tween_property(_toothbrush, "rotation_degrees:z", 0.0, 0.06)
	_attack_tween.parallel().tween_property(self, "position:x", direction * 0.24, 0.06)
	_attack_tween.parallel().tween_property(self, "rotation_degrees:z", direction * -12.0, 0.06)
	_attack_tween.tween_property(_toothbrush, "global_position", swipe_end, 0.08)
	_attack_tween.parallel().tween_property(_toothbrush, "rotation_degrees:z", direction * -14.0, 0.08)
	_attack_tween.tween_property(_toothbrush, "global_position", hand, 0.12)
	_attack_tween.parallel().tween_property(self, "position:x", 0.0, 0.12)
	_attack_tween.parallel().tween_property(self, "rotation_degrees:z", 0.0, 0.12)
	_attack_tween.tween_callback(_toothbrush.hide)


func play_death(attacker: Node3D) -> Tween:
	if _attack_tween:
		_attack_tween.kill()
	_toothbrush.hide()
	anim_player.stop()
	head_pivot.rotation = Vector3.ZERO
	set_process(false)
	var fall_right := global_position.x >= attacker.global_position.x if is_instance_valid(attacker) else _facing_right
	var direction := 1.0 if fall_right else -1.0

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(ATTACK_CONTACT_TIME)
	tween.set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_property(self, "rotation_degrees:z", direction * -80.0, 0.38)
	tween.tween_property(self, "position:x", direction * 0.24, 0.38)
	# Naklonění a výška posadí obrys hlavy na zem a přiblíží nohy k podlaze.
	tween.tween_property(self, "position:y", 0.32, 0.38)
	return tween


func show_score_popup(points: int) -> void:
	var popup := Label3D.new()
	popup.name = "ScorePopup"
	popup.text = "%+d" % points
	popup.font_size = 42
	popup.outline_size = 10
	popup.pixel_size = 0.009
	popup.modulate = Color(0.58, 1.0, 0.52) if points >= 0 else Color(1.0, 0.46, 0.44)
	popup.no_depth_test = true
	popup.top_level = true
	popup.hide()
	add_child(popup)
	popup.global_position = global_position + Vector3(0.0, 2.0, 0.0)

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tween.tween_callback(popup.show).set_delay(ATTACK_CONTACT_TIME)
	tween.tween_property(popup, "position:y", popup.position.y + 0.55, 0.48).set_delay(ATTACK_CONTACT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.22).set_delay(ATTACK_CONTACT_TIME + 0.26)
	tween.tween_property(popup, "outline_modulate:a", 0.0, 0.22).set_delay(ATTACK_CONTACT_TIME + 0.26)
	tween.chain().tween_callback(popup.queue_free)


func is_facing_right() -> bool:
	return _facing_right

# Voláno z Call Method Tracku uvnitř AnimationPlayeru
func _on_anim_hit_frame() -> void:
	hit_frame.emit()
