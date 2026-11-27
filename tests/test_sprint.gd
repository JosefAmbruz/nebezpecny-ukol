extends Node3D

# Run with godot --headless --path . res://tests/test_sprint.tscn.
func _ready() -> void:
	seed(7)
	var player := Player.new()
	add_child(player)
	var assassin := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	assassin.is_assassin = true
	assassin.position.x = 3.0
	add_child(assassin)
	assassin.set_physics_process(false)

	var walking_hits := _count_acquisitions(assassin, player, false)
	var sprinting_hits := _count_acquisitions(assassin, player, true)
	assert(sprinting_hits > walking_hits * 1.8, "walk %d, sprint %d" % [walking_hits, sprinting_hits])
	print("Sprint detection passed (walk %d, sprint %d)." % [walking_hits, sprinting_hits])
	get_tree().quit()


func _count_acquisitions(assassin: NpcBase, player: Player, sprinting: bool) -> int:
	player.is_sprinting = sprinting
	var hits := 0
	for i in range(3000):
		assassin.state = NpcBase.State.WANDER
		assassin._stalk_target = null
		assassin._try_acquire_stalk_target(0.2)
		if assassin.state == NpcBase.State.STALK:
			hits += 1
	return hits
