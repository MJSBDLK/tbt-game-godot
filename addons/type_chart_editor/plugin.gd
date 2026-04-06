@tool
extends EditorPlugin


var _panel: Control = null


func _enter_tree() -> void:
	_panel = preload("type_chart_editor_panel.gd").new()
	_panel.name = "TypeChartEditor"
	add_control_to_bottom_panel(_panel, "Type Chart")


func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
