class_name AppearancePool
extends Resource

@export var face_textures: Array[Texture2D] = []
@export var hair_scenes: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.05) var bald_chance: float = 0.2
@export var hair_colors: Array[Color] = [
	Color(0.14, 0.12, 0.11, 1.0), # černá
	Color(0.32, 0.21, 0.14, 1.0), # tmavě hnědá
	Color(0.55, 0.37, 0.22, 1.0), # kaštanová
	Color(0.84, 0.72, 0.42, 1.0), # blond
	Color(0.72, 0.30, 0.16, 1.0), # zrzavá
	Color(0.62, 0.62, 0.65, 1.0), # šedá
]
@export var skin_colors: Array[Color] = [
	Color(0.98, 0.85, 0.76, 1.0),
	Color(0.92, 0.75, 0.62, 1.0),
	Color(0.84, 0.63, 0.49, 1.0),
	Color(0.68, 0.46, 0.34, 1.0),
	Color(0.96, 0.80, 0.78, 1.0),
	Color(0.86, 0.78, 0.66, 1.0),
	Color(0.76, 0.84, 0.78, 1.0),
	Color(0.82, 0.76, 0.88, 1.0),
]
@export var names: Array[String] = [
	"Karel Šalina",
	"Petra Petrová",
	"Lukáš Orloj",
	"Tereza Zelná",
	"Ondřej Špilas",
	"Klára Mendlová",
	"Jakub Komeťák",
	"Markéta Čára",
	"Filip Prýgl",
	"Barbora Lužánková",
	"Matěj Veveří",
	"Eliška Krpole",
	"Vojtěch Cejl",
	"Adéla Svoboďáková",
	"Honza Hlavas",
	"Simona Bystrcová",
]
