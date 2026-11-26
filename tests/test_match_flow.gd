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
	var how_to := current_scene.get_node("%HowTo") as Button
	var instructions := current_scene.get_node("%HowToContent") as Control
	assert(not instructions.visible)
	how_to.grab_focus()
	await _press_key(KEY_ENTER)
	await process_frame
	assert(instructions.visible)
	await _press_key(KEY_ENTER)
	await process_frame
	assert(not instructions.visible)
	current_scene.get_node("Center/Content/Start").grab_focus()
	await _press_key(KEY_ENTER)
	var world := await _wait_for_match()
	var shin := world._player.visuals.get_node("BodyRig/FrontShin") as MeshInstance3D
	var rest_pose := shin.transform
	Input.action_press(&"move_right")
	await create_timer(0.16).timeout
	Input.action_release(&"move_right")
	assert(not shin.transform.is_equal_approx(rest_pose))
	await create_timer(0.16).timeout
	assert(shin.transform.is_equal_approx(rest_pose))
	var visuals := world._player.visuals
	var back_arm := visuals.get_node("BodyRig/BackForearm") as MeshInstance3D
	var front_arm := visuals.get_node("BodyRig/FrontForearm") as MeshInstance3D
	var foot := visuals.get_node("BodyRig/FrontFoot") as MeshInstance3D
	visuals._pose_walk(0.0, 1.0, 1.0)
	assert(foot.rotation.z > -PI * 0.5 and foot.position.x > 0.25)
	assert(back_arm.position.y > front_arm.position.y)
	var forward_arm_x := back_arm.position.x
	visuals._pose_walk(0.0, 1.0, -1.0)
	assert(foot.rotation.z < -PI * 0.5 and foot.position.x < -0.15)
	assert(back_arm.position.x < forward_arm_x)
	visuals._pose_walk(PI * 0.25, 1.0, 1.0)
	assert(is_equal_approx(foot.position.y, 0.025))
	visuals._pose_walk(PI * 1.5, 1.0, 1.0)
	assert(foot.position.y > 0.12)
	visuals._pose_walk(0.0, 0.0, 1.0)
	assert(world._game_hud.get_node("%QuestRoute").text == "Náměstí | Jdi doprava")
	world._player.position.x = 0.0
	await physics_frame
	await physics_frame
	assert(not world._player.is_safe_from_attack())

	var killer := OffScreenDirector.NPC_BASE_SCENE.instantiate() as NpcBase
	killer.apply_character_data(world.assassins[0])
	world.add_child(killer)
	killer.position = world._player.position + Vector3(3.0, 0.0, 0.0)
	assert(world._player._get_interaction_hint(killer.interactable) == Player.InteractionHint.APPROACH)
	killer.position.x = world._player.position.x + 1.0
	killer._looking_right = true
	assert(world._player._get_interaction_hint(killer.interactable) == Player.InteractionHint.ATTACK)
	killer._looking_right = false
	assert(world._player._get_interaction_hint(killer.interactable) == Player.InteractionHint.WAIT)
	var victim := NpcBase.new()
	victim.apply_character_data(world.assassins[1])
	world.add_child(victim)
	victim.died.connect(world._director._on_npc_died)
	victim.on_interaction_completed(killer, InteractableNpc.InteractionKind.ASSASSINATE)

	var civilian := world._director._active_civilians[0]
	civilian.interactable.complete_interaction(world._player)
	assert(civilian.state == NpcBase.State.DEAD and civilian.interactable.collision_layer == 0)
	assert(world._broken_toothbrushes == 1 and world._director._death_mark_records.size() == 2)
	assert(world._game_hud._brush_icons[2].texture == world._game_hud._broken_brush_tex)
	var penalty := civilian.visuals.get_node("ScorePopup") as Label3D
	assert(penalty.text == "-50" and penalty.modulate.r > penalty.modulate.g)

	var scored_victim := OffScreenDirector.NPC_BASE_SCENE.instantiate() as NpcBase
	scored_victim.apply_character_data(world.assassins[2])
	world.add_child(scored_victim)
	scored_victim.died.connect(world._director._on_npc_died)
	scored_victim.interactable.complete_interaction(world._player)
	var reward := scored_victim.visuals.get_node("ScorePopup") as Label3D
	assert(reward.text == "+100" and reward.modulate.g > reward.modulate.r)
	assert(world._score == 50)
	world._director.activate_level(1)
	assert(world._game_hud.get_node("%QuestRoute").text == "Náměstí | Jsi na místě")
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.MADRINA_METTICULOSA)
	assert(world._game_hud.get_node("%QuestRoute").text == "Park | Jdi doprava")
	world._director.activate_level(2)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.PADRINO_MORETTI)
	assert(world._game_hud.get_node("%QuestRoute").text == "Start | Jdi doleva")
	world._director.activate_level(0)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.PADRINO_PACATO)
	assert(not world._game_hud.get_node("%QuestRoute").visible)
	world._assassin_list_ui.toggle_list()
	killer.position = world._player.position + Vector3(-1.0, 0.0, 0.0)
	world._player._looking_right = true
	killer._stalk_target = world._player
	var killer_depth := killer.visuals.global_position.z
	killer._process_attack(killer.attack_duration * 0.2)
	var grip := killer.visuals.get_node("Toothbrush") as Node3D
	var handle := grip.get_node("Handle") as MeshInstance3D
	assert(grip.visible and not handle.visible)
	killer._process_attack(killer.attack_duration * 0.38)
	assert(not handle.visible)
	var gripping_forearm := killer.visuals.get_node("BodyRig/FrontForearm") as MeshInstance3D
	var wrist := gripping_forearm.global_position + gripping_forearm.global_basis.y.normalized() * (gripping_forearm.scale.y - 0.045) * 0.5
	assert(wrist.is_equal_approx(grip.global_position))
	killer._process_attack(killer.attack_duration)
	assert(grip.visible and handle.visible and handle.scale.x < 0.5)
	assert(world._player.is_alive and world._player.movement_locked and not paused)
	assert(Engine.time_scale < 1.0 and world._game_hud.get_node("%DefensePanel").visible)
	var match_time := world._elapsed_time
	await _press_key(KEY_E)
	if world._camera_zoom_tween.is_running():
		await world._camera_zoom_tween.finished
	assert(world._player_camera.size < world._camera_base_size * 0.5)
	assert(world._defense_deadline_ms != 0 and world._elapsed_time == match_time)
	await _press_key(KEY_F)
	await process_frame
	assert(Engine.time_scale == 1.0 and world._defense_deadline_ms == 0)
	assert(world._player.is_alive and world._assassin_list_ui.visible)
	assert(world._game_hud.get_node("%DefenseLabel").text == "Útok odražen")
	if killer.visuals._attack_tween.is_running():
		await killer.visuals._attack_tween.finished
	assert(not killer.visuals.get_node("Toothbrush").visible)
	assert(is_equal_approx(killer.visuals.global_position.z, killer_depth))
	assert(killer.character_data.kill_score == 100)

	world._player._looking_right = true
	killer._stalk_target = world._player
	killer._process_attack(killer.attack_duration)
	var deadline := world._defense_deadline_ms
	assert(deadline != 0)
	while not paused:
		await process_frame
	assert(Time.get_ticks_msec() >= deadline and Engine.time_scale == 1.0)
	assert(paused and not world._player.can_process() and not world._director.can_process())
	assert(not world._assassin_list_ui.visible)
	var end_panel := world._game_hud.get_node("%EndGamePanel") as Control
	assert(not end_panel.visible)
	await create_timer(0.09).timeout
	assert(handle.visible and is_equal_approx(handle.scale.x, 1.0))
	await end_panel.visibility_changed
	await process_frame
	assert(not killer.visuals.get_node("Toothbrush").visible)
	assert(absf(world._player.visuals.rotation_degrees.z) >= 75.0)
	assert(absf(civilian.visuals.rotation_degrees.z) >= 75.0)
	assert(world._game_hud.get_node("%EndTitleLabel").text == "Byl jsi zabit")
	assert(world._game_hud.get_node("%LeaderboardRows").text == "1. Ty — 350\n2. %s — 200" % killer.display_name)
	var position := world._player.position
	Input.action_press(&"move_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"move_right")
	assert(world._player.position == position)
	if is_instance_valid(penalty):
		await penalty.tree_exited
	assert(not civilian.visuals.has_node("ScorePopup"))

	var previous_id := world.get_instance_id()
	await _press_key(KEY_ENTER)
	world = await _wait_for_match(previous_id)
	assert(not paused)
	assert(world._player.is_alive and world._score == 0)
	assert(not world.assassins[0].has_killed and world.assassins[0].kill_score == 0)

	previous_id = world.get_instance_id()
	await _press_key(KEY_F5)
	world = await _wait_for_match(previous_id)
	for i in range(3):
		var civilian_target := world._director._active_civilians[0]
		civilian_target.interactable.complete_interaction(world._player)
	assert(world._broken_toothbrushes == 3 and paused)
	assert(world._game_hud.get_node("%EndTitleLabel").text == "Zlomil jsi všechny kartáčky!")
	assert(world._game_hud.get_node("%Leaderboard").is_visible_in_tree())
	previous_id = world.get_instance_id()
	await _press_key(KEY_ENTER)
	world = await _wait_for_match(previous_id)
	var assassin := world.assassins[0]
	assassin.has_killed = true
	assassin.kill_score = 100
	world._update_match_clock(world.match_duration_seconds)
	assert(paused and world._game_hud.get_node("%Leaderboard").is_visible_in_tree())
	assert(world._game_hud.get_node("%LeaderboardRows").text == "1. %s — 100\n2. Ty — 0" % assassin.display_name)
	print("Onboarding, combat, defense success and timeout, results, and restarts passed.")
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
