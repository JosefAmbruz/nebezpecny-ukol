extends Node

# Run with godot --headless --path . res://tests/test_difficulty.tscn.
func _ready() -> void:
	Difficulty.current = Difficulty.Level.HARD
	var world := preload("res://src/world.tscn").instantiate()
	assert(world.total_assassins == 10 and world.max_toothbrushes == 2)
	assert(world.match_duration_seconds == 240.0 and world._defense_window_ms == 1000)

	var normal_npc := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	var base_detect := normal_npc.detect_range
	var base_attack := normal_npc.attack_duration
	var data := CharacterData.new()
	data.is_assassin = true
	var hard_assassin := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	hard_assassin.apply_character_data(data)
	add_child(hard_assassin)
	assert(is_equal_approx(hard_assassin.detect_range, base_detect * 1.2))
	assert(is_equal_approx(hard_assassin.attack_duration, base_attack * 0.75))

	Difficulty.current = Difficulty.Level.NORMAL
	var normal_assassin := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	normal_assassin.apply_character_data(data)
	add_child(normal_assassin)
	assert(normal_assassin.detect_range == base_detect)

	world.free()
	normal_npc.free()
	hard_assassin.free()
	normal_assassin.free()
	print("Difficulty presets passed.")
	get_tree().quit()
