extends StaticBody3D

# City.gd
# Représente une ville (Lieu comme dans Fly Corp)
# Génère des passagers et permet d'envoyer des véhicules vers d'autres villes connectées.

@export var city_name: String = "Ville"
@export var population: int = 1000
@export var vehicle_scene = preload("res://Vehicle.tscn")
@export var stock_type: MapManager.CargoType = MapManager.CargoType.PASSENGER

var targeted_demand: Dictionary = {} # { "NomVille": nombre_passagers }
var generation_rate: float = 0.0

@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	# Enregistrement dans MapManager
	var grid_pos = MapManager.world_to_grid(global_position)
	MapManager.add_building(grid_pos, "city", self)

	# Initialisation du taux de génération basé sur la population (ex: 1 passager pour 500 habitants par tick)
	generation_rate = max(1.0, population / 500.0)

	label_3d.text = city_name

	# Connexion au signal de tick
	EconomyManager.game_tick.connect(_on_game_tick)

func _on_game_tick():
	# Générer de la demande vers les autres villes
	for pos in MapManager.buildings_instances.keys():
		var building = MapManager.buildings_instances[pos]
		if building == self or not building.has_method("is_city"):
			continue

		var dest_name = building.city_name
		if not targeted_demand.has(dest_name):
			targeted_demand[dest_name] = 0

		# Calcul de la croissance basée sur la population de la destination
		# Les grandes villes attirent plus de monde
		var attraction_factor = building.population / 1000.0
		var growth = int(generation_rate * attraction_factor * randf_range(0.5, 1.5))
		targeted_demand[dest_name] += max(1, growth)

	update_label()

func update_label():
	var total_stock = 0
	for count in targeted_demand.values():
		total_stock += count
	label_3d.text = city_name + "\n(" + str(total_stock) + ")"

# Fonction pour le chargement ciblé par le véhicule
func take_targeted_stock(dest_name: String, max_to_take: int) -> int:
	if not targeted_demand.has(dest_name):
		return 0

	var available = targeted_demand[dest_name]
	var taken = min(available, max_to_take)
	targeted_demand[dest_name] -= taken
	update_label()
	return taken

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_city_clicked()

func _on_city_clicked():
	if ToolManager.current_mode != ToolManager.ToolMode.SELECTION_VILLE:
		print("Cliquez sur l'icône Ville pour sélectionner une destination")
		return

	print("Ville source sélectionnée : ", city_name)
	# Utiliser l'UI pour afficher les destinations possibles
	var ui = get_tree().root.find_child("Control", true)
	if ui and ui.has_method("show_destination_panel"):
		ui.show_destination_panel(self)

func get_reachable_cities() -> Array:
	var my_grid_pos = MapManager.world_to_grid(global_position)
	var cities_info = []

	for pos in MapManager.buildings_instances.keys():
		if pos == my_grid_pos:
			continue

		var building = MapManager.buildings_instances[pos]
		if MapManager.grid_data.get(pos) == "city":
			# Vérifier si un chemin existe déjà
			var existing_path = MapManager.get_route_path(my_grid_pos, pos)
			var connected = existing_path.size() >= 2

			var path_to_use = existing_path
			var construction_cost = 0
			var grid_path = []

			if not connected:
				# Calculer le chemin potentiel et le coût
				grid_path = MapManager.get_potential_path(my_grid_pos, pos)
				if grid_path.size() >= 2:
					var segments_to_build = 0
					for gp in grid_path:
						if not MapManager.grid_data.has(gp):
							segments_to_build += 1
					construction_cost = segments_to_build * MapManager.road_cost

					# Convertir grid_path en world_path pour l'aperçu/usage futur
					path_to_use = []
					for gp in grid_path:
						path_to_use.append(MapManager.grid_to_world(gp))

			if path_to_use.size() >= 2:
				cities_info.append({
					"pos": pos,
					"path": path_to_use,
					"grid_path": grid_path,
					"name": building.city_name if "city_name" in building else "Inconnu",
					"connected": connected,
					"construction_cost": construction_cost
				})
	return cities_info

func spawn_vehicle_to(path: Array[Vector3], dest_name: String):
	# Vérification de la demande pour la destination spécifique
	if not targeted_demand.has(dest_name) or targeted_demand[dest_name] <= 0:
		print("Pas de passagers pour ", dest_name, " à ", city_name)
		return

	var vehicle = vehicle_scene.instantiate()
	get_parent().add_child(vehicle)

	# Passer l'info de destination au véhicule
	if vehicle.has_method("set_line_destination"):
		vehicle.set_line_destination(dest_name)

	# Le chargement s'effectue automatiquement via vehicle.set_path() -> try_load()
	vehicle.set_path(path)
	print("Véhicule envoyé de ", city_name, " vers ", dest_name, " avec ", vehicle.current_load, " passagers.")

func is_city():
	return true
