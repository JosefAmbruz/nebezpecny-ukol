extends Node

# Run with godot --headless --path . res://tests/test_attack_camera.tscn.
func _ready() -> void:
	var world := preload("res://src/world.tscn").instantiate()
	world.total_assassins = 0
	world.background_music = null
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	world.set_physics_process(false)
	var player: Player = world._player
	player.set_physics_process(false)
	var victim := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	world.add_child(victim)
	victim.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	victim.set_physics_process(false)
	victim._looking_right = true
	var before := player.get_cursor_world_point()
	var cursor_screen: Vector2 = world._player_camera.unproject_position(before)
	world._on_player_interaction_started(victim.interactable, InteractableNpc.InteractionKind.ASSASSINATE)
	world._on_player_interaction_progress_changed(1.0, InteractableNpc.InteractionKind.ASSASSINATE)
	world._update_camera_clamp(0.016)
	assert(is_equal_approx(world._player_camera.size, world._camera_base_size * world.assassinate_zoom_factor))
	assert(player.get_cursor_world_point().distance_to(before) < 0.001)
	assert(world._player_camera.unproject_position(before).distance_to(cursor_screen) < 0.1)

	player._active_target = victim.interactable
	Input.action_press(&"interact")
	player._handle_interaction(0.2)
	assert(player._active_target == victim.interactable and player._interact_elapsed > 0.0)
	Input.action_release(&"interact")
	player._handle_interaction(0.1)
	assert(player._active_target == null)
	world.queue_free()
	await get_tree().process_frame
	print("Attack zoom preserves the cursor position and active target.")
	get_tree().quit()
