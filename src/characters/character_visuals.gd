# character_visuals.gd
class_name CharacterVisuals
extends Node3D

signal action_finished(action_name: StringName)
signal hit_frame

const ATTACK_CONTACT_TIME := 0.12
const BRUSH_REVEAL_PROGRESS := 0.82
const WALK_BLEND_RATE := 9.0
# x = délka kroku, y = zdvih chodidla, z = náklon chodidla v radiánech.
const WALK_FOOT_POSES := [
	Vector3(0.25, 0.0, 0.43),
	Vector3(0.16, 0.0, 0.0),
	Vector3(0.02, 0.0, 0.0),
	Vector3(-0.12, 0.0, -0.17),
	Vector3(-0.24, 0.0, -0.82),
	Vector3(-0.13, 0.115, -0.86),
	Vector3(0.04, 0.135, -0.45),
	Vector3(0.19, 0.065, 0.12),
]

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
@onready var body_rig: Node3D = $BodyRig
@onready var headwear_anchor: Marker3D = $HeadPivot/HeadwearAnchor
@onready var balloon_anchor: Marker3D = $BodyRig/BalloonAnchor
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var _toothbrush: Node3D = $Toothbrush
@onready var _brush_handle: MeshInstance3D = $Toothbrush/Handle
@onready var _brush_handle_rest_x: float = _brush_handle.position.x
@onready var _torso: Sprite3D = $BodyRig/BodySprite
@onready var _torso_rest_y: float = _torso.position.y
@onready var _head_rest_y: float = head_pivot.position.y
@onready var _upper_arms: Array[MeshInstance3D] = [$BodyRig/BackUpperArm, $BodyRig/FrontUpperArm]
@onready var _forearms: Array[MeshInstance3D] = [$BodyRig/BackForearm, $BodyRig/FrontForearm]
@onready var _thighs: Array[MeshInstance3D] = [$BodyRig/BackThigh, $BodyRig/FrontThigh]
@onready var _shins: Array[MeshInstance3D] = [$BodyRig/BackShin, $BodyRig/FrontShin]
@onready var _feet: Array[MeshInstance3D] = [$BodyRig/BackFoot, $BodyRig/FrontFoot]

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _facing_right: bool = true
var _attack_tween: Tween
var _attack_depth_offset: float = 0.0
var _charging_attack: bool = false
var _attack_charge: float = 0.0
var _attack_direction: float = 1.0
var _move_speed: float = 0.0
var _walk_phase: float = 0.0
var _walk_weight: float = 0.0
var _walk_facing: float = 1.0

func _ready() -> void:
	# Zajistí, že každá instance postavy má vlastní kopii materiálu hlavy
	if head_mesh.material_override:
		head_mesh.material_override = head_mesh.material_override.duplicate()
	_apply_appearance()
	_pose_walk(0.0, 0.0, _walk_facing)

func _process(delta: float) -> void:
	# Plynulé dotáčení hlavy k cílovému úhlu
	head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, _target_yaw, head_turn_speed * delta)
	head_pivot.rotation.x = lerp_angle(head_pivot.rotation.x, _target_pitch, head_turn_speed * delta)
	_update_walk(delta)


func _update_walk(delta: float) -> void:
	var speed := 0.0 if _attack_tween and _attack_tween.is_running() else _move_speed
	var direction := 1.0 if _facing_right else -1.0
	if speed == 0.0 and _walk_weight == 0.0:
		_walk_facing = direction
		return
	_walk_weight = move_toward(_walk_weight, minf(1.0, speed / 1.6), delta * WALK_BLEND_RATE)
	var cycle_distance := lerpf(1.35, 2.4, minf(speed / 6.0, 1.0))
	_walk_facing = move_toward(_walk_facing, direction, delta * 15.0)
	_walk_phase = fposmod(_walk_phase + TAU * speed * delta / cycle_distance, TAU)
	_pose_walk(_walk_phase, _walk_weight, _walk_facing)


