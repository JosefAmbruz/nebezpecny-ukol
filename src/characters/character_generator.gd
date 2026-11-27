class_name CharacterGenerator
extends RefCounted


## Vygeneruje `total_count` unikátních assassinů (50/50 muži/ženy s respektem k dostupným jménům).
## Prvních `quest_count` začíná v Levelu 1 u Padrina Pacata a jako jediní (spolu s hráčem) mohou plnit quest.
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

	var male_names: Array[String] = pool.male_names.duplicate()
	var female_names: Array[String] = pool.female_names.duplicate()
	male_names.shuffle()
	female_names.shuffle()

	var used_signatures: Dictionary = {}
	var clamped_quest_count := mini(quest_count, total_count)

	for i in range(total_count):
		var gender := _pick_gender_for_assassin(male_names, female_names)
		var app := _generate_unique_appearance_for_gender(pool, gender, used_signatures)
		if not app:
			# Zkusíme druhé pohlaví, pokud pro první došly unikátní kombinace
			var other := (
				CharacterAppearance.Gender.FEMALE
				if gender == CharacterAppearance.Gender.MALE
				else CharacterAppearance.Gender.MALE
			)
			gender = other
			app = _generate_unique_appearance_for_gender(pool, gender, used_signatures)
			if not app:
				break

		used_signatures[app.get_signature()] = true

		var data := CharacterData.new()
		data.id = StringName("assassin_%d" % i)
		data.display_name = _pop_name_for_gender(gender, male_names, female_names, i)
		data.appearance = app
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

	if result.size() < total_count:
		push_warning(
			"CharacterGenerator: Pool má jen %d unikátních kombinací (požadováno %d)."
			% [result.size(), total_count]
		)

	return result


## Vrátí množinu signatur (Dictionary jako Set) všech assassinů.
static func collect_reserved_signatures(assassins: Array[CharacterData]) -> Dictionary:
	var reserved: Dictionary = {}
	for data in assassins:
		if data and data.appearance:
			reserved[data.appearance.get_signature()] = true
	return reserved


## Vygeneruje náhodný vzhled civilisty (nebo hráče) 50/50 muž/žena mimo `reserved_signatures`.
static func generate_civilian_appearance(
	pool: AppearancePool,
	reserved_signatures: Dictionary
) -> CharacterAppearance:
	if not pool:
		return CharacterAppearance.new()

	var gender := (
		CharacterAppearance.Gender.MALE
		if randf() < 0.5
		else CharacterAppearance.Gender.FEMALE
	)
	var unique := _generate_unique_appearance_for_gender(pool, gender, reserved_signatures)
	if unique:
		return unique

	var other := (
		CharacterAppearance.Gender.FEMALE
		if gender == CharacterAppearance.Gender.MALE
		else CharacterAppearance.Gender.MALE
	)
	unique = _generate_unique_appearance_for_gender(pool, other, reserved_signatures)
	if unique:
		return unique

	return _sample_random_appearance(pool, gender)


static func _pick_gender_for_assassin(male_names: Array[String], female_names: Array[String]) -> CharacterAppearance.Gender:
	var has_m := not male_names.is_empty()
	var has_f := not female_names.is_empty()
	if has_m and has_f:
		return CharacterAppearance.Gender.MALE if randf() < 0.5 else CharacterAppearance.Gender.FEMALE
	if has_m:
		return CharacterAppearance.Gender.MALE
	if has_f:
		return CharacterAppearance.Gender.FEMALE
	return CharacterAppearance.Gender.MALE if randf() < 0.5 else CharacterAppearance.Gender.FEMALE


static func _pop_name_for_gender(
	gender: CharacterAppearance.Gender,
	male_names: Array[String],
	female_names: Array[String],
	index: int
) -> String:
	if gender == CharacterAppearance.Gender.MALE and not male_names.is_empty():
		return male_names.pop_back()
	if gender == CharacterAppearance.Gender.FEMALE and not female_names.is_empty():
		return female_names.pop_back()
	return ("Assassin #%d" if gender == CharacterAppearance.Gender.MALE else "Assassinka #%d") % (index + 1)


static func _generate_unique_appearance_for_gender(
	pool: AppearancePool,
	gender: CharacterAppearance.Gender,
	used_signatures: Dictionary
) -> CharacterAppearance:
	for _attempt in range(40):
		var candidate := _sample_random_appearance(pool, gender)
		if not used_signatures.has(candidate.get_signature()):
			return candidate

	var all_for_gender := _build_all_unique_appearances(pool, gender)
	all_for_gender.shuffle()
	for app in all_for_gender:
		if not used_signatures.has(app.get_signature()):
			return app
	return null


static func _sample_random_appearance(pool: AppearancePool, gender: CharacterAppearance.Gender) -> CharacterAppearance:
	var app := CharacterAppearance.new()
	app.gender = gender

	var faces := pool.get_faces_for(gender)
	if not faces.is_empty():
		app.face_texture = faces.pick_random()

	if not pool.skin_colors.is_empty():
		app.skin_color = pool.skin_colors.pick_random()

	var hairs := pool.get_hair_scenes_for(gender)
	var bald_chance := pool.get_bald_chance_for(gender)
	if not hairs.is_empty() and randf() >= bald_chance:
		app.headwear_scene = hairs.pick_random()
		if not pool.hair_colors.is_empty():
			app.hair_color = pool.hair_colors.pick_random()

	return app


static func _build_all_unique_appearances(
	pool: AppearancePool,
	gender: CharacterAppearance.Gender
) -> Array[CharacterAppearance]:
	var list: Array[CharacterAppearance] = []
	var faces := pool.get_faces_for(gender)
	var skins: Array[Color] = pool.skin_colors if not pool.skin_colors.is_empty() else [Color.WHITE]
	var hairs := pool.get_hair_scenes_for(gender)
	var h_colors: Array[Color] = pool.hair_colors if not pool.hair_colors.is_empty() else [Color(0.18, 0.14, 0.12, 1.0)]
	var allow_bald := pool.get_bald_chance_for(gender) > 0.0 or hairs.is_empty()

	var face_list: Array = faces if not faces.is_empty() else [null]
	for face in face_list:
		for skin in skins:
			if allow_bald:
				var bald := CharacterAppearance.new()
				bald.gender = gender
				bald.face_texture = face
				bald.skin_color = skin
				list.append(bald)

			for hair in hairs:
				for h_col in h_colors:
					var app := CharacterAppearance.new()
					app.gender = gender
					app.face_texture = face
					app.skin_color = skin
					app.headwear_scene = hair
					app.hair_color = h_col
					list.append(app)
	return list
