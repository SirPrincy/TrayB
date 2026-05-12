extends Control

# UIManager.gd
# Gère l'affichage des informations économiques et temporelles à l'écran.

@onready var money_label: Label = $MarginContainer/VBoxContainer/MoneyLabel
@onready var date_label: Label = $MarginContainer/VBoxContainer/DateLabel

func _ready() -> void:
	# Connexion aux signaux de l'EconomyManager pour mettre à jour l'UI
	EconomyManager.balance_changed.connect(_on_balance_changed)
	EconomyManager.day_changed.connect(_on_day_changed)

	# Initialisation de l'affichage avec les valeurs actuelles
	_update_money_display(EconomyManager.balance)
	_update_date_display(EconomyManager.current_day)

func _on_balance_changed(new_balance: int) -> void:
	_update_money_display(new_balance)

func _on_day_changed(new_day: int) -> void:
	_update_date_display(new_day)

func _update_money_display(amount: int) -> void:
	money_label.text = "Argent: " + str(amount) + " $"

func _update_date_display(day: int) -> void:
	date_label.text = "Jour " + str(day)
