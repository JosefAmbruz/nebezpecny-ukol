class_name CharacterData
extends Resource

enum QuestStage {
	NONE = 0,
	HAS_BALLOON = 1,
	HAS_BATTERY = 2,
	COMPLETED = 3,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var appearance: CharacterAppearance
@export var portrait: Texture2D

@export var is_assassin: bool = false
@export var can_do_quest: bool = false
@export var quest_stage: QuestStage = QuestStage.NONE
@export var is_alive: bool = true
@export var current_level_id: int = 0

var has_killed: bool = false
var kill_score: int = 0