func _pose_walk(phase: float, weight: float, facing: float) -> void:
	var body_bob := -sin(phase * 2.0) * weight * 0.033
	_torso.position.y = _torso_rest_y + body_bob
	_torso.rotation.z = -facing * weight * 0.055
	head_pivot.position.y = _head_rest_y + body_bob * 0.7

	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var frame := fposmod(phase / TAU + (1 - i) * 0.5, 1.0) * WALK_FOOT_POSES.size()
		var index := int(frame)
		var foot_pose: Vector3 = WALK_FOOT_POSES[index].lerp(
			WALK_FOOT_POSES[(index + 1) % WALK_FOOT_POSES.size()], frame - index
		)
		var pitch := foot_pose.z * weight
		var tilt := sin(pitch)
		var shoe_center_y := 0.025 + 0.047 * absf(tilt) + foot_pose.y * weight
		var ankle := Vector2(
			side * lerpf(0.13, 0.065, weight) + facing * foot_pose.x * weight,
			shoe_center_y - 0.027 * tilt
		)
		var shoe := _feet[i]
		shoe.position.x = ankle.x + facing * 0.027 * cos(pitch) * weight
		shoe.position.y = shoe_center_y
		shoe.rotation.z = -PI * 0.5 + facing * pitch

		var hip := Vector2(side * lerpf(0.09, 0.058, weight), 0.33 + body_bob)
		var leg := ankle - hip
		var bend := sqrt(maxf(0.0, 0.195 * 0.195 - leg.length_squared() * 0.25))
		bend *= lerpf(0.56, 1.0, smoothstep(0.015, 0.10, foot_pose.y))
		var knee := hip.lerp(ankle, 0.5) + Vector2(-leg.y, leg.x).normalized() * bend * facing * weight
		_pose_segment(_thighs[i], hip, knee)
		_pose_segment(_shins[i], knee, ankle)

		if _toothbrush.visible:
			continue
		var arm_swing := -foot_pose.x * weight / 0.25
		var forward_swing := maxf(0.0, arm_swing)
		var reach := 0.15 if i == 0 else 0.22
		var lift_forward := 0.085 if i == 0 else 0.12
		var shoulder := Vector2(side * (0.13 - 0.025 * weight), 0.68 + body_bob)
		var hand := Vector2(
			side * 0.28 + facing * (arm_swing * reach + 0.035 * weight + 0.035 * forward_swing),
			0.34 + body_bob + 0.025 * absf(arm_swing) + lift_forward * forward_swing
		)
		var elbow := shoulder.lerp(hand, 0.53) + Vector2(
			side * 0.025 - facing * (0.035 * weight + 0.09 * forward_swing),
			-0.015 - 0.025 * forward_swing
		)
		_pose_segment(_upper_arms[i], shoulder, elbow)
		_pose_segment(_forearms[i], elbow, hand)


func _pose_segment(segment: MeshInstance3D, start: Vector2, end: Vector2) -> void:
	var direction := end - start
	var center := start.lerp(end, 0.5)
	segment.position = Vector3(center.x, center.y, segment.position.z)
	segment.rotation.z = atan2(-direction.x, direction.y)
	segment.scale.y = direction.length() + 0.045
	if segment == _forearms[0]:
		balloon_anchor.position = Vector3(end.x, end.y, segment.position.z)


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

	set_headwear(appearance.headwear_scene)


func set_headwear(scene: PackedScene) -> void:
	if not headwear_anchor:
		return
	for child in headwear_anchor.get_children():
		child.queue_free()
	if scene:
		var inst := scene.instantiate()
		headwear_anchor.add_child(inst)

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

## Nastaví směr těla pro 2D sidescroller.
func set_facing_right(right: bool) -> void:
	if _facing_right == right:
		return
	_facing_right = right
	_torso.flip_h = not right


func get_balloon_anchor() -> Marker3D:
	return balloon_anchor

func play_state(anim_name: StringName, speed: float = 0.0) -> void:
	_move_speed = absf(speed)
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func prepare_attack(target: Node3D, progress: float) -> void:
	if not _charging_attack:
		if _attack_tween:
			_attack_tween.kill()
		_clear_attack_pose()
		_charging_attack = true
		_toothbrush.show()
	var right := target.global_position.x >= global_position.x
	_attack_direction = 1.0 if right else -1.0
	set_facing_right(right)
	_apply_attack_charge(progress)


func _apply_attack_charge(progress: float) -> void:
	_attack_charge = progress
	var reach := smoothstep(0.0, 0.69, progress)
	var draw := smoothstep(0.76, 1.0, progress)
	var windup := smoothstep(BRUSH_REVEAL_PROGRESS, 1.0, progress)
	var pocket := Vector2(_attack_direction * 0.15, 0.29)
	var raised := Vector2(_attack_direction * (0.20 + 0.10 * windup), 0.53 + 0.16 * windup)
	var hand := Vector2(0.28, 0.34).lerp(pocket, reach).lerp(raised, draw)
	_brush_handle.visible = progress >= BRUSH_REVEAL_PROGRESS
	_set_brush_exposure(lerpf(0.08, 0.48, windup))
	rotation_degrees.z = _attack_direction * 6.0 * windup
	_pose_attack_grip(hand, lerpf(81.0, 16.0, draw) + 10.0 * windup, reach)


func _set_brush_exposure(length_fraction: float) -> void:
	_brush_handle.scale.x = length_fraction
	_brush_handle.position.x = _brush_handle_rest_x * length_fraction


