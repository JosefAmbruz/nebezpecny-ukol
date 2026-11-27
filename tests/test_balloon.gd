extends Node

# Run with godot --headless --path . res://tests/test_balloon.tscn.
func _ready() -> void:
	var visuals := preload("res://src/characters/character_visuals.tscn").instantiate() as CharacterVisuals
	add_child(visuals)
	var anchor := visuals.get_balloon_anchor()
	var balloon := preload("res://src/characters/balloon_visual.tscn").instantiate() as BalloonVisual
	anchor.add_child(balloon)
	visuals.set_process(false)
	visuals._pose_walk(PI * 0.5, 1.0, 1.0)
	var arm := visuals.get_node("BodyRig/BackForearm") as MeshInstance3D
	var hand := arm.global_position + arm.global_basis.y.normalized() * (arm.scale.y - 0.045) * 0.5
	assert(anchor.global_position.is_equal_approx(hand))
	visuals._pose_attack_grip(Vector2(0.2, 0.5), 0.0, 1.0)
	hand = arm.global_position + arm.global_basis.y.normalized() * (arm.scale.y - 0.045) * 0.5
	assert(anchor.global_position.is_equal_approx(hand))
	var initial_x := balloon.global_position.x
	visuals.position.x += 0.8
	for i in 30:
		await get_tree().physics_frame
	assert(balloon.global_position.x > initial_x + 0.05)
	assert(balloon.global_position.distance_to(anchor.global_position) < BalloonVisual.STRING_LENGTH + 0.1)
	assert(balloon.global_position.y > anchor.global_position.y)
	balloon.global_position = anchor.global_position + Vector3(2.3, 0.2, 0.0)
	balloon.linear_velocity = Vector3(5.0, -5.0, 0.0)
	for i in 5:
		await get_tree().physics_frame
	assert(balloon.global_position.y >= anchor.global_position.y + BalloonVisual.MIN_HEIGHT - 0.05)
	assert(balloon.global_position.distance_to(anchor.global_position) < BalloonVisual.STRING_LENGTH + 0.1)
	await get_tree().process_frame
	var string := balloon.get_node("String") as MeshInstance3D
	var string_start := string.to_global(Vector3(0.0, -0.5, 0.0))
	assert(string_start.distance_to(anchor.global_position) < 0.02)
	var quest_npc := preload("res://src/characters/quest_npc.tscn").instantiate() as QuestNpc
	quest_npc.role = QuestNpc.Role.MADRINA_METTICULOSA
	add_child(quest_npc)
	assert(quest_npc.balloon_bunch.get_parent() == quest_npc.visuals.get_balloon_anchor())
	assert(quest_npc.balloon_bunch.get_child_count() == 3)
	visuals.queue_free()
	await get_tree().process_frame
	assert(not is_instance_valid(balloon))
	print("Balloon follows the animated hand with a constrained physical tether.")
	get_tree().quit()
