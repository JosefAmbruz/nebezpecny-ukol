class_name CharacterGenerator
extends RefCounted


## Vygeneruje `total_count` unikátních assassinů. Prvních `quest_count` začíná v Levelu 1
## u Padrina Pacata a jako jediní (spolu s hráčem) mohou plnit quest.
static func generate_assassins(
	pool: AppearancePool,
	total_count: int = 8,
	quest_count: int = 4,
	level_count: int = 3
) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	if not pool:
		push_error("CharacterGenerator: AppearancePool is null.")
		return result

	var all_appearances := _build_all_unique_appearances(pool)
	all_appearances.shuffle()

	var available_names: Array[String] = pool.names.duplicate()
	available_names.shuffle()

	var count := mini(total_count, all_appearances.size())
	if count < total_count:
		push_warning(
			"CharacterGenerator: Pool má jen %d unikátních kombinací (požadováno %d)."
			% [count, total_count]
		)

	var clamped_quest_count := mini(quest_count, count)

	for i in range(count):
		var data := CharacterData.new()
		data.id = StringName("assassin_%d" % i)
		data.display_name = (
			available_names[i]
			if i < available_names.size()
			else "Assassin #%d" % (i + 1)
		)
		data.appearance = all_appearances[i]
		data.is_assassin = true
		data.is_alive = true
		data.quest_stage = CharacterData.QuestStage.NONE

		if i < clamped_quest_count:
			data.can_do_quest = true
			data.current_level_id = 0 # Level 1 (u Padrina Pacata)
		else:
			data.can_do_quest = false
			data.current_level_id = randi_range(0, maxi(0, level_count - 1))

		result.append(data)

	return result


## Vrátí množinu signatur (Dictionary jako Set) všech assassinů.
static func collect_reserved_signatures(assassins: Array[CharacterData]) -> Dictionary:
	var reserved: Dictionary = {}
	for data in assassins:
		if data and data.appearance:
			reserved[data.appearance.get_signature()] = true
	return reserved


## Vygeneruje náhodný vzhled civilisty ze zbývajících kombinací mimo `reserved_signatures`.
static func generate_civilian_appearance(
	pool: AppearancePool,
	reserved_signatures: Dictionary
) -> CharacterAppearance:
	if not pool:
		return CharacterAppearance.new()

	var free_appearances: Array[CharacterAppearance] = []
	for app in _build_all_unique_appearances(pool):
		if not reserved_signatures.has(app.get_signature()):
			free_appearances.append(app)

	if not free_appearances.is_empty():
		return free_appearances.pick_random()

	# Fallback pro raný prototyp, pokud jsou všechny kombinace zabrané assassiny
	var fallback := CharacterAppearance.new()
	if not pool.face_textures.is_empty():
		fallback.face_texture = pool.face_textures.pick_random()
	if not pool.skin_colors.is_empty():
		fallback.skin_color = pool.skin_colors.pick_random()
	return fallback


static func _build_all_unique_appearances(pool: AppearancePool) -> Array[CharacterAppearance]:
	var list: Array[CharacterAppearance] = []
	var faces: Array[Texture2D] = pool.face_textures
	var skins: Array[Color] = pool.skin_colors if not pool.skin_colors.is_empty() else [Color.WHITE]

	if faces.is_empty():
		for skin in skins:
			var app := CharacterAppearance.new()
			app.skin_color = skin
			list.append(app)
		return list

	for face in faces:
		for skin in skins:
			var app := CharacterAppearance.new()
			app.face_texture = face
			app.skin_color = skin
			list.append(app)
	return list
