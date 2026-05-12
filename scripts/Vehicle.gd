extends Node3D

# Vehicle.gd
# Gère le déplacement fluide du véhicule sur la grille via le chemin A*.
# Intègre maintenant le système économique (maintenance et revenus).

@export var speed: float = 5.0
@export var reward_per_unit: int = 20 # Gain par unité transportée
@export var base_maintenance: int = 10 # Coût de base (à l'arrêt ou plein)
@export var empty_running_penalty: int = 5 # Coût supplémentaire si roule à vide

# Système de cargaison
@export var max_capacity: int = 10
var current_load: int = 0:
	set(value):
		current_load = value
		update_visuals()
var load_type: MapManager.CargoType = MapManager.CargoType.NONE:
	set(value):
		load_type = value
		update_visuals()

# Coût de maintenance dynamique
var maintenance_cost: int:
	get:
		if is_moving and current_load == 0:
			return base_maintenance + empty_running_penalty
		return base_maintenance

var path: Array[Vector3] = []
var target_index: int = 0
var is_moving: bool = false

@onready var mesh_instance = $MeshInstance3D
@onready var progress_bar = $ProgressBar # Sera ajouté dans le .tscn

func _ready() -> void:
	# On s'assure que le véhicule est bien au-dessus du sol
	position.y = 0.5
	MapManager.road_removed.connect(_on_road_removed_globally)

	# Ajout au groupe pour le calcul de la maintenance par EconomyManager
	add_to_group("vehicles")

	# Initialisation visuelle
	update_visuals()

func _on_road_removed_globally(_grid_pos: Vector2i):
	check_path_validity()

func _process(delta: float) -> void:
	if not is_moving or target_index >= path.size():
		return

	# Intégration du speed_factor du TimeManager
	# Note: Engine.time_scale gère déjà delta si on utilise delta normalement.

	var target_pos = path[target_index]
	target_pos.y = position.y # Garder la même hauteur

	var direction = (target_pos - position).normalized()
	var distance = position.distance_to(target_pos)

	# Mouvement fluide
	var move_distance = speed * delta

	if move_distance >= distance:
		position = target_pos
		target_index += 1
		if target_index >= path.size():
			_on_arrival()
	else:
		position += direction * move_distance
		# Rotation vers la cible pour le look
		if direction != Vector3.ZERO:
			look_at(position + direction, Vector3.UP)

# Définit un nouveau chemin à suivre
func set_path(new_path: Array[Vector3]):
	if new_path.size() < 2:
		is_moving = false
		return

	path = new_path
	target_index = 1 # On commence à l'index 1 car l'index 0 est la position actuelle
	position = path[0]
	position.y = 0.5

	# Essayer de charger avant de partir
	try_load()

	is_moving = true

# Tente de charger du stock depuis un bâtiment à la position actuelle
func try_load():
	var grid_pos = MapManager.world_to_grid(position)
	if MapManager.buildings_instances.has(grid_pos):
		var building = MapManager.buildings_instances[grid_pos]
		if building.has_method("take_stock"):
			self.load_type = building.stock_type
			self.current_load = building.take_stock(max_capacity)
			print("Véhicule chargé : ", current_load, " de type ", MapManager.CargoType.keys()[load_type])

# Met à jour l'apparence du véhicule selon son chargement
func update_visuals():
	if not is_inside_tree() or not mesh_instance:
		return

	# Changement de couleur selon le type de cargaison
	var color = Color.WHITE # NONE
	match load_type:
		MapManager.CargoType.PASSENGER:
			color = Color.BLUE
		MapManager.CargoType.CARGO:
			color = Color.YELLOW

	# On utilise un Material unique pour ne pas changer tous les véhicules
	var mat = mesh_instance.get_active_material(0)
	if mat:
		mat = mat.duplicate()
		mat.albedo_color = color
		mesh_instance.set_surface_override_material(0, mat)

	# Mise à jour de la barre de progression (si elle existe)
	if progress_bar:
		var fill_ratio = float(current_load) / float(max_capacity)
		progress_bar.scale.x = fill_ratio
		progress_bar.visible = current_load > 0

# Appelé quand le véhicule atteint sa destination
func _on_arrival():
	is_moving = false

	if current_load > 0:
		var total_reward = current_load * reward_per_unit
		# Le gain est maintenant différé jusqu'au prochain tick quotidien
		EconomyManager.add_pending_revenue(total_reward)
		print("Véhicule arrivé ! Gain différé : ", total_reward, " pour ", current_load, " unités.")
	else:
		print("Véhicule arrivé à vide. Aucun gain.")

	# On supprime le véhicule (il ne coûte plus de maintenance)
	queue_free()

# Vérifie si le chemin est toujours valide (utilisé par MapManager si une route est supprimée)
func check_path_validity():
	for p in path:
		var grid_pos = MapManager.world_to_grid(p)
		if not MapManager.grid_data.has(grid_pos):
			# La route a été supprimée !
			_on_path_invalidated()
			return

func _on_path_invalidated():
	print("Chemin invalidé ! Arrêt du véhicule.")
	is_moving = false
	# Optionnel : essayer de recalculer un chemin
	queue_free() # Pour l'instant on le supprime simplement
