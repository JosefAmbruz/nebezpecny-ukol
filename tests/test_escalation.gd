extends Node3D

# Run with godot --headless --path . res://tests/test_escalation.tscn.
func _ready() -> void:
	var world := preload("res://src/world.tscn").instantiate()
	world.total_assassins = 0
	world.background_music = null
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	assert(NpcBase.late_pressure == 0.0 and not world._game_hud.get_node("%EventLabel").visible)
	world._update_match_clock(world.match_duration_seconds * 0.5)
	assert(NpcBase.late_pressure == 0.0)
	world._update_match_clock(world.match_duration_seconds * 0.3)
	assert(is_equal_approx(NpcBase.late_pressure, 0.5))
	assert(world._game_hud.get_node("%EventLabel").visible)

	var player: Player = world._player
	player._looking_right = false
	var assassin := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	assassin.is_assassin = true
	world.add_child(assassin)
	assassin.set_physics_process(false)
	assassin.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	assassin._stalk_target = player
	assassin.state = NpcBase.State.ATTACK
	NpcBase.late_pressure = 1.0
	assassin._process_attack(0.1)
	assert(is_equal_approx(assassin._attack_elapsed, 0.1 * (1.0 + assassin.late_attack_speedup)))

	world.queue_free()
	await get_tree().process_frame
	assert(NpcBase.late_pressure == 0.0)
	print("Late match escalation passed.")
	get_tree().quit()
