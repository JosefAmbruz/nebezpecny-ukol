extends Node3D

@export var appearance_pool: AppearancePool = preload("res://src/characters/default_appearance_pool.tres")
@export var total_assassins: int = 8
@export var quest_assassins: int = 4

@onready var _assassin_list_ui: AssassinListUI = $AssassinListUI
@onready var _test_assassin: NpcBase = get_node_or_null("TestAssassin") as NpcBase
@onready var _test_civilian: NpcBase = get_node_or_null("TestCivilian") as NpcBase

var assassins: Array[CharacterData] = []
var reserved_signatures: Dictionary = {}


func _ready() -> void:
	_setup_characters()


func _setup_characters() -> void:
	assassins = CharacterGenerator.generate_assassins(
		appearance_pool,
		total_assassins,
		quest_assassins
	)
	reserved_signatures = CharacterGenerator.collect_reserved_signatures(assassins)

	await PortraitBaker.bake_portraits(self, assassins)

	if _assassin_list_ui:
		_assassin_list_ui.set_assassins(assassins)

	if _test_assassin and not assassins.is_empty():
		_test_assassin.apply_character_data(assassins[0])
		_test_assassin.died.connect(_on_npc_died)

	if _test_civilian:
		_test_civilian.appearance = CharacterGenerator.generate_civilian_appearance(
			appearance_pool,
			reserved_signatures
		)


func _on_npc_died(npc: NpcBase, _killer: Node3D) -> void:
	if npc.character_data and npc.character_data.is_assassin and _assassin_list_ui:
		_assassin_list_ui.mark_assassin_dead(npc.character_data.id)
