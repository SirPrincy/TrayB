extends Camera3D

# Caméra RTS 3D
# Gère les déplacements ZQSD, le zoom et la rotation.

@export_group("Déplacement")
@export var move_speed: float = 20.0
@export var acceleration: float = 10.0

@export_group("Zoom")
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 50.0

@export_group("Rotation")
@export var rotation_speed: float = 2.0

var _target_position: Vector3 # Position du pivot au sol
var _target_zoom: float = 20.0
var _target_rotation: float = 0.0

func _ready() -> void:
	# On initialise la position cible au sol (projection du point de vue initial)
	_target_position = global_position
	_target_position.y = 0
	_target_rotation = rotation.y

	# Inclinaison fixe vers le sol
	rotation_degrees.x = -45

func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_rotation(delta)

func _input(event: InputEvent) -> void:
	# Zoom avec la molette
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = max(min_zoom, _target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = min(max_zoom, _target_zoom + zoom_speed)

	# Rotation avec le bouton central
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_target_rotation -= event.relative.x * 0.01

func _handle_rotation(delta: float) -> void:
	# Rotation fluide
	rotation.y = lerp_angle(rotation.y, _target_rotation, acceleration * delta)

func _handle_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO

	# Mouvements ZQSD / WASD
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1

	input_dir = input_dir.normalized()

	# Calcul des directions par rapport à la rotation actuelle
	var forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	var right = Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	var move_dir = (forward * input_dir.y + right * input_dir.x)

	# Mise à jour de la position cible du pivot au sol
	_target_position += move_dir * move_speed * delta

	# Calcul de la position réelle de la caméra par rapport au pivot
	# On recule sur l'axe Z local (après rotation) et on monte sur l'axe Y
	# Pour un angle de 45°, reculer de _target_zoom et monter de _target_zoom
	# permet de rester focalisé sur le point _target_position au sol.
	var offset = Vector3(0, _target_zoom, _target_zoom).rotated(Vector3.UP, rotation.y)
	var desired_cam_pos = _target_position + offset

	global_position = global_position.lerp(desired_cam_pos, acceleration * delta)
