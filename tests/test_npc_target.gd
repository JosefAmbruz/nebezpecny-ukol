extends Node

# Run with godot --headless --path . res://tests/test_npc_target.tscn.


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var npc := NpcBase.new()
	get_tree().root.add_child(npc)
	var target := NpcBase.new()
	assert(npc._is_valid_attack_target(target))
	npc._stalk_target = target
	target.free()
	assert(not npc._is_valid_attack_target(npc._stalk_target))
	npc.state = NpcBase.State.STALK
	npc._process_stalk(0.1)
	assert(npc.state == NpcBase.State.WANDER and npc._stalk_target == null)

	target = NpcBase.new()
	npc._stalk_target = target
	target.free()
	npc.state = NpcBase.State.ATTACK
	npc._process_attack(0.1)
	assert(npc.state == NpcBase.State.WANDER and npc._stalk_target == null)
	npc.free()
	print("Freed attack targets are handled safely.")
	get_tree().quit()
