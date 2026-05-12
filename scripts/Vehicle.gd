extends Node3D

# Vehicle.gd
# Gère le déplacement fluide du véhicule sur la grille via le chemin A*.

@export var speed: float = 5.0
@export var reward: int = 100

var path: Array[Vector3] = []
var target_index: int = 0
var is_moving: bool = false

func _ready() -> void:
	# On s'assure que le véhicule est bien au-dessus du sol
	position.y = 0.5
	MapManager.road_removed.connect(_on_road_removed_globally)

func _on_road_removed_globally(_grid_pos: Vector2i):
	check_path_validity()

func _process(delta: float) -> void:
	if not is_moving or target_index >= path.size():
		return

	# Intégration du speed_factor du TimeManager
	# Note: Engine.time_scale gère déjà delta si on utilise delta normalement,
	# mais il est bon de vérifier si on veut un comportement spécifique.
	# Ici, delta est déjà affecté par Engine.time_scale.

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
	is_moving = true

# Appelé quand le véhicule atteint sa destination
func _on_arrival():
	is_moving = false
	EconomyManager.add_money(reward)
	print("Véhicule arrivé ! Gain : ", reward)
	# On peut supprimer le véhicule ou le renvoyer au dépôt
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
