extends Node

# Gestionnaire de temps (Autoload)
# Permet de contrôler la vitesse du jeu (pause, normal, rapide, très rapide)

signal speed_changed(new_speed: float)

@export var speed_factor: float = 1.0:
	set(value):
		speed_factor = value
		Engine.time_scale = speed_factor
		speed_changed.emit(speed_factor)

var _previous_speed: float = 1.0

func _ready() -> void:
	# Initialise l'échelle de temps du moteur
	Engine.time_scale = speed_factor

func set_speed(new_speed: float) -> void:
	speed_factor = new_speed

func toggle_pause() -> void:
	if speed_factor > 0:
		_previous_speed = speed_factor
		speed_factor = 0.0
	else:
		speed_factor = _previous_speed

func _input(event: InputEvent) -> void:
	# Raccourcis clavier pour le contrôle du temps
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("space"): # Espace pour pause (ui_accept par défaut est souvent espace/entrée)
		toggle_pause()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				set_speed(1.0)
			KEY_2:
				set_speed(2.0)
			KEY_3:
				set_speed(4.0)
