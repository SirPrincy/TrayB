extends Control

# UIManager.gd
# Gère l'affichage des informations économiques, temporelles et des missions.

@onready var money_label: Label = $HUD/VBoxContainer/MoneyLabel
@onready var pending_revenue_label: Label = $HUD/VBoxContainer/PendingRevenueLabel
@onready var maintenance_label: Label = $HUD/VBoxContainer/MaintenanceLabel
@onready var active_vehicles_label: Label = $HUD/VBoxContainer/ActiveVehiclesLabel
@onready var date_label: Label = $HUD/VBoxContainer/DateLabel
@onready var speed_label: Label = $HUD/VBoxContainer/GameSpeedLabel

# Toolbar buttons
@onready var build_btn = $Toolbar/HBoxContainer/BuildButton
@onready var delete_btn = $Toolbar/HBoxContainer/DeleteButton
@onready var select_btn = $Toolbar/HBoxContainer/SelectButton
@onready var inspect_btn = $Toolbar/HBoxContainer/InspectButton

# Destination Panel
@onready var dest_panel = $DestinationPanel
@onready var city_list = $DestinationPanel/VBoxContainer/ScrollContainer/CityList
@onready var close_dest_btn = $DestinationPanel/VBoxContainer/CloseButton

# Notification
@onready var notification_container = $NotificationContainer

# Modals
@onready var daily_report_panel = $DailyReportPanel
@onready var report_stats = $DailyReportPanel/VBoxContainer/Stats
@onready var report_history_list = $DailyReportPanel/VBoxContainer/HistoryList
@onready var close_report_btn = $DailyReportPanel/VBoxContainer/CloseReportButton

@onready var game_over_panel = $GameOverPanel
@onready var game_over_reason = $GameOverPanel/VBoxContainer/Reason
@onready var restart_btn = $GameOverPanel/VBoxContainer/RestartButton

@onready var objectives_panel = $ObjectivesPanel
@onready var goal_list = $ObjectivesPanel/VBoxContainer/GoalList

@onready var victory_panel = $VictoryPanel
@onready var continue_victory_btn = $VictoryPanel/VBoxContainer/ContinueVictoryButton

var _current_origin_city = null
var _last_balance = 0

func _ready() -> void:
	# Connexions EconomyManager
	EconomyManager.balance_changed.connect(_on_balance_changed)
	EconomyManager.day_changed.connect(_on_day_changed)
	EconomyManager.game_over.connect(_on_game_over)

	# Connexions TimeManager
	TimeManager.speed_changed.connect(_on_speed_changed)

	# Connexions MissionManager
	MissionManager.stats_updated.connect(_update_objectives)
	MissionManager.victory.connect(_on_victory)

	# Initialisation
	_last_balance = EconomyManager.balance
	_update_hud()
	_update_objectives()

	# Toolbar buttons
	build_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.CONSTRUIRE))
	delete_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.SUPPRIMER))
	select_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.SELECTION_VILLE))
	inspect_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.INSPECTER))

	close_dest_btn.pressed.connect(func(): dest_panel.hide())
	close_report_btn.pressed.connect(func(): daily_report_panel.hide())
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	continue_victory_btn.pressed.connect(func(): victory_panel.hide())

func _process(_delta: float) -> void:
	# Mise à jour des infos qui changent souvent (véhicules, revenus en attente)
	_update_dynamic_hud()

func _on_balance_changed(new_balance: int) -> void:
	var diff = new_balance - _last_balance
	if diff > 0:
		_animate_money_color(Color.GREEN)
	elif diff < 0:
		_animate_money_color(Color.RED)

	_last_balance = new_balance
	_update_hud()
	_update_objectives()

func _on_day_changed(new_day: int) -> void:
	_update_hud()
	_show_daily_report()

func _on_speed_changed(new_speed: float) -> void:
	_update_speed_display(new_speed)

func _on_game_over(reason: String) -> void:
	game_over_reason.text = reason
	game_over_panel.show()
	TimeManager.set_speed(0)

func _on_victory() -> void:
	victory_panel.show()

func _update_hud() -> void:
	money_label.text = "Argent: %d $" % EconomyManager.balance
	date_label.text = "Jour %d" % EconomyManager.current_day
	_update_speed_display(TimeManager.speed_factor)
	_update_dynamic_hud()

func _update_dynamic_hud() -> void:
	pending_revenue_label.text = "Revenus en attente: %d $" % EconomyManager.pending_revenue

	var total_maintenance = 0
	var vehicles = get_tree().get_nodes_in_group("vehicles")
	for v in vehicles:
		total_maintenance += v.maintenance_cost
	maintenance_label.text = "Maintenance jour: %d $" % total_maintenance
	active_vehicles_label.text = "Véhicules actifs: %d" % vehicles.size()

func _update_speed_display(speed: float) -> void:
	var text = "Vitesse: "
	if speed == 0: text += "PAUSE"
	else: text += "x%g" % speed
	speed_label.text = text

func _animate_money_color(color: Color) -> void:
	money_label.add_theme_color_override("font_color", color)
	get_tree().create_timer(0.5).timeout.connect(func():
		money_label.remove_theme_color_override("font_color")
	)

func show_notification(message: String) -> void:
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_font_size_override("font_size", 18)
	notification_container.add_child(label)

	# Animation simple de montée et disparition
	var tween = get_tree().create_tween()
	tween.tween_property(label, "position:y", -50.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(func(): label.queue_free())

func _show_daily_report() -> void:
	if EconomyManager.history.is_empty(): return

	var last = EconomyManager.history.back()
	report_stats.text = "Revenu: %d$\nMaintenance: %d$\nBénéfice Net: %d$\nSolde Final: %d$" % [
		last.revenue, last.maintenance, last.profit, last.balance_after
	]

	# Vider la liste
	for child in report_history_list.get_children():
		child.queue_free()

	# Remplir l'historique (du plus récent au plus ancien)
	var hist = EconomyManager.history.duplicate()
	hist.reverse()
	for entry in hist:
		var l = Label.new()
		var color_str = "green" if entry.profit >= 0 else "red"
		l.text = "Jour %d: %+d$" % [entry.day, entry.profit]
		l.modulate = Color.GREEN if entry.profit >= 0 else Color.RED
		report_history_list.add_child(l)

	daily_report_panel.show()

func _update_objectives() -> void:
	for child in goal_list.get_children():
		child.queue_free()

	var objectives = MissionManager.get_objectives_status()
	for obj in objectives:
		var l = Label.new()
		var status = "✅" if obj.completed else "❌"
		l.text = "%s %s (%d/%d)" % [status, obj.description, obj.current, obj.goal]
		if obj.completed:
			l.modulate = Color.GREEN
		goal_list.add_child(l)

func show_destination_panel(origin_city):
	_current_origin_city = origin_city
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
			var revenue = int(dist * 2.0)
			var time = int(dist / 5.0)

			btn.text = "%s\nRevenu: %d$ | Temps: %ds" % [city_info.name, revenue, time]
			btn.pressed.connect(_on_destination_selected.bind(city_info))
			city_list.add_child(btn)

	dest_panel.show()

func _on_destination_selected(city_info):
	if _current_origin_city:
		_current_origin_city.spawn_vehicle_to(city_info.path)
	dest_panel.hide()
	ToolManager.set_mode(ToolManager.ToolMode.INSPECTER)
