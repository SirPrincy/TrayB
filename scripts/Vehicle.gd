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

# Système de ligne
var assigned_line = null
var current_destination_name: String = ""
var is_returning: bool = false # Pour savoir si on va vers A ou vers B

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

# Définit la destination pour un trajet simple
func set_line_destination(dest_name: String):
	current_destination_name = dest_name

# Assigne le véhicule à une ligne régulière
func assign_to_line(line):
	assigned_line = line
	is_returning = false
	current_destination_name = line.dest_name
	set_path(line.path)

# Désassigne le véhicule
func unassign():
	assigned_line = null
	enter_garage()

# Tente de charger du stock depuis un bâtiment à la position actuelle
func try_load():
	var grid_pos = MapManager.world_to_grid(position)
	if MapManager.buildings_instances.has(grid_pos):
		var building = MapManager.buildings_instances[grid_pos]

		# Si on a une destination spécifique, on utilise take_targeted_stock
		if current_destination_name != "" and building.has_method("take_targeted_stock"):
			self.load_type = MapManager.CargoType.PASSENGER # Par défaut pour le ciblé
			self.current_load = building.take_targeted_stock(current_destination_name, max_capacity)
		elif building.has_method("take_stock"):
			self.load_type = building.stock_type
			self.current_load = building.take_stock(max_capacity)

		if current_load > 0:
			print("Véhicule chargé : ", current_load, " pour ", current_destination_name)

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

	var revenue = 0
	if current_load > 0:
		# Calcul de la distance totale parcourue
		var total_distance = 0.0
		for i in range(path.size() - 1):
			total_distance += path[i].distance_to(path[i+1])

		var distance_factor = total_distance / MapManager.grid_size
		revenue = int(current_load * reward_per_unit * (1.0 + distance_factor * 0.1))

		EconomyManager.add_pending_revenue(revenue)
		MissionManager.add_transport_stat(current_load)

		if assigned_line:
			LineManager.register_profit(assigned_line.id, revenue)

		print("Véhicule arrivé ! Gain : ", revenue, " pour ", current_load, " à ", current_destination_name)

	# Déchargement
	current_load = 0

	if assigned_line:
		# Faire le trajet inverse
		is_returning = !is_returning
		current_destination_name = assigned_line.origin_name if is_returning else assigned_line.dest_name

		var new_path = assigned_line.path.duplicate()
		if is_returning:
			new_path.reverse()

		# Petit délai avant de repartir pour simuler le temps de chargement/déchargement
		await get_tree().create_timer(1.0).timeout
		if assigned_line: # Vérifier s'il est toujours assigné
			set_path(new_path)
	else:
		# Retour au garage (pool)
		enter_garage()

func enter_garage():
	hide()
	is_moving = false
	current_load = 0
	load_type = MapManager.CargoType.NONE
	assigned_line = null
	current_destination_name = ""
	# On garde le véhicule dans le groupe vehicles mais il est caché
	# Il faut s'assurer que EconomyManager ne compte pas les véhicules cachés dans la maintenance si on veut être strict
	# Mais ici on va dire qu'au garage ils ne coûtent rien.

func exit_garage():
	show()
	# Réinitialisation si nécessaire

# Vérifie si le chemin est toujours valide (utilisé par MapManager si une route est supprimée)
func check_path_validity():
	for p in path:
		var grid_pos = MapManager.world_to_grid(p)
		if not MapManager.grid_data.has(grid_pos):
			# La route a été supprimée !
			_on_path_invalidated()
			return

func _on_path_invalidated():
	print("Chemin invalidé pour véhicule à ", position)
	# Recalcul de chemin si possible
	var grid_pos = MapManager.world_to_grid(position)
	var dest_grid = Vector2i.ZERO

	if assigned_line:
		dest_grid = assigned_line.origin_pos if is_returning else assigned_line.dest_pos
	elif current_destination_name != "":
		# Trouver la position de la destination par son nom
		for pos in MapManager.buildings_instances.keys():
			var b = MapManager.buildings_instances[pos]
			if b.has_method("is_city") and b.city_name == current_destination_name:
				dest_grid = pos
				break

	if dest_grid != Vector2i.ZERO:
		var new_path = MapManager.get_route_path(grid_pos, dest_grid)
		if new_path.size() >= 2:
			print("Recalcul réussi.")
			path = new_path
			target_index = 1
			return

	print("Impossible de recalculer. Retour au garage.")
	enter_garage()
