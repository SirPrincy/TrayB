extends Node3D

# Curseur de Grille
# Projette un rayon depuis la souris vers le sol et s'aimante à la grille.

@export var grid_size: float = 2.0
@export var cursor_visual: MeshInstance3D # Référence au cube plat visuel

var _camera: Camera3D
var _current_grid_pos: Vector2i
var _ghost_material: StandardMaterial3D
var _cost_label: Label3D

var _touch_start_pos: Vector2
var _is_touch_dragging: bool = false

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	if not cursor_visual:
		# Si non assigné, on cherche un enfant MeshInstance3D
		cursor_visual = find_child("MeshInstance3D")

	# Initialisation du matériau fantôme
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = Color(1, 1, 1, 0.5)

	if cursor_visual and cursor_visual.mesh:
		cursor_visual.set_surface_override_material(0, _ghost_material)

	# Initialisation du label de coût
	_cost_label = Label3D.new()
	_cost_label.pixel_size = 0.005
	_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cost_label.position = Vector3(0, 0.5, 0)
	_cost_label.font_size = 48
	_cost_label.outline_size = 12
	add_child(_cost_label)

func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = _camera.project_ray_origin(mouse_pos)
	var ray_direction = _camera.project_ray_normal(mouse_pos)

	# Intersection avec le plan horizontal (y=0)
	if ray_direction.y != 0:
		var t = -ray_origin.y / ray_direction.y
		if t > 0:
			var world_pos = ray_origin + ray_direction * t
			_update_cursor_position(world_pos)

			# Sur PC on garde le comportement "painting" (drag pour construire)
			# Sur Mobile on utilise _input pour le "Tap to build"
			if not DisplayServer.is_touchscreen_available():
				_handle_input()

func _update_cursor_position(world_pos: Vector3) -> void:
	# Calcul du snap sur la grille
	var grid_x = floor(world_pos.x / grid_size)
	var grid_z = floor(world_pos.z / grid_size)

	_current_grid_pos = Vector2i(int(grid_x), int(grid_z))

	var snapped_x = grid_x * grid_size + (grid_size / 2.0)
	var snapped_z = grid_z * grid_size + (grid_size / 2.0)

	global_position = Vector3(snapped_x, 0.05, snapped_z) # Un peu au dessus du sol pour éviter le Z-fighting
	_update_ghost_visual()

func _update_ghost_visual():
	var mode = ToolManager.current_mode
	var is_valid = true
	var cost = 0

	# Visibilité par défaut
	cursor_visual.visible = true
	_cost_label.visible = false

	match mode:
		ToolManager.ToolMode.CONSTRUIRE:
			cost = MapManager.road_cost
			is_valid = MapManager.is_valid_terrain(_current_grid_pos) and not MapManager.grid_data.has(_current_grid_pos)
			_cost_label.text = str(cost) + "$"
			_cost_label.visible = true
			if EconomyManager.balance < cost:
				is_valid = false
		ToolManager.ToolMode.SUPPRIMER:
			is_valid = MapManager.grid_data.has(_current_grid_pos) and MapManager.grid_data[_current_grid_pos] == "route"
		ToolManager.ToolMode.SELECTION_VILLE, ToolManager.ToolMode.INSPECTER:
			cursor_visual.visible = false
			return

	if is_valid:
		_ghost_material.albedo_color = Color(0, 1, 0, 0.5) # Vert
		_cost_label.modulate = Color.WHITE
	else:
		_ghost_material.albedo_color = Color(1, 0, 0, 0.5) # Rouge
		_cost_label.modulate = Color.RED

func _input(event: InputEvent) -> void:
	# Click droit (PC) ou Bouton Annuler (Mobile) pour revenir en mode inspection
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		ToolManager.set_mode(ToolManager.ToolMode.INSPECTER)
		return

	# Logique spécifique Mobile : Tap to Build
	if DisplayServer.is_touchscreen_available():
		if event is InputEventScreenTouch:
			if event.pressed:
				_touch_start_pos = event.position
				_is_touch_dragging = false
			else:
				if not _is_touch_dragging and event.position.distance_to(_touch_start_pos) < 20:
					# C'est un Tap !
					_trigger_action()

		if event is InputEventScreenDrag:
			if event.relative.length() > 5:
				_is_touch_dragging = true

func _handle_input() -> void:
	# Comportement PC (Painting)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_trigger_action()

func _trigger_action() -> void:
	var mode = ToolManager.current_mode
	match mode:
		ToolManager.ToolMode.CONSTRUIRE:
			MapManager.add_road(_current_grid_pos)
		ToolManager.ToolMode.SUPPRIMER:
			MapManager.remove_road(_current_grid_pos)
