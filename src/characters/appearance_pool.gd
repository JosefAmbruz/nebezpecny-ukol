class_name AppearancePool
extends Resource

@export_group("Obličeje")
@export var unisex_faces: Array[Texture2D] = []
@export var male_faces: Array[Texture2D] = []
@export var female_faces: Array[Texture2D] = []

@export_group("Vlasy")
@export var male_hair_scenes: Array[PackedScene] = []
@export var female_hair_scenes: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.05) var male_bald_chance: float = 0.25
@export_range(0.0, 1.0, 0.05) var female_bald_chance: float = 0.0
@export var hair_colors: Array[Color] = [
	Color(0.14, 0.12, 0.11, 1.0), # černá
	Color(0.32, 0.21, 0.14, 1.0), # tmavě hnědá
	Color(0.55, 0.37, 0.22, 1.0), # kaštanová
	Color(0.84, 0.72, 0.42, 1.0), # blond
	Color(0.72, 0.30, 0.16, 1.0), # zrzavá
	Color(0.62, 0.62, 0.65, 1.0), # šedá
]

@export_group("Barvy kůže")
@export var skin_colors: Array[Color] = [
	Color(0.98, 0.85, 0.76, 1.0),
	Color(0.92, 0.75, 0.62, 1.0),
	Color(0.84, 0.63, 0.49, 1.0),
	Color(0.68, 0.46, 0.34, 1.0),
]

@export_group("Jména")
@export var male_names: Array[String] = []
@export var female_names: Array[String] = []


func get_faces_for(gender: CharacterAppearance.Gender) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	result.append_array(unisex_faces)
	if gender == CharacterAppearance.Gender.MALE:
		result.append_array(male_faces)
	else:
		result.append_array(female_faces)
	return result


func get_hair_scenes_for(gender: CharacterAppearance.Gender) -> Array[PackedScene]:
	if gender == CharacterAppearance.Gender.MALE:
		return male_hair_scenes
	return female_hair_scenes


func get_bald_chance_for(gender: CharacterAppearance.Gender) -> float:
	if gender == CharacterAppearance.Gender.MALE:
		return male_bald_chance
	return female_bald_chance
