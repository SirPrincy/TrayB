extends Node3D

# MapManager.gd
# Gère les données de la carte (grille), le rendu des infrastructures et la navigation A*.

signal road_removed(grid_pos: Vector2i)

enum CargoType { NONE, PASSENGER, CARGO }

# Dictionnaire pour stocker les types d'infrastructures par coordonnées de grille (Vector2i)
var grid_data = {} # { Vector2i: String }
# Dictionnaire pour stocker les instances visuelles
var visuals = {}   # { Vector2i: Node3D }
# Dictionnaire pour stocker les instances de bâtiments (pour accéder à leurs stocks)
var buildings_instances = {} # { Vector2i: Node }

@export var grid_size: float = 2.0
@export var road_cost: int = 50
var route_scene = preload("res://RouteVisual.tscn")

# Système de navigation A*
var astar = AStar2D.new()
var _grid_to_id = {}
var _next_id = 0

func _ready() -> void:
	pass

# Vérifie si le terrain aux coordonnées données est constructible (Terre vs Mer)
func is_valid_terrain(grid_pos: Vector2i) -> bool:
	var world_pos = grid_to_world(grid_pos)
	var x = world_pos.x
	var z = world_pos.z

	# Définition simplifiée des zones de terre (Madagascar) basée sur main.tscn
	# (Ajustée pour inclure les positions des villes)

	# Main Body
	if x >= -25.0 and x <= 25.0 and z >= -55.0 and z <= 55.0:
		return true

	# North
	if x >= -10.0 and x <= 20.0 and z >= -75.0 and z <= -25.0:
		return true

	# South
	if x >= -25.0 and x <= 15.0 and z >= 25.0 and z <= 75.0:
		return true

	return false

# Retourne un ID unique pour une position de grille
func _get_or_create_id(grid_pos: Vector2i) -> int:
	if not _grid_to_id.has(grid_pos):
		_grid_to_id[grid_pos] = _next_id
		astar.add_point(_next_id, Vector2(grid_pos.x, grid_pos.y))
		_next_id += 1
	return _grid_to_id[grid_pos]

# Ajoute une route à la position donnée (coordonnées de grille)
func add_road(grid_pos: Vector2i):
	if grid_data.has(grid_pos):
		return

	if not is_valid_terrain(grid_pos):
		# Optionnel : Message d'erreur ici si nécessaire
		return

	# Vérification du budget via EconomyManager
	if not EconomyManager.spend_money(road_cost):
		var ui = get_tree().root.find_child("Control", true)
		if ui and ui.has_method("show_notification"):
			ui.show_notification("Fonds insuffisants !")
		return

	grid_data[grid_pos] = "route"
	_create_visual(grid_pos)
	_update_astar_connections(grid_pos)
	_update_neighbors(grid_pos)

# Permet d'ajouter un bâtiment qui participe à la navigation
func add_building(grid_pos: Vector2i, type: String, instance: Node = null):
	if grid_data.has(grid_pos):
		return

	grid_data[grid_pos] = type
	if instance:
		buildings_instances[grid_pos] = instance

	_update_astar_connections(grid_pos)
	# On ne crée pas de visuel ici car le bâtiment a sa propre scène

func _update_astar_connections(grid_pos: Vector2i):
	var current_id = _get_or_create_id(grid_pos)
	var neighbors = [
		grid_pos + Vector2i.UP,
		grid_pos + Vector2i.DOWN,
		grid_pos + Vector2i.LEFT,
		grid_pos + Vector2i.RIGHT
	]

	for n_pos in neighbors:
		if grid_data.has(n_pos):
			var n_id = _get_or_create_id(n_pos)
			astar.connect_points(current_id, n_id)

# Supprime une route
func remove_road(grid_pos: Vector2i):
	if not grid_data.has(grid_pos) or grid_data[grid_pos] != "route":
		return

	grid_data.erase(grid_pos)

	if visuals.has(grid_pos):
		visuals[grid_pos].queue_free()
		visuals.erase(grid_pos)

	if _grid_to_id.has(grid_pos):
		var id = _grid_to_id[grid_pos]
		astar.remove_point(id)
		_grid_to_id.erase(grid_pos)

	road_removed.emit(grid_pos)
	_update_neighbors(grid_pos)

# Calcule un chemin entre deux positions de grille
func get_route_path(start_grid_pos: Vector2i, end_grid_pos: Vector2i) -> Array[Vector3]:
	if not _grid_to_id.has(start_grid_pos) or not _grid_to_id.has(end_grid_pos):
		return []

	var start_id = _grid_to_id[start_grid_pos]
	var end_id = _grid_to_id[end_grid_pos]

	var point_path = astar.get_point_path(start_id, end_id)
	var world_path: Array[Vector3] = []

	for point in point_path:
		world_path.append(grid_to_world(Vector2i(int(point.x), int(point.y))))

	return world_path

# Utilitaires de conversion
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var world_x = grid_pos.x * grid_size + (grid_size / 2.0)
	var world_z = grid_pos.y * grid_size + (grid_size / 2.0)
	return Vector3(world_x, 0.0, world_z)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var grid_x = floor(world_pos.x / grid_size)
	var grid_z = floor(world_pos.z / grid_size)
	return Vector2i(int(grid_x), int(grid_z))

# Crée l'instance visuelle pour une case de route
func _create_visual(grid_pos: Vector2i):
	if not route_scene:
		return

	var instance = route_scene.instantiate()
	add_child(instance)
	instance.position = grid_to_world(grid_pos)
	instance.position.y = 0.01

	visuals[grid_pos] = instance
	_update_visual(grid_pos)

# Met à jour les voisins d'une case
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

	var up = grid_data.get(grid_pos + Vector2i.UP) == "route"
	var down = grid_data.get(grid_pos + Vector2i.DOWN) == "route"
	var left = grid_data.get(grid_pos + Vector2i.LEFT) == "route"
	var right = grid_data.get(grid_pos + Vector2i.RIGHT) == "route"

	if (up or down) and not (left or right):
		visual.rotation_degrees.y = 90
		visual.scale = Vector3(1, 1, 1)
	elif (left or right) and not (up or down):
		visual.rotation_degrees.y = 0
		visual.scale = Vector3(1, 1, 1)
	elif (up or down) and (left or right):
		visual.rotation_degrees.y = 0
		visual.scale = Vector3(1.2, 1, 1.2)
	else:
		visual.rotation_degrees.y = 0
		visual.scale = Vector3(1, 1, 1)
