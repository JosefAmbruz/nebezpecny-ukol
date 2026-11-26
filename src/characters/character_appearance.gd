# character_appearance.gd
class_name CharacterAppearance
extends Resource

@export var face_texture: Texture2D
@export var skin_color: Color = Color.WHITE
## 3D scéna na hlavu (klobouk pro questová NPC, později vlasy pro všechny postavy).
@export var headwear_scene: PackedScene


## Jednoznačný klíč kombinace vzhledu pro hlídání unikátnosti assassinů vs civilistů.
func get_signature() -> String:
	var face_key := face_texture.resource_path if face_texture else "none"
	var head_key := headwear_scene.resource_path if headwear_scene else "none"
	return "%s|%s|%s" % [face_key, skin_color.to_html(false), head_key]
