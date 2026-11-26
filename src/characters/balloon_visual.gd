class_name BalloonVisual
extends Node3D

@export var bob_amplitude: float = 0.08
@export var bob_speed: float = 2.6

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta * bob_speed
	position.y = _base_y + sin(_time) * bob_amplitude
