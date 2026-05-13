extends Node

# MissionManager.gd
# Suit les statistiques globales et gère les objectifs de victoire.

signal stats_updated()
signal victory()

# Statistiques suivies
var total_transported: int = 0
var consecutive_profit_days: int = 0
var connected_cities_count: int = 0

# Objectifs à atteindre
var goal_transported: int = 100
var goal_connected_cities: int = 5
var goal_balance: int = 10000

var is_victory_achieved: bool = false

func _ready() -> void:
	EconomyManager.day_changed.connect(_on_day_changed)
	# Vérification initiale de la connectivité
	update_city_connectivity()

func _on_day_changed(_day: int) -> void:
	# Vérifier les jours de profit consécutifs
	if not EconomyManager.history.is_empty():
		var last_day = EconomyManager.history.back()
		if last_day.profit > 0:
			consecutive_profit_days += 1
		else:
			consecutive_profit_days = 0

	update_city_connectivity()
	check_goals()
	stats_updated.emit()

func add_transport_stat(amount: int) -> void:
	total_transported += amount
	check_goals()
	stats_updated.emit()

func update_city_connectivity() -> void:
	var cities = []
	for pos in MapManager.buildings_instances.keys():
		if MapManager.grid_data.get(pos) == "city":
			cities.append(pos)

	if cities.size() < 2:
		connected_cities_count = 0
		return

	var connected_count = 0
	# On considère une ville "connectée" si elle a un chemin vers au moins une autre ville
	for i in range(cities.size()):
		var start_pos = cities[i]
		var is_connected = false
		for j in range(cities.size()):
			if i == j: continue
			var path = MapManager.get_route_path(start_pos, cities[j])
			if path.size() >= 2:
				is_connected = true
				break
		if is_connected:
			connected_count += 1

	connected_cities_count = connected_count

func check_goals() -> void:
	if is_victory_achieved:
		return

	var c1 = total_transported >= goal_transported
	var c2 = connected_cities_count >= goal_connected_cities
	var c3 = EconomyManager.balance >= goal_balance

	if c1 and c2 and c3:
		is_victory_achieved = true
		victory.emit()
		print("VICTOIRE ! Tous les objectifs sont remplis.")

func get_objectives_status() -> Array[Dictionary]:
	return [
		{
			"description": "Transporter %d passagers/marchandises" % goal_transported,
			"current": total_transported,
			"goal": goal_transported,
			"completed": total_transported >= goal_transported
		},
		{
			"description": "Connecter %d villes au réseau" % goal_connected_cities,
			"current": connected_cities_count,
			"goal": goal_connected_cities,
			"completed": connected_cities_count >= goal_connected_cities
		},
		{
			"description": "Atteindre un solde de %d $" % goal_balance,
			"current": EconomyManager.balance,
			"goal": goal_balance,
			"completed": EconomyManager.balance >= goal_balance
		}
	]
