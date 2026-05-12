extends Node

# EconomyManager.gd
# Gère l'économie du jeu : solde, revenus et dépenses.

signal balance_changed(new_balance: int)

@export var balance: int = 1000:
	set(value):
		balance = value
		balance_changed.emit(balance)
		print("Nouveau solde : ", balance)

func _ready() -> void:
	print("EconomyManager prêt. Solde initial : ", balance)

# Ajoute de l'argent au solde
func add_money(amount: int) -> void:
	balance += amount

# Dépense de l'argent si le solde est suffisant
func spend_money(amount: int) -> bool:
	if balance >= amount:
		balance -= amount
		return true
	else:
		print("Fonds insuffisants !")
		return false
