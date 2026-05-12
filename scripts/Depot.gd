extends StaticBody3D

# Depot.gd
# Un bâtiment qui fait apparaître un véhicule lorsqu'on clique dessus.

@export var vehicle_scene = preload("res://Vehicle.tscn")

# Gestion du stock
@export var stock_type: MapManager.CargoType = MapManager.CargoType.PASSENGER
@export var stock_amount: int = 0
@export var generation_rate: int = 5 # Nombre d'unités générées par tick

func _ready() -> void:
	# Enregistrement du dépôt dans MapManager pour la navigation et l'accès au stock
	var grid_pos = MapManager.world_to_grid(global_position)
	MapManager.add_building(grid_pos, "depot", self)

	# Connexion au signal de tick pour générer du stock
	EconomyManager.game_tick.connect(_on_game_tick)

# Génère du stock à chaque tick de jeu
func _on_game_tick():
	stock_amount += generation_rate
	# print("Dépôt : Stock actuel (", MapManager.CargoType.keys()[stock_type], ") = ", stock_amount)

# Fonction pour permettre au véhicule de récupérer du stock
func take_stock(max_to_take: int) -> int:
	var taken = min(stock_amount, max_to_take)
	stock_amount -= taken
	return taken

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_spawn_vehicle()

func _spawn_vehicle():
	print("Dépôt cliqué ! Apparition d'un véhicule.")

	# Position du dépôt sur la grille
	var grid_pos = MapManager.world_to_grid(global_position)

	# On cherche une destination (une route existante au hasard pour le test)
	var roads = []
	for pos in MapManager.grid_data.keys():
		if MapManager.grid_data[pos] == "route":
			roads.append(pos)

	if roads.is_empty():
		print("Aucune route disponible pour le véhicule !")
		return

	var target_pos = roads.pick_random()
	var path = MapManager.get_route_path(grid_pos, target_pos)

	if path.is_empty():
		print("Pas de chemin trouvé vers ", target_pos)
		return

	var vehicle = vehicle_scene.instantiate()
	get_parent().add_child(vehicle)
	vehicle.set_path(path)
