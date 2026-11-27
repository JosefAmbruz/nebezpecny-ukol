class_name PortraitBaker
extends RefCounted

const CHARACTER_VISUALS_SCENE: PackedScene = preload("res://src/characters/character_visuals.tscn")


## Vyfotí 3D hlavu pro každé CharacterData pomocí dočasného izolovaného SubViewportu
## a uloží výsledek jako ImageTexture do `data.portrait`.
static func bake_portraits(
	host_node: Node,
	characters: Array[CharacterData],
	portrait_size: Vector2i = Vector2i(128, 128)
) -> void:
	if characters.is_empty() or not is_instance_valid(host_node):
		return

	var viewport := SubViewport.new()
	viewport.name = "PortraitBakerViewport"
	viewport.size = portrait_size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25.0, 20.0, 0.0)
	light.light_energy = 1.1
	viewport.add_child(light)

	var visuals := CHARACTER_VISUALS_SCENE.instantiate() as CharacterVisuals
	viewport.add_child(visuals)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.75
	camera.position = Vector3(0.0, 1.21, 3.0)
	camera.current = true
	viewport.add_child(camera)

	host_node.add_child(viewport)

	# Skryjeme tělo, fotíme jen hlavu (případně budoucí 3D vlasy + uši)
	visuals.body_rig.hide()
	visuals.look_forward()
	visuals.head_pivot.rotation = Vector3.ZERO

	var tree := host_node.get_tree()
	await tree.process_frame

	for data in characters:
		if not data or not data.appearance:
			continue

		visuals.appearance = data.appearance
		visuals.head_pivot.rotation = Vector3.ZERO

		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await tree.process_frame
		await RenderingServer.frame_post_draw

		var img := viewport.get_texture().get_image()
		if img and not img.is_empty():
			data.portrait = ImageTexture.create_from_image(img.duplicate())

	viewport.queue_free()
