extends StaticBody3D

# City.gd
# Représente une ville (Lieu comme dans Fly Corp)
# Génère des passagers et permet d'envoyer des véhicules vers d'autres villes connectées.

@export var city_name: String = "Ville"
@export var population: int = 1000
@export var vehicle_scene = preload("res://Vehicle.tscn")
@export var stock_type: MapManager.CargoType = MapManager.CargoType.PASSENGER

var stock_amount: int = 0
var generation_rate: float = 0.0

@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	# Enregistrement dans MapManager
	var grid_pos = MapManager.world_to_grid(global_position)
	MapManager.add_building(grid_pos, "city", self)

	# Initialisation du taux de génération basé sur la population (ex: 1 passager pour 1000 habitants par tick)
	generation_rate = max(1, population / 500.0)

	label_3d.text = city_name

	# Connexion au signal de tick
	EconomyManager.game_tick.connect(_on_game_tick)

func _on_game_tick():
	stock_amount += int(generation_rate)
	update_label()

func update_label():
	label_3d.text = city_name + "\n(" + str(stock_amount) + ")"

# Fonction pour le chargement par le véhicule
func take_stock(max_to_take: int) -> int:
	var taken = min(stock_amount, max_to_take)
	stock_amount -= taken
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
	var reachable_cities = []

	for pos in MapManager.buildings_instances.keys():
		if pos == my_grid_pos:
			continue

		var building = MapManager.buildings_instances[pos]
		if MapManager.grid_data.get(pos) == "city":
			# Vérifier si un chemin existe
			var path = MapManager.get_route_path(my_grid_pos, pos)
			if path.size() >= 2:
				reachable_cities.append({
					"pos": pos,
					"path": path,
					"name": building.city_name if "city_name" in building else "Inconnu"
				})
	return reachable_cities

func spawn_vehicle_to(path: Array[Vector3]):
	if stock_amount <= 0:
		print("Pas assez de passagers à ", city_name)
		return

	var vehicle = vehicle_scene.instantiate()
	get_parent().add_child(vehicle)
	# Le chargement s'effectue automatiquement via vehicle.set_path() -> try_load()
	vehicle.set_path(path)
	print("Véhicule envoyé de ", city_name, " vers destination avec ", vehicle.current_load, " passagers.")

func is_city():
	return true
