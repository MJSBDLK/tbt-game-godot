@tool
extends EditorInspectorPlugin

const PaletteProperty = preload("palette_property.gd")


func _can_handle(object: Object) -> bool:
	return true


func _parse_property(object: Object, type: Variant.Type, name: String,
		hint_type: PropertyHint, hint_string: String,
		usage_flags: int, wide: bool) -> bool:
	if type == TYPE_COLOR:
		var editor = PaletteProperty.new()
		editor.no_alpha = (hint_type == PROPERTY_HINT_COLOR_NO_ALPHA)
		add_property_editor(name, editor)
		return true
	return false
