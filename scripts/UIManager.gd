extends Control

# UIManager.gd
# Gère l'affichage des informations économiques, temporelles et des missions.

var money_label: Label
var pending_revenue_label: Label
var maintenance_label: Label
var active_vehicles_label: Label
var date_label: Label
var speed_label: Label

# Toolbar buttons
var build_btn: Button
var delete_btn: Button
var select_btn: Button
var inspect_btn: Button
var cancel_btn: Button # Mobile only
var open_lines_btn: Button

# Time buttons (Mobile only)
var pause_btn: Button
var speed1_btn: Button
var speed2_btn: Button
var speed4_btn: Button

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

var objectives_panel: Control
var goal_list: Control

@onready var victory_panel = $VictoryPanel
@onready var continue_victory_btn = $VictoryPanel/VBoxContainer/ContinueVictoryButton

# Line Management Panel (Assumed to be added in UI scene)
@onready var lines_panel = $LinesPanel
@onready var lines_list = $LinesPanel/VBoxContainer/ScrollContainer/LinesList
@onready var close_lines_btn = $LinesPanel/VBoxContainer/CloseLinesButton

var _current_origin_city = null
var _last_balance = 0
var _is_mobile = false

func _ready() -> void:
	_detect_platform()
	_setup_ui_references()
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
	if cancel_btn:
		cancel_btn.pressed.connect(func(): ToolManager.set_mode(ToolManager.ToolMode.INSPECTER))

	if open_lines_btn:
		open_lines_btn.pressed.connect(show_lines_panel)

	# Time buttons (Mobile)
	if pause_btn: pause_btn.pressed.connect(func(): TimeManager.toggle_pause())
	if speed1_btn: speed1_btn.pressed.connect(func(): TimeManager.set_speed(1.0))
	if speed2_btn: speed2_btn.pressed.connect(func(): TimeManager.set_speed(2.0))
	if speed4_btn: speed4_btn.pressed.connect(func(): TimeManager.set_speed(4.0))

	close_dest_btn.pressed.connect(func(): dest_panel.hide())
	close_report_btn.pressed.connect(func(): daily_report_panel.hide())
	if close_lines_btn:
		close_lines_btn.pressed.connect(func(): lines_panel.hide())
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	continue_victory_btn.pressed.connect(func(): victory_panel.hide())

	# Connexion LineManager
	LineManager.lines_updated.connect(_update_lines_list)

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
		label.text = "Aucune destination possible"
		city_list.add_child(label)
	else:
		for city_info in reachable_cities:
			var btn = Button.new()
			var dist = city_info.path.size() * MapManager.grid_size
			var revenue = int(dist * 2.0)
			var time = int(dist / 5.0)

			var btn_text = "%s\n" % city_info.name
			if not city_info.connected:
				btn_text += "[NON CONNECTÉ - Coût: %d$]\n" % city_info.construction_cost

			btn_text += "Revenu: %d$ | Temps: %ds" % [revenue, time]
			btn.text = btn_text

			if not city_info.connected and EconomyManager.balance < city_info.construction_cost:
				btn.disabled = true
				btn.modulate = Color(1, 0.5, 0.5)

			btn.pressed.connect(_on_destination_selected.bind(city_info))
			city_list.add_child(btn)

	dest_panel.show()

func _on_destination_selected(city_info):
	if _current_origin_city:
		# Si non connecté, on construit la route d'abord
		if not city_info.connected:
			if MapManager.build_road_network(city_info.grid_path):
				show_notification("Route construite vers " + city_info.name)
			else:
				# Normalement désactivé si pas de fonds, mais sécurité
				show_notification("Échec de la construction !")
				return

		# Au lieu de spawn direct, on propose de créer une ligne ou un trajet simple
		# Pour simplifier ici, on crée une ligne
		if LineManager.create_line(_current_origin_city, MapManager.buildings_instances[city_info.pos]):
			show_notification("Ligne créée : " + _current_origin_city.city_name + " - " + city_info.name)
			show_lines_panel()
		else:
			# Si la ligne existe déjà, on l'ouvre
			show_lines_panel()

	dest_panel.hide()
	ToolManager.set_mode(ToolManager.ToolMode.INSPECTER)

func show_lines_panel():
	_update_lines_list()
	lines_panel.show()

func _update_lines_list():
	if not lines_list: return

	for child in lines_list.get_children():
		child.queue_free()

	for line_id in LineManager.lines:
		var line = LineManager.lines[line_id]
		var container = HBoxContainer.new()

		var label = Label.new()
		label.text = "%s | Freq: %.1f/m | Véhicules: %d | Profit: %d$" % [line.id, line.frequency, line.vehicles.size(), line.daily_profit]
		label.custom_minimum_size.x = 350
		container.add_child(label)

		var add_v = Button.new()
		add_v.text = "+"
		add_v.custom_minimum_size = Vector2(40, 40) if not _is_mobile else Vector2(60, 60)
		add_v.pressed.connect(func(): LineManager.add_vehicle_to_line(line_id))
		container.add_child(add_v)

		var rem_v = Button.new()
		rem_v.text = "-"
		rem_v.custom_minimum_size = Vector2(40, 40) if not _is_mobile else Vector2(60, 60)
		rem_v.pressed.connect(func(): LineManager.remove_vehicle_from_line(line_id))
		container.add_child(rem_v)

		var close_l = Button.new()
		close_l.text = "Fermer"
		close_l.custom_minimum_size = Vector2(80, 40) if not _is_mobile else Vector2(100, 60)
		close_l.pressed.connect(func(): LineManager.close_line(line_id))
		container.add_child(close_l)

		lines_list.add_child(container)

func _detect_platform():
	# On peut forcer avec une feature tag ou vérifier la présence d'écran tactile
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_is_mobile = true
	else:
		_is_mobile = false

	$PCUI.visible = not _is_mobile
	$MobileUI.visible = _is_mobile

func _setup_ui_references():
	var root = "MobileUI" if _is_mobile else "PCUI"

	money_label = get_node(root + "/HUD/VBoxContainer/MoneyLabel")
	pending_revenue_label = get_node(root + "/HUD/VBoxContainer/PendingRevenueLabel")
	maintenance_label = get_node(root + "/HUD/VBoxContainer/MaintenanceLabel")
	active_vehicles_label = get_node(root + "/HUD/VBoxContainer/ActiveVehiclesLabel")
	date_label = get_node(root + "/HUD/VBoxContainer/DateLabel")
	speed_label = get_node(root + "/HUD/VBoxContainer/GameSpeedLabel")

	build_btn = get_node(root + "/Toolbar/HBoxContainer/BuildButton")
	delete_btn = get_node(root + "/Toolbar/HBoxContainer/DeleteButton")
	select_btn = get_node(root + "/Toolbar/HBoxContainer/SelectButton")
	inspect_btn = get_node(root + "/Toolbar/HBoxContainer/InspectButton")
	open_lines_btn = get_node(root + "/Toolbar/HBoxContainer/LinesButton")

	if _is_mobile:
		cancel_btn = get_node(root + "/Toolbar/HBoxContainer/CancelButton")
		pause_btn = get_node(root + "/TimeControls/HBoxContainer/PauseButton")
		speed1_btn = get_node(root + "/TimeControls/HBoxContainer/Speed1Button")
		speed2_btn = get_node(root + "/TimeControls/HBoxContainer/Speed2Button")
		speed4_btn = get_node(root + "/TimeControls/HBoxContainer/Speed4Button")

	objectives_panel = get_node(root + "/ObjectivesPanel")
	goal_list = get_node(root + "/ObjectivesPanel/VBoxContainer/GoalList")
