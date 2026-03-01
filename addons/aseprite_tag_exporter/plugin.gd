@tool
extends EditorPlugin

const ContextMenu = preload("context_menu.gd")

var _context_menu: EditorContextMenuPlugin


func _enter_tree() -> void:
	_context_menu = ContextMenu.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _context_menu)


func _exit_tree() -> void:
	remove_context_menu_plugin(_context_menu)
