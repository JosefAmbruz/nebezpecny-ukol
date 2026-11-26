# character_appearance.gd
class_name CharacterAppearance
extends Resource

@export var face_texture: Texture2D
@export var skin_color: Color = Color.WHITE
# Rezerva pro pozdější customizaci (vlasy, uši, oblečení...)


## Jednoznačný klíč kombinace vzhledu pro hlídání unikátnosti assassinů vs civilistů.
func get_signature() -> String:
	var face_key := face_texture.resource_path if face_texture else "none"
	return "%s|%s" % [face_key, skin_color.to_html(false)]
