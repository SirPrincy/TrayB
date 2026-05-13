extends Camera3D

# Caméra RTS 3D
# Gère les déplacements ZQSD, le zoom et la rotation.

@export_group("Déplacement")
@export var move_speed: float = 20.0
@export var acceleration: float = 10.0
@export var edge_margin: int = 20
@export var use_edge_panning: bool = true

@export_group("Zoom")
@export var zoom_speed: float = 5.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 60.0
@export var smooth_zoom_speed: float = 10.0

@export_group("Rotation")
@export var rotation_speed: float = 2.0
@export var tilt_angle_min: float = -60.0 # Angle quand on est proche
@export var tilt_angle_max: float = -30.0 # Angle quand on est loin

var _target_position: Vector3 # Position du pivot au sol
var _target_zoom: float = 30.0
var _target_rotation: float = 0.0
var _current_zoom: float = 30.0
var _touch_positions = {}

func _ready() -> void:
	# On initialise la position cible au sol
	_target_position = global_position
	_target_position.y = 0
	_target_rotation = rotation.y
	_current_zoom = _target_zoom

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_rotation(delta)
	_update_camera_transform(delta)

func _input(event: InputEvent) -> void:
	# Zoom avec la molette
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = max(min_zoom, _target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = min(max_zoom, _target_zoom + zoom_speed)

	# Rotation et Drag Souris
	if event is InputEventMouseMotion:
		# Rotation avec le bouton central
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_target_rotation -= event.relative.x * 0.005

		# Déplacement par "drag" avec le bouton droit
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var drag_speed = _current_zoom * 0.001
			var drag_dir = Vector3(-event.relative.x, 0, -event.relative.y).rotated(Vector3.UP, rotation.y)
			_target_position += drag_dir * drag_speed * 100 * get_process_delta_time()

	# Support Tactile
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
		else:
			_touch_positions.erase(event.index)

	if event is InputEventScreenDrag:
		_touch_positions[event.index] = event.position

		if _touch_positions.size() == 1:
			# Panoramique à un doigt
			var drag_speed = _current_zoom * 0.001
			var drag_dir = Vector3(-event.relative.x, 0, -event.relative.y).rotated(Vector3.UP, rotation.y)
			_target_position += drag_dir * drag_speed * 100 * get_process_delta_time()

		elif _touch_positions.size() == 2:
			# Pinch-to-zoom et Rotation à deux doigts
			var indices = _touch_positions.keys()
			var p1 = _touch_positions[indices[0]]
			var p2 = _touch_positions[indices[1]]

			var prev_p1 = p1
			var prev_p2 = p2

			if event.index == indices[0]:
				prev_p1 = p1 - event.relative
			else:
				prev_p2 = p2 - event.relative

			# Zoom
			var old_dist = prev_p1.distance_to(prev_p2)
			var new_dist = p1.distance_to(p2)
			if old_dist > 0:
				var ratio = new_dist / old_dist
				_target_zoom = clamp(_target_zoom / ratio, min_zoom, max_zoom)

			# Rotation
			var old_dir = (prev_p2 - prev_p1).angle()
			var new_dir = (p2 - p1).angle()
			_target_rotation -= wrapf(new_dir - old_dir, -PI, PI)

func _handle_rotation(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_rotation, acceleration * delta)

func _handle_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO

	# Touches ZQSD / WASD
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1

	# Edge panning
	if use_edge_panning:
		var mouse_pos = get_viewport().get_mouse_position()
		var screen_size = get_viewport().get_visible_rect().size
		if mouse_pos.x < edge_margin: input_dir.x -= 1
		if mouse_pos.x > screen_size.x - edge_margin: input_dir.x += 1
		if mouse_pos.y < edge_margin: input_dir.y -= 1
		if mouse_pos.y > screen_size.y - edge_margin: input_dir.y += 1

	input_dir = input_dir.normalized()

	# Vitesse adaptée au zoom (plus on est haut, plus on va vite)
	var speed_multiplier = lerp(1.0, 3.0, (_current_zoom - min_zoom) / (max_zoom - min_zoom))

	var forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var right = Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	var move_dir = (forward * input_dir.y + right * input_dir.x)

	_target_position += move_dir * move_speed * speed_multiplier * delta

func _update_camera_transform(delta: float) -> void:
	# Zoom fluide
	_current_zoom = lerp(_current_zoom, _target_zoom, smooth_zoom_speed * delta)

	# Calcul de l'inclinaison dynamique (Tilt)
	var zoom_percent = (_current_zoom - min_zoom) / (max_zoom - min_zoom)
	var current_tilt = lerp(tilt_angle_min, tilt_angle_max, zoom_percent)
	rotation.x = lerp_angle(rotation.x, deg_to_rad(current_tilt), acceleration * delta)

	# Calcul de la position par rapport au pivot au sol
	# On utilise la trigonométrie pour garder le point cible au centre
	var tilt_rad = rotation.x
	var dist_z = _current_zoom * cos(tilt_rad)
	var dist_y = _current_zoom * -sin(tilt_rad) # rotation.x est négative

	var offset = Vector3(0, dist_y, dist_z).rotated(Vector3.UP, rotation.y)
	var desired_cam_pos = _target_position + offset

	global_position = global_position.lerp(desired_cam_pos, acceleration * delta)
