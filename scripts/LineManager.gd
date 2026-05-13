extends Node

# LineManager.gd
# Gère les lignes de transport régulières, leur création et leur économie.

class TransportLine:
	var id: String
	var origin_name: String
	var dest_name: String
	var origin_pos: Vector2i
	var dest_pos: Vector2i
	var path: Array[Vector3]
	var vehicles: Array[Node] = []
	var daily_profit: int = 0
	var total_profit: int = 0
	var frequency: float = 0.0 # Véhicules par minute (théorique)

	func _init(_origin_name: String, _dest_name: String, _origin_pos: Vector2i, _dest_pos: Vector2i, _path: Array[Vector3]):
		self.origin_name = _origin_name
		self.dest_name = _dest_name
		self.origin_pos = _origin_pos
		self.dest_pos = _dest_pos
		self.path = _path
		self.id = _origin_name + "-" + _dest_name

var lines: Dictionary = {} # { id: TransportLine }
var vehicle_pool: Array[Node] = []

signal lines_updated

func _ready():
	EconomyManager.day_changed.connect(_on_day_changed)

func _on_day_changed(_day: int):
	for line_id in lines:
		var line = lines[line_id]
		# Réinitialiser le profit quotidien (les profits sont accumulés via les véhicules)
		line.daily_profit = 0

func create_line(origin_city, dest_city) -> bool:
	var origin_name = origin_city.city_name
	var dest_name = dest_city.city_name
	var line_id = origin_name + "-" + dest_name

	if lines.has(line_id):
		return false

	var origin_grid = MapManager.world_to_grid(origin_city.global_position)
	var dest_grid = MapManager.world_to_grid(dest_city.global_position)

	var path = MapManager.get_route_path(origin_grid, dest_grid)
	if path.size() < 2:
		return false

	var new_line = TransportLine.new(origin_name, dest_name, origin_grid, dest_grid, path)
	lines[line_id] = new_line
	lines_updated.emit()
	return true

func add_vehicle_to_line(line_id: String):
	if not lines.has(line_id):
		return

	var line = lines[line_id]
	var vehicle = _get_or_create_vehicle()

	if not line.vehicles.has(vehicle):
		line.vehicles.append(vehicle)

	# Initialiser le véhicule sur la ligne
	if vehicle.has_method("assign_to_line"):
		vehicle.assign_to_line(line)

	_recalculate_line_frequency(line)
	lines_updated.emit()

func remove_vehicle_from_line(line_id: String):
	if not lines.has(line_id) or lines[line_id].vehicles.is_empty():
		return

	var line = lines[line_id]
	var vehicle = line.vehicles.pop_back()

	if vehicle.has_method("unassign"):
		vehicle.unassign()

	_recalculate_line_frequency(line)
	lines_updated.emit()

func close_line(line_id: String):
	if not lines.has(line_id):
		return

	var line = lines[line_id]
	for vehicle in line.vehicles:
		if vehicle.has_method("unassign"):
			vehicle.unassign()

	lines.erase(line_id)
	lines_updated.emit()

func _get_or_create_vehicle() -> Node:
	# Nettoyage du pool (sécurisé)
	var i = vehicle_pool.size() - 1
	while i >= 0:
		if not is_instance_valid(vehicle_pool[i]):
			vehicle_pool.remove_at(i)
		i -= 1

	for v in vehicle_pool:
		if not v.visible: # Considéré comme "au garage"
			v.show()
			if v.has_method("exit_garage"):
				v.exit_garage()
			return v

	# Créer un nouveau véhicule
	var vehicle_scene = preload("res://Vehicle.tscn")
	var vehicle = vehicle_scene.instantiate()
	# Ajout au parent de la carte pour être dans le monde
	var world = get_tree().current_scene
	world.add_child(vehicle)

	vehicle_pool.append(vehicle)
	return vehicle

func _recalculate_line_frequency(line: TransportLine):
	if line.vehicles.is_empty() or line.path.size() < 2:
		line.frequency = 0.0
		return

	var total_dist = 0.0
	for j in range(line.path.size() - 1):
		total_dist += line.path[j].distance_to(line.path[j+1])

	# Temps aller-retour (approximatif, speed=5.0)
	var cycle_time = (total_dist * 2.0) / 5.0
	if cycle_time > 0:
		line.frequency = (line.vehicles.size() * 60.0) / cycle_time # Véhicules par minute

func register_profit(line_id: String, amount: int):
	if lines.has(line_id):
		lines[line_id].daily_profit += amount
		lines[line_id].total_profit += amount
