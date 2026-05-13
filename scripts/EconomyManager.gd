extends Node

# EconomyManager.gd
# Gère l'économie du jeu : solde, revenus et dépenses.
# Gère également le Tick System pour les revenus/coûts quotidiens.

signal balance_changed(new_balance: int)
signal game_tick()
signal day_changed(day: int)
signal game_over(reason: String)

@export var balance: int = 1000:
	set(value):
		balance = value
		balance_changed.emit(balance)
		# print("Nouveau solde : ", balance)

@export var day_duration: float = 5.0 # Durée d'un jour en secondes (vitesse x1)
var current_day: int = 1
var time_accumulator: float = 0.0
var pending_revenue: int = 0
var history: Array[Dictionary] = []
var bankruptcy_days: int = 0

func _ready() -> void:
	print("EconomyManager prêt. Solde initial : ", balance)

func _process(delta: float) -> void:
	# Accumulation du temps (Engine.time_scale est déjà pris en compte dans delta)
	time_accumulator += delta

	# Utilisation d'une boucle while pour éviter le drift si plusieurs jours passent
	while time_accumulator >= day_duration:
		_process_day_tick()

# Traitement du passage d'une journée
func _process_day_tick() -> void:
	time_accumulator -= day_duration

	# Calcul de la maintenance des véhicules
	var total_maintenance = 0
	var tree = get_tree()
	if tree:
		var vehicles = tree.get_nodes_in_group("vehicles")
		for vehicle in vehicles:
			if "maintenance_cost" in vehicle:
				total_maintenance += vehicle.maintenance_cost

	# Sauvegarde des stats du jour avant mise à jour du solde
	var daily_stats = {
		"day": current_day,
		"revenue": pending_revenue,
		"maintenance": total_maintenance,
		"profit": pending_revenue - total_maintenance,
		"balance_after": balance + (pending_revenue - total_maintenance)
	}
	history.append(daily_stats)
	if history.size() > 7:
		history.remove_at(0)

	# Mise à jour du solde : revenus accumulés moins maintenance
	var net_change = pending_revenue - total_maintenance
	self.balance += net_change

	# Logique de faillite
	if balance < 0:
		bankruptcy_days += 1
		if bankruptcy_days >= 3:
			game_over.emit("Faillite : Solde négatif pendant 3 jours consécutifs.")
	else:
		bankruptcy_days = 0

	# Réinitialisation des revenus pour le jour suivant
	pending_revenue = 0

	# Passage au jour suivant
	current_day += 1

	# Émission des signaux
	game_tick.emit()
	day_changed.emit(current_day)

	print("Jour ", current_day - 1, " terminé. Maintenance: ", total_maintenance, " Net: ", net_change)

# Ajoute des revenus qui seront perçus au prochain tick
func add_pending_revenue(amount: int) -> void:
	pending_revenue += amount

# Ajoute de l'argent au solde immédiatement
func add_money(amount: int) -> void:
	# Utilisation de self.balance pour déclencher le setter
	self.balance += amount

# Dépense de l'argent si le solde est suffisant
func spend_money(amount: int) -> bool:
	if balance >= amount:
		# Utilisation de self.balance pour déclencher le setter
		self.balance -= amount
		return true
	else:
		print("Fonds insuffisants !")
		return false
