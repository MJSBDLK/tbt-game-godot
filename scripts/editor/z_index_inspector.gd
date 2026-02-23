## @tool script for inspecting z_index values in the editor.
## Select any Node2D in the scene tree and this will decode its z_index
## into human-readable row/layer information in the inspector.
@tool
class_name ZIndexInspector
extends EditorScript


func _run() -> void:
	var editor := EditorInterface.get_selection()
	var selected := editor.get_selected_nodes()

	if selected.is_empty():
		print("ZIndexInspector: No node selected")
		return

	print("=== Z-Index Inspector ===")
	for node: Node in selected:
		if node is Node2D:
			var node_2d := node as Node2D
			var z := node_2d.z_index
			var decoded := ZIndexCalculator.decode_z_index(z)
			print("  %s: z_index=%d -> %s (relative=%s)" % [
				node_2d.name, z, decoded, str(node_2d.z_as_relative)])
		else:
			print("  %s: not a Node2D" % node.name)
	print("=========================")
