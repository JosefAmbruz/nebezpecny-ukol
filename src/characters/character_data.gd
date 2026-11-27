class_name CharacterData
extends Resource

enum QuestStage {
	NONE = 0,
	HAS_BALLOON = 1,
	HAS_BATTERY = 2,
	COMPLETED = 3,
}

## Povaha assassina mění jeho AI (viz NpcBase._apply_personality).
enum Personality {
	NONE = 0,
	AGGRESSIVE = 1, # rychle a nápadně útočí
	PATIENT = 2,    # vidí dál a dlouho tě sleduje, ale zřídka začne
	SKITTISH = 3,   # pomalu útočí, a když se na něj podíváš, uteče z čtvrti
}

const PERSONALITY_NAMES := {
	Personality.NONE: "",
	Personality.AGGRESSIVE: "Agresivní",
	Personality.PATIENT: "Trpělivý",
	Personality.SKITTISH: "Zbabělý",
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
@export var personality: Personality = Personality.NONE

var has_killed: bool = false
var kill_score: int = 0
