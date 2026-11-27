extends Node3D

# Run with godot --headless --path . res://tests/test_witnesses.tscn.
func _ready() -> void:
	var player := Player.new()
	add_child(player)
	var witness := _spawn_npc(2.0)
	var distant := _spawn_npc(12.0)
	var assassin := _spawn_npc(-2.0, true)
	var victim := _spawn_npc(0.5, true)
	victim.on_interaction_completed(player, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(witness.state == NpcBase.State.EVADE and victim.witness_count == 1)
	assert(witness.get_node("WitnessReaction").visible)
	assert(distant.state == NpcBase.State.WANDER)
	assert(assassin.state == NpcBase.State.STALK and assassin._stalk_target == player)

	witness.position.x = 12.0
	assassin._abort_attack()
	assassin._attack_cooldown = 0.0
	var isolated_victim := _spawn_npc(0.5)
	isolated_victim.on_interaction_completed(player, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(isolated_victim.witness_count == 0)
	assert(assassin.state == NpcBase.State.WANDER)

	witness.position.x = 2.0
	var npc_victim := _spawn_npc(0.5)
	npc_victim.on_interaction_completed(assassin, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(witness.state == NpcBase.State.EVADE)
	assert(assassin.state == NpcBase.State.WANDER)
	witness.on_interaction_completed(assassin, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(not witness.get_node("WitnessReaction").visible)
	print("Witness reactions, nearby alerts and isolated attacks passed.")
	get_tree().quit()


func _spawn_npc(x: float, assassin: bool = false) -> NpcBase:
	var npc := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	npc.position.x = x
	npc.is_assassin = assassin
	add_child(npc)
	npc.set_physics_process(false)
	return npc