func _pose_attack_grip(hand: Vector2, brush_angle: float, reach: float) -> void:
	_toothbrush.position = Vector3(hand.x, hand.y, body_rig.position.z + _forearms[1].position.z)
	_toothbrush.rotation_degrees = Vector3(0.0, 0.0 if _attack_direction > 0.0 else 180.0, brush_angle)
	var shoulder := Vector2(0.13, 0.68)
	var elbow := shoulder.lerp(hand, 0.53) + Vector2(
		lerpf(0.025, -_attack_direction * 0.065, reach), lerpf(-0.015, -0.075, reach)
	)
	_pose_segment(_upper_arms[1], shoulder, elbow)
	_pose_segment(_forearms[1], elbow, hand)

	var free_shoulder := Vector2(-0.13, 0.68)
	var free_hand := Vector2(-0.28 - _attack_direction * 0.09 * reach, 0.34 + 0.17 * reach)
	var free_elbow := free_shoulder.lerp(free_hand, 0.53) + Vector2(-0.025, -0.015 - 0.035 * reach)
	_pose_segment(_upper_arms[0], free_shoulder, free_elbow)
	_pose_segment(_forearms[0], free_elbow, free_hand)


func play_attack_windup(target: Node3D, foreground_z: float) -> void:
	if not _charging_attack:
		prepare_attack(target, 0.65)
	_bring_attack_forward(foreground_z)
	_attack_tween = create_tween().set_ignore_time_scale(true)
	_attack_tween.tween_method(_apply_attack_charge, _attack_charge, 1.0, 0.72).set_trans(Tween.TRANS_SINE)


func cancel_attack_windup() -> void:
	if not _charging_attack:
		return
	_charging_attack = false
	if _attack_tween:
		_attack_tween.kill()
	_attack_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_attack_tween.tween_method(_apply_attack_charge, _attack_charge, 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	_attack_tween.tween_callback(_clear_attack_pose)


func _bring_attack_forward(foreground_z: float) -> void:
	var offset := maxf(0.0, foreground_z - global_position.z)
	_attack_depth_offset += offset
	global_position.z += offset


func _clear_attack_pose() -> void:
	_charging_attack = false
	_attack_charge = 0.0
	_toothbrush.hide()
	position.x = 0.0
	rotation_degrees.z = 0.0
	global_position.z -= _attack_depth_offset
	_attack_depth_offset = 0.0
	_pose_walk(_walk_phase, _walk_weight, _walk_facing)


func play_attack(target: Node3D) -> void:
	if not _charging_attack:
		prepare_attack(target, 1.0)
	_charging_attack = false
	if _attack_tween:
		_attack_tween.kill()
	_bring_attack_forward(target.global_position.z + 0.16)
	_brush_handle.show()
	var distance := absf(target.global_position.x - global_position.x)
	var lunge := maxf(0.08, distance - 0.87)
	var wrist_x := clampf(distance - lunge - 0.35, -0.17, 0.52)
	var direction := _attack_direction
	# x/y jsou pozice úchopu, z posun těla a w jeho náklon.
	var raised := Vector4(_toothbrush.position.x, _toothbrush.position.y, position.x, rotation_degrees.z)
	var reach := Vector4(direction * (wrist_x - 0.19), 0.82, direction * lunge * 0.86, -direction * 7.0)
	var swipe := Vector4(direction * (wrist_x + 0.10), 0.72, direction * lunge, -direction * 13.0)
	var pocket := Vector4(direction * 0.15, 0.29, 0.0, 0.0)
	_attack_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_attack_tween.tween_method(_transition_attack_pose.bind(raised, reach, _toothbrush.rotation_degrees.z, 8.0), 0.0, 1.0, 0.05)
	_attack_tween.parallel().tween_method(_set_brush_exposure, _brush_handle.scale.x, 1.0, 0.05)
	_attack_tween.tween_method(_transition_attack_pose.bind(reach, swipe, 8.0, -18.0), 0.0, 1.0, ATTACK_CONTACT_TIME - 0.05)
	_attack_tween.tween_method(_transition_attack_pose.bind(swipe, pocket, -18.0, 81.0), 0.0, 1.0, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_callback(_clear_attack_pose)


func _transition_attack_pose(progress: float, from: Vector4, to: Vector4, angle_from: float, angle_to: float) -> void:
	var pose := from.lerp(to, progress)
	position.x = pose.z
	rotation_degrees.z = pose.w
	_pose_attack_grip(Vector2(pose.x, pose.y), lerpf(angle_from, angle_to, progress), 1.0)


func play_death(attacker: Node3D) -> Tween:
	if _attack_tween:
		_attack_tween.kill()
	_clear_attack_pose()
	anim_player.stop()
	head_pivot.rotation = Vector3.ZERO
	_pose_walk(0.0, 0.0, _walk_facing)
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
