extends Node

# ToolManager.gd
# Gère les modes d'outils et l'état actuel de l'interaction utilisateur.

enum ToolMode { CONSTRUIRE, SUPPRIMER, SELECTION_VILLE, INSPECTER }

signal mode_changed(new_mode: ToolMode)

var current_mode: ToolMode = ToolMode.INSPECTER:
	set(value):
		current_mode = value
		mode_changed.emit(current_mode)
		print("Mode d'outil changé : ", ToolMode.keys()[current_mode])

func set_mode(mode: ToolMode):
	self.current_mode = mode
