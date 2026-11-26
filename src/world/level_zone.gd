class_name LevelZone
extends Node3D

@export var level_id: int = 0
@export var level_name: String = "Level 1"
@export var min_x: float = -15.0
@export var max_x: float = 15.0
@export var floor_y: float = 0.6
@export var civilian_count: int = 4
@export var quest_npc_start_x: float = -10.0


func contains_x(x: float) -> bool:
	return x >= min_x and x < max_x


func get_random_x(margin: float = 2.0) -> float:
	var lo := minf(min_x + margin, max_x - margin)
	var hi := maxf(min_x + margin, max_x - margin)
	return randf_range(lo, hi)
