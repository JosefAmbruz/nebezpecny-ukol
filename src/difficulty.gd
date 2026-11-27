class_name Difficulty
extends RefCounted

enum Level { EASY, NORMAL, HARD }

const NAMES := ["Lehká", "Normální", "Těžká"]

## Násobiče assassin AI jsou relativní k hodnotám v npc_base.tscn, takže NORMAL nic nemění.
const PRESETS := {
	Level.EASY: {
		"total_assassins": 6,
		"match_duration_seconds": 360.0,
		"max_toothbrushes": 5,
		"distractions": 4,
		"defense_window_ms": 2200,
		"reaction_grace_time": 0.35,
		"detect_range_mult": 0.8,
		"stalk_chance_mult": 0.6,
		"attack_duration_mult": 1.3,
	},
	Level.NORMAL: {
		"total_assassins": 8,
		"match_duration_seconds": 300.0,
		"max_toothbrushes": 3,
		"distractions": 3,
		"defense_window_ms": 1500,
		"reaction_grace_time": 0.22,
		"detect_range_mult": 1.0,
		"stalk_chance_mult": 1.0,
		"attack_duration_mult": 1.0,
	},
	Level.HARD: {
		"total_assassins": 10,
		"match_duration_seconds": 240.0,
		"max_toothbrushes": 2,
		"distractions": 2,
		"defense_window_ms": 1000,
		"reaction_grace_time": 0.12,
		"detect_range_mult": 1.2,
		"stalk_chance_mult": 1.5,
		"attack_duration_mult": 0.75,
	},
}

# ponytail: static var přežije change_scene i reload; ukládat na disk, až bude potřeba pamatovat volbu mezi spuštěními.
static var current: Level = Level.NORMAL


static func get_preset() -> Dictionary:
	return PRESETS[current]
