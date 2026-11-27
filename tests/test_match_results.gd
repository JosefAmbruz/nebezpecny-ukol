extends Node

# Run with godot --headless --path . res://tests/test_match_results.tscn.
func _ready() -> void:
	var world := await _new_world()
	var assassin := NpcBase.new()
	assassin.is_assassin = true
	var civilian := NpcBase.new()
	var rival := NpcBase.new()
	world._on_npc_died(assassin, world._player)
	world._on_npc_died(assassin, rival)
	world._on_npc_died(civilian, world._player)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.MADRINA_METTICULOSA)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.PADRINO_MORETTI)
	world._on_quest_npc_interacted(null, world._player, QuestNpc.Role.PADRINO_PACATO)
	world._end_match("Čas vypršel", "Konečné skóre: %d" % world._score)
	var results: String = world._game_hud.get_node("%EndSummaryLabel").text
	assert("Konečné skóre: 400" in results)
	assert("Tiché likvidace: 1" in results and "Nejdelší kombo: 1" in results)
	assert("Vyřazení assassini: 1" in results)
	assert("Zasažení civilisté: 1" in results)
	assert("Úkol: splněn" in results)
	get_tree().paused = false
	world.queue_free()
	assassin.free()
	civilian.free()
	rival.free()
	await get_tree().process_frame

	world = await _new_world()
	var seen_assassin := NpcBase.new()
	seen_assassin.is_assassin = true
	seen_assassin.witness_count = 2
	for i in 3:
		world._on_npc_died(seen_assassin, world._player)
	assert(world._score == 100 + 150 + 200 and world._best_streak == 3)
	assert(world._game_hud.get_node("%ScoreLabel").text == "Skóre: 450 | Další ×2.5")
	world._player.assassination_spotted.emit()
	assert(world._game_hud.get_node("%ScoreLabel").text == "Skóre: 450")
	world._on_npc_died(seen_assassin, world._player)
	assert(world._score == 550)
	civilian = NpcBase.new()
	world._on_npc_died(civilian, world._player)
	world._on_npc_died(seen_assassin, world._player)
	assert(world._score == 600 and world._best_streak == 3)
	get_tree().paused = false
	world.queue_free()
	seen_assassin.free()
	civilian.free()
	await get_tree().process_frame

	world = await _new_world()
	civilian = NpcBase.new()
	for i in 3:
		world._on_npc_died(civilian, world._player)
	results = world._game_hud.get_node("%EndSummaryLabel").text
	assert(world._match_ended and "Zasažení civilisté: 3" in results)
	assert("Vyřazení assassini: 0" in results and "Úkol: nesplněn" in results)
	get_tree().paused = false
	world.queue_free()
	civilian.free()
	await get_tree().process_frame
	print("Match results count player eliminations and quest completion correctly.")
	get_tree().quit()


func _new_world() -> Node:
	var world := preload("res://src/world.tscn").instantiate()
	world.total_assassins = 0
	world.background_music = null
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	return world
