extends Node3D

# MapInitializer.gd
# Initialise la carte de Madagascar avec ses principales villes.

@export var city_scene = preload("res://City.tscn")

# Liste des principales villes de Madagascar avec leurs positions approximatives (coordonnées de grille)
# On centre Antananarivo à (0,0)
var cities_data = [
	{"name": "Antananarivo", "pos": Vector2i(0, 0), "pop": 1300000},
	{"name": "Toamasina", "pos": Vector2i(10, -1), "pop": 325000},
	{"name": "Mahajanga", "pos": Vector2i(-5, -12), "pop": 245000},
	{"name": "Toliara", "pos": Vector2i(-12, 15), "pop": 170000},
	{"name": "Antsiranana", "pos": Vector2i(5, -25), "pop": 130000},
	{"name": "Fianarantsoa", "pos": Vector2i(-1, 8), "pop": 190000},
	{"name": "Antsirabe", "pos": Vector2i(-1, 3), "pop": 250000}
]

func _ready() -> void:
	# Attendre un peu que les autoloads soient prêts
	call_deferred("_spawn_cities")

func _spawn_cities():
	for data in cities_data:
		var city = city_scene.instantiate()
		city.city_name = data["name"]
		city.population = data["pop"]
		add_child(city)
		city.position = MapManager.grid_to_world(data["pos"])
		print("Ville placée : ", data["name"], " à ", data["pos"])
