class_name UiUtils
extends RefCounted
## Small UI helpers shared across screens

## Hides every Window-derived child (FileDialog | ConfirmationDialog | AcceptDialog)
## Window.visible defaults to true, so a dialog left visible in the editor pops open as soon as its parent scene enters the tree
## Call this first in every _ready()
static func hide_dialogs(root: Node) -> void:
	for child in root.get_children():
		if child is Window:
			child.hide()
		elif child.get_child_count() > 0:
			hide_dialogs(child)   # Dialogs nested inside containers 
