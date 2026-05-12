extends Node3D

# MapManager.gd
# Gère les données de la carte (grille) et le rendu des infrastructures.

# Dictionnaire pour stocker les types d'infrastructures par coordonnées de grille (Vector2i)
var grid_data = {} # { Vector2i: String }
# Dictionnaire pour stocker les instances visuelles
var visuals = {}   # { Vector2i: Node3D }

@export var grid_size: float = 2.0
var route_scene = preload("res://RouteVisual.tscn")

func _ready() -> void:
	# On s'assure que le MapManager est bien positionné au centre si nécessaire
	# mais comme il gère des positions absolues, peu importe.
	pass

# Ajoute une route à la position donnée (coordonnées de grille)
func add_road(grid_pos: Vector2i):
	if grid_data.has(grid_pos):
		return # Empêche de poser deux routes au même endroit

	grid_data[grid_pos] = "route"
	_create_visual(grid_pos)
	_update_neighbors(grid_pos)

# Crée l'instance visuelle pour une case de route
func _create_visual(grid_pos: Vector2i):
	if not route_scene:
		push_error("RouteVisual.tscn n'est pas chargé")
		return

	var instance = route_scene.instantiate()
	add_child(instance)

	# Positionnement au centre de la case de grille
	# On multiplie par grid_size et on ajoute grid_size/2 pour centrer le mesh
	var world_x = grid_pos.x * grid_size + (grid_size / 2.0)
	var world_z = grid_pos.y * grid_size + (grid_size / 2.0)
	instance.position = Vector3(world_x, 0.01, world_z) # 0.01 pour éviter le Z-fighting avec le sol

	visuals[grid_pos] = instance
	_update_visual(grid_pos)

# Met à jour les voisins d'une case pour recalculer leur auto-tiling
func _update_neighbors(grid_pos: Vector2i):
	var neighbors = [
		grid_pos + Vector2i.UP,
		grid_pos + Vector2i.DOWN,
		grid_pos + Vector2i.LEFT,
		grid_pos + Vector2i.RIGHT
	]
	for n in neighbors:
		if visuals.has(n):
			_update_visual(n)

# Logique d'auto-tiling simplifiée
func _update_visual(grid_pos: Vector2i):
	var visual = visuals[grid_pos]
	if not visual: return

	# Vérification de la présence de voisins (haut, bas, gauche, droite)
	var up = grid_data.has(grid_pos + Vector2i.UP)
	var down = grid_data.has(grid_pos + Vector2i.DOWN)
	var left = grid_data.has(grid_pos + Vector2i.LEFT)
	var right = grid_data.has(grid_pos + Vector2i.RIGHT)

	# Logique de rotation et d'échelle pour simuler des connexions
	# C'est ici qu'on peut plus tard remplacer par des modèles de virages/croisements

	if (up or down) and not (left or right):
		# Route verticale
		visual.rotation_degrees.y = 90
		visual.scale = Vector3(1, 1, 1)
	elif (left or right) and not (up or down):
		# Route horizontale
		visual.rotation_degrees.y = 0
		visual.scale = Vector3(1, 1, 1)
	elif (up or down) and (left or right):
		# Intersection
		visual.rotation_degrees.y = 0
		# On augmente un peu l'échelle pour couvrir l'intersection avec le rectangle
		visual.scale = Vector3(1.2, 1, 1.2)
	else:
		# Route isolée
		visual.rotation_degrees.y = 0
		visual.scale = Vector3(1, 1, 1)
