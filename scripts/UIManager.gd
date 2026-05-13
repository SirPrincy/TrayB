extends Control

# UIManager.gd
# Gère l'affichage des informations économiques et temporelles à l'écran.

@onready var money_label: Label = $HUD/VBoxContainer/MoneyLabel
@onready var date_label: Label = $HUD/VBoxContainer/DateLabel

# Toolbar buttons
@onready var build_btn = $Toolbar/HBoxContainer/BuildButton
@onready var delete_btn = $Toolbar/HBoxContainer/DeleteButton
@onready var select_btn = $Toolbar/HBoxContainer/SelectButton
@onready var inspect_btn = $Toolbar/HBoxContainer/InspectButton

# Destination Panel
@onready var dest_panel = $DestinationPanel
@onready var city_list = $DestinationPanel/VBoxContainer/ScrollContainer/CityList
@onready var close_dest_btn = $DestinationPanel/VBoxContainer/CloseButton

var _current_origin_city = null

func _ready() -> void:
	# Connexion aux signaux de l'EconomyManager pour mettre à jour l'UI
	EconomyManager.balance_changed.connect(_on_balance_changed)
	EconomyManager.day_changed.connect(_on_day_changed)

	# Initialisation de l'affichage avec les valeurs actuelles
	_update_money_display(EconomyManager.balance)
	_update_date_display(EconomyManager.current_day)

	# Connexion des boutons de la toolbar
	build_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.CONSTRUIRE))
	delete_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.SUPPRIMER))
	select_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.SELECTION_VILLE))
	inspect_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.INSPECTER))

	close_dest_btn.pressed.connect(func(): dest_panel.hide())

func _on_balance_changed(new_balance: int) -> void:
	_update_money_display(new_balance)

func _on_day_changed(new_day: int) -> void:
	_update_date_display(new_day)

func _update_money_display(amount: int) -> void:
	money_label.text = "Argent: " + str(amount) + " $"

func _update_date_display(day: int) -> void:
	date_label.text = "Jour " + str(day)

func show_destination_panel(origin_city):
	_current_origin_city = origin_city
	# Nettoyer la liste
	for child in city_list.get_children():
		child.queue_free()

	var reachable_cities = origin_city.get_reachable_cities()

	if reachable_cities.is_empty():
		var label = Label.new()
		label.text = "Aucune ville connectée"
		city_list.add_child(label)
	else:
		for city_info in reachable_cities:
			var btn = Button.new()
			var dist = city_info.path.size() * MapManager.grid_size
			var revenue = int(dist * 2.0) # Formule simple de revenu estimé
			var time = int(dist / 5.0) # Formule simple de temps estimé

			btn.text = "%s\nRevenu: %d$ | Temps: %ds" % [city_info.name, revenue, time]
			btn.pressed.connect(_on_destination_selected.bind(city_info))
			city_list.add_child(btn)

	dest_panel.show()

func _on_destination_selected(city_info):
	if _current_origin_city:
		_current_origin_city.spawn_vehicle_to(city_info.path)
	dest_panel.hide()
	ToolManager.set_mode(ToolManager.ToolMode.INSPECTER)
