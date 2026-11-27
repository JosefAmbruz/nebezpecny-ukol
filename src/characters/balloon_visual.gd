class_name BalloonVisual
extends RigidBody3D

const STRING_LENGTH := 1.6
const BALLOON_RADIUS := 0.31
const LIFT := 5.0
const DRAG := 1.8

@export var initial_sway: float = 0.0

@onready var _string: MeshInstance3D = $String
var _anchor: Node3D
var _last_anchor_position: Vector3


func _ready() -> void:
	_anchor = get_parent() as Node3D
	_last_anchor_position = _anchor.global_position
	top_level = true
	global_position = _last_anchor_position + Vector3(initial_sway, STRING_LENGTH, 0.0).normalized() * STRING_LENGTH


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not is_instance_valid(_anchor):
		return
	var anchor_position := _anchor.global_position
	var anchor_velocity := (anchor_position - _last_anchor_position) / state.step
	_last_anchor_position = anchor_position
	var offset := state.transform.origin - anchor_position
	if offset.length() > STRING_LENGTH + 5.0:
		var reset := state.transform
		reset.origin = anchor_position + Vector3.UP * STRING_LENGTH
		state.transform = reset
		state.linear_velocity = Vector3.ZERO
		return

	state.linear_velocity += (Vector3.UP * LIFT - state.linear_velocity * DRAG) * state.step
	if offset.length() >= STRING_LENGTH:
		var direction := offset.normalized()
		var transform := state.transform
		transform.origin = anchor_position + direction * STRING_LENGTH
		state.transform = transform
		var outward_speed := (state.linear_velocity - anchor_velocity).dot(direction)
		if outward_speed > 0.0:
			state.linear_velocity -= direction * outward_speed


func _process(_delta: float) -> void:
	if not is_instance_valid(_anchor):
		return
	var start := to_local(_anchor.global_position)
	var end := Vector3.DOWN * BALLOON_RADIUS
	var line := end - start
	_string.position = (start + end) * 0.5
	_string.quaternion = Quaternion(Vector3.UP, line.normalized()) if line.length_squared() > 0.0001 else Quaternion.IDENTITY
	_string.scale.y = line.length()
