# character_visuals.gd
class_name CharacterVisuals
extends Node3D

signal action_finished(action_name: StringName)
signal hit_frame

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
@onready var body_sprite: Sprite3D = $BodySprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _facing_right: bool = true

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

## Natočí hlavu směrem ke světové pozici (např. kurzor, hráč, podezřelý zvuk)
func look_at_world_point(world_point: Vector3) -> void:
	var local_dir := to_local(world_point) - head_pivot.position
	if local_dir.length_squared() < 0.001:
		return
	var raw_yaw := atan2(local_dir.x, local_dir.z)
	var raw_pitch := -atan2(local_dir.y, Vector2(local_dir.x, local_dir.z).length())
	
	_target_yaw = clamp(raw_yaw, -max_head_yaw, max_head_yaw)
	_target_pitch = clamp(raw_pitch, -max_head_pitch, max_head_pitch)

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

func is_facing_right() -> bool:
	return _facing_right

# Voláno z Call Method Tracku uvnitř AnimationPlayeru
func _on_anim_hit_frame() -> void:
	hit_frame.emit()
