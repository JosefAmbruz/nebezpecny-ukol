class_name AssassinListEntry
extends PanelContainer

@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _name_label: Label = %NameLabel
@onready var _trait_label: Label = %TraitLabel
@onready var _dead_overlay: Control = %DeadOverlay

var character_id: StringName = &""


func setup(data: CharacterData) -> void:
	character_id = data.id
	_name_label.text = data.display_name
	_trait_label.text = CharacterData.PERSONALITY_NAMES[data.personality]
	_trait_label.visible = not _trait_label.text.is_empty()
	_portrait_texture.texture = data.portrait
	set_alive(data.is_alive)


func set_alive(alive: bool) -> void:
	_dead_overlay.visible = not alive
	modulate = Color.WHITE if alive else Color(0.55, 0.55, 0.55, 0.8)
