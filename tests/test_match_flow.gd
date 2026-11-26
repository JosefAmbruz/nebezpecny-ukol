extends SceneTree

# Run with godot --path . --script res://tests/test_match_flow.gd.
const WORLD := preload("res://src/world.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	create_timer(30.0).timeout.connect(quit.bind(1))
	assert(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) == OK)
	await scene_changed
	assert(current_scene.name == &"TitleScreen")
	await _press_key(KEY_ENTER)
	var world := await _wait_for_match()
	world._player.position.x = 0.0
	await physics_frame
	await physics_frame
	assert(not world._player.is_safe_from_attack())

	var killer := NpcBase.new()
	killer.apply_character_data(world.assassins[0])
	world.add_child(killer)
	var victim := NpcBase.new()
	victim.apply_character_data(world.assassins[1])
	world.add_child(victim)
	victim.died.connect(world._director._on_npc_died)
	victim.on_interaction_completed(killer, InteractableNpc.InteractionKind.ASSASSINATE)

	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.MADRINA_METTICULOSA)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.PADRINO_MORETTI)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.PADRINO_PACATO)
	world._assassin_list_ui.toggle_list()
	world._player.on_killed_by_assassin(killer)
	assert(paused and not world._player.can_process() and not world._director.can_process())
	assert(not world._assassin_list_ui.visible)
	assert(world._game_hud.get_node("%EndTitleLabel").text == "Byl jsi zabit")
	assert(world._game_hud.get_node("%LeaderboardRows").text == "1. Ty — 300\n2. %s — 200" % killer.display_name)
	var position := world._player.position
	Input.action_press(&"move_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"move_right")
	assert(world._player.position == position)

	var previous_id := world.get_instance_id()
	await _press_key(KEY_ENTER)
	world = await _wait_for_match(previous_id)
	assert(not paused)
	assert(world._player.is_alive and world._score == 0)
	assert(not world.assassins[0].has_killed and world.assassins[0].kill_score == 0)

	previous_id = world.get_instance_id()
	await _press_key(KEY_F5)
	world = await _wait_for_match(previous_id)
	var assassin := world.assassins[0]
	assassin.has_killed = true
	assassin.kill_score = 100
	world._update_match_clock(world.match_duration_seconds)
	assert(paused and world._game_hud.get_node("%Leaderboard").is_visible_in_tree())
	assert(world._game_hud.get_node("%LeaderboardRows").text == "1. %s — 100\n2. Ty — 0" % assassin.display_name)
	print("Title, score ranking, input lock, and both restart controls passed.")
	quit()


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)


func _wait_for_match(previous_id: int = 0) -> WORLD:
	while (
		not current_scene is WORLD
		or current_scene.get_instance_id() == previous_id
		or current_scene._director.active_level_id < 0
	):
		await process_frame
	return current_scene as WORLD
