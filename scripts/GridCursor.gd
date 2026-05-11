extends Node3D

# Curseur de Grille
# Projette un rayon depuis la souris vers le sol et s'aimante à la grille.

@export var grid_size: float = 2.0
@export var cursor_visual: MeshInstance3D # Référence au cube plat visuel

var _camera: Camera3D

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	if not cursor_visual:
		# Si non assigné, on cherche un enfant MeshInstance3D
		cursor_visual = find_child("MeshInstance3D")

func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = _camera.project_ray_origin(mouse_pos)
	var ray_direction = _camera.project_ray_normal(mouse_pos)

	# Intersection avec le plan horizontal (y=0)
	# Equation du plan : P . N = d (ici N=(0,1,0) et d=0)
	# t = (d - origin . N) / (direction . N)
	if ray_direction.y != 0:
		var t = -ray_origin.y / ray_direction.y
		if t > 0:
			var world_pos = ray_origin + ray_direction * t
			_update_cursor_position(world_pos)

func _update_cursor_position(world_pos: Vector3) -> void:
	# Calcul du snap sur la grille
	var snapped_x = floor(world_pos.x / grid_size) * grid_size + (grid_size / 2.0)
	var snapped_z = floor(world_pos.z / grid_size) * grid_size + (grid_size / 2.0)

	global_position = Vector3(snapped_x, 0.05, snapped_z) # Un peu au dessus du sol pour éviter le Z-fighting
