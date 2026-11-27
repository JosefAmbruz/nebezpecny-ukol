extends Node

# Run with godot --headless --path . res://tests/test_rival_event.tscn.
func _ready() -> void:
	var world := preload("res://src/world.tscn").instantiate()
	world.total_assassins = 0
	world.background_music = null
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	var event := world._game_hud.get_node("%RivalEvent") as Label
	assert(not event.visible)
	world._game_hud.set_clock_progress(0.5)
	var rival := CharacterData.new()
	rival.display_name = "Soupeř"
	rival.can_do_quest = true
	rival.quest_stage = CharacterData.QuestStage.HAS_BALLOON
	rival.current_level_id = 2
	var record := {"data": rival, "level_id": 2, "x_pos": 0.0}
	world._director._step_frozen_assassin(record)
	assert(rival.quest_stage == CharacterData.QuestStage.HAS_BATTERY)
	assert(event.visible and event.text == "18:30 | Soupeř získal baterii: Park")
	world._director._step_frozen_assassin(record)
	assert(record.level_id == 1 and rival.current_level_id == 1)
	assert(event.text == "18:30 | Soupeř získal baterii: Park")
	world.queue_free()
	await get_tree().process_frame
	print("Rival progress announces the actual time and last known location.")
	get_tree().quit()
