extends Control

const CELL_SIZE := 24
const VILLAGER_SCENE = preload("res://scenes/villager.tscn")
const TREE_SPOTS: Array[Vector2] = [
	Vector2(0.08, 0.05), Vector2(0.2, 0.04), Vector2(0.34, 0.06),
	Vector2(0.5, 0.04), Vector2(0.66, 0.06), Vector2(0.81, 0.04),
	Vector2(0.93, 0.06), Vector2(0.06, 0.3), Vector2(0.94, 0.27),
	Vector2(0.07, 0.56), Vector2(0.93, 0.56), Vector2(0.1, 0.83),
	Vector2(0.26, 0.94), Vector2(0.43, 0.92), Vector2(0.62, 0.95),
	Vector2(0.79, 0.92), Vector2(0.91, 0.84)
]
const RESIDENTS := ["Lía", "Tomás", "Mara", "Nico", "Eva"]
const HOME_SPOTS := [
	Vector2(0.19, 0.57), Vector2(0.17, 0.31), Vector2(0.39, 0.19),
	Vector2(0.38, 0.79), Vector2(0.58, 0.19)
]
const JOB_OPTIONS := [
	{"title": "Cultiva verduras", "place": "Huerta comunitaria"},
	{"title": "Operario de Nexo", "place": "Nexo Industrias"},
	{"title": "Administrativa de Nexo", "place": "Nexo Industrias"},
	{"title": "Logística de Nexo", "place": "Nexo Industrias"},
	{"title": "Atención en el café", "place": "Café"}
]
const FARM_PLOT_SCENE = preload("res://scenes/farm_plot.tscn")
const FARM_BACKDROP = preload("res://assets/farm_map.svg")
const CROP_OPTIONS := [
	{"name": "Trigo", "seed_cost": 3, "grow_minutes": 30},
	{"name": "Zanahoria", "seed_cost": 5, "grow_minutes": 45},
	{"name": "Tomate", "seed_cost": 8, "grow_minutes": 75}
]
const LOCAL_ORDERS := [
	{"customer": "Almacén del valle", "crop": "Trigo", "quantity": 3, "reward": 27},
	{"customer": "Café del valle", "crop": "Zanahoria", "quantity": 2, "reward": 28},
	{"customer": "Cooperativa local", "crop": "Tomate", "quantity": 2, "reward": 38}
]
const FARM_COLUMNS := 3
const FARM_ROWS := 2
const FARM_SPACING := 56.0

var map_rect: Rect2
var pond_polygon := PackedVector2Array()
var tree_positions: Array[Vector2] = []
var buildings: Array[StaticBody2D] = []
var villagers: Array[CharacterBody2D] = []
var walkable_cells: Array[Vector2i] = []
var navigation := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var clock_minutes := 8.0 * 60.0
var game_day := 1
var simulation_speed := 1.0
var paused := false
var speed_index := 0
var clock_label: Label
var pause_button: Button
var speed_button: Button
var market_button: Button
var inventory_label: Label
var selected_villager: CharacterBody2D
var inspector_panel: PanelContainer
var inspector_name: Label
var inspector_action: Label
var inspector_job: Label
var inspector_relationships: Label
var job_selector: OptionButton
var need_bars: Dictionary = {}
var inspector_refresh_time := 0.0
var plaza_position := Vector2.ZERO
var farm_plots: Array[Area2D] = []
var farm_plot_positions: Array[Vector2] = []
var selected_plot: Area2D
var farm_panel: PanelContainer
var farm_panel_layout: VBoxContainer
var farm_panel_mode := ""
var farm_panel_refresh_time := 0.0
var farm_plot_status: Label
var farm_crop_selector: OptionButton
var farm_action_button: Button
var farm_message: Label
var order_selector: OptionButton
var order_details: Label
var order_message: Label
var order_deliver_button: Button
var crop_inventory := {"Trigo": 0, "Zanahoria": 0, "Tomate": 0}
var coins := 90
var delivered_orders := 0


func _ready() -> void:
	rng.randomize()
	map_rect = Rect2(64, 112, size.x - 128, size.y - 154)
	_build_art_background()
	_build_pond()
	_build_interface()
	_build_trees()
	_build_buildings()
	plaza_position = _map_point(Vector2(0.56, 0.69))
	_build_farm_plots()
	_build_navigation()
	_spawn_villagers()
	queue_redraw()


func _build_art_background() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = FARM_BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)


func _process(delta: float) -> void:
	if not paused:
		var game_minutes := delta * simulation_speed * 10.0
		clock_minutes += game_minutes
		if clock_minutes >= 1440.0:
			game_day += int(clock_minutes / 1440.0)
			clock_minutes = fmod(clock_minutes, 1440.0)
		clock_label.text = _clock_text()
		for plot in farm_plots:
			plot.call("advance", game_minutes)

	if selected_villager != null and is_instance_valid(selected_villager):
		inspector_refresh_time += delta
		if inspector_refresh_time >= 0.25:
			inspector_refresh_time = 0.0
			_refresh_inspector()
	if farm_panel_mode == "plot":
		farm_panel_refresh_time += delta
		if farm_panel_refresh_time >= 0.25:
			farm_panel_refresh_time = 0.0
			_refresh_plot_panel()
	_refresh_inventory_label()


func _build_interface() -> void:
	var title := Label.new()
	title.text = "Ecos del Valle"
	title.position = Vector2(30, 22)
	title.size = Vector2(270, 38)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)

	var note := Label.new()
	note.text = "Una granja propia en un pueblo vivo"
	note.position = Vector2(32, 58)
	note.size = Vector2(440, 24)
	add_child(note)

	inventory_label = Label.new()
	inventory_label.position = Vector2(32, 84)
	inventory_label.size = Vector2(450, 22)
	inventory_label.add_theme_font_size_override("font_size", 14)
	add_child(inventory_label)

	market_button = Button.new()
	market_button.text = "Pedidos"
	market_button.position = Vector2(470, 22)
	market_button.size = Vector2(112, 42)
	market_button.pressed.connect(_open_orders_panel)
	add_child(market_button)

	clock_label = Label.new()
	clock_label.position = Vector2(size.x - 550, 30)
	clock_label.size = Vector2(155, 34)
	clock_label.custom_minimum_size = Vector2(155, 34)
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.add_theme_font_size_override("font_size", 17)
	clock_label.text = _clock_text()
	add_child(clock_label)

	pause_button = Button.new()
	pause_button.text = "Pausar"
	pause_button.toggle_mode = true
	pause_button.position = Vector2(size.x - 385, 22)
	pause_button.size = Vector2(92, 42)
	pause_button.custom_minimum_size = Vector2(92, 42)
	pause_button.toggled.connect(_on_pause_toggled)
	add_child(pause_button)

	speed_button = Button.new()
	speed_button.text = "1x"
	speed_button.position = Vector2(size.x - 280, 22)
	speed_button.size = Vector2(66, 42)
	speed_button.custom_minimum_size = Vector2(66, 42)
	speed_button.pressed.connect(_on_speed_pressed)
	add_child(speed_button)

	var back_button := Button.new()
	back_button.text = "Volver al inicio"
	back_button.position = Vector2(size.x - 190, 22)
	back_button.size = Vector2(160, 42)
	back_button.custom_minimum_size = Vector2(160, 42)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	_build_inspector()
	_build_farm_panel()
	_refresh_inventory_label()


func _build_inspector() -> void:
	inspector_panel = PanelContainer.new()
	inspector_panel.position = Vector2(size.x - 310, 82)
	inspector_panel.size = Vector2(286, size.y - 104)
	inspector_panel.custom_minimum_size = Vector2(286, size.y - 104)
	inspector_panel.visible = false
	add_child(inspector_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	inspector_panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	inspector_name = Label.new()
	inspector_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_name.add_theme_font_size_override("font_size", 22)
	header.add_child(inspector_name)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(_close_inspector)
	header.add_child(close_button)

	inspector_action = Label.new()
	layout.add_child(inspector_action)
	inspector_job = Label.new()
	inspector_job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(inspector_job)

	var needs_title := Label.new()
	needs_title.text = "Necesidades"
	needs_title.add_theme_font_size_override("font_size", 16)
	layout.add_child(needs_title)
	for need_name in ["Hambre", "Energía", "Diversión", "Social"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		layout.add_child(row)
		var label := Label.new()
		label.text = need_name
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		row.add_child(bar)
		need_bars[need_name] = bar

	var action_title := Label.new()
	action_title.text = "¿Qué quieres que haga?"
	action_title.add_theme_font_size_override("font_size", 16)
	layout.add_child(action_title)
	var first_actions := HBoxContainer.new()
	layout.add_child(first_actions)
	_add_action_button(first_actions, "Comer", "Comer")
	_add_action_button(first_actions, "Jugar", "Jugar")
	var second_actions := HBoxContainer.new()
	layout.add_child(second_actions)
	_add_action_button(second_actions, "Descansar", "Descansar")
	_add_action_button(second_actions, "Socializar", "Socializar")
	var work_button := Button.new()
	work_button.text = "Ir a trabajar"
	work_button.custom_minimum_size = Vector2(0, 38)
	work_button.pressed.connect(_order_selected_action.bind("Trabajar"))
	layout.add_child(work_button)

	var job_title := Label.new()
	job_title.text = "Oficio"
	job_title.add_theme_font_size_override("font_size", 16)
	layout.add_child(job_title)
	job_selector = OptionButton.new()
	for index in range(JOB_OPTIONS.size()):
		job_selector.add_item(JOB_OPTIONS[index]["title"], index)
	layout.add_child(job_selector)
	var assign_job_button := Button.new()
	assign_job_button.text = "Asignar oficio"
	assign_job_button.pressed.connect(_assign_selected_job)
	layout.add_child(assign_job_button)

	var relation_title := Label.new()
	relation_title.text = "Relaciones"
	relation_title.add_theme_font_size_override("font_size", 16)
	layout.add_child(relation_title)
	inspector_relationships = Label.new()
	inspector_relationships.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(inspector_relationships)


func _build_farm_panel() -> void:
	farm_panel = PanelContainer.new()
	farm_panel.position = Vector2(24, 116)
	farm_panel.size = Vector2(292, 300)
	farm_panel.custom_minimum_size = Vector2(292, 260)
	farm_panel.visible = false
	farm_panel.z_index = 10
	add_child(farm_panel)


func _clear_farm_panel() -> VBoxContainer:
	for child in farm_panel.get_children():
		farm_panel.remove_child(child)
		child.queue_free()
	farm_panel_layout = VBoxContainer.new()
	farm_panel_layout.add_theme_constant_override("separation", 10)
	farm_panel.add_child(farm_panel_layout)
	return farm_panel_layout


func _add_panel_header(layout: VBoxContainer, title: String) -> void:
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 19)
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(_close_farm_panel)
	header.add_child(close_button)


func _open_plot_panel(plot: Area2D) -> void:
	if selected_villager != null:
		_close_inspector()
	if selected_plot != null and is_instance_valid(selected_plot):
		selected_plot.call("set_selected", false)
	selected_plot = plot
	selected_plot.call("set_selected", true)
	farm_panel_mode = "plot"
	farm_panel.visible = true
	var layout := _clear_farm_panel()
	_add_panel_header(layout, "Parcela")
	farm_crop_selector = OptionButton.new()
	for index in range(CROP_OPTIONS.size()):
		var crop: Dictionary = CROP_OPTIONS[index]
		farm_crop_selector.add_item("%s  ·  %d monedas" % [crop["name"], crop["seed_cost"]], index)
	layout.add_child(farm_crop_selector)
	farm_plot_status = Label.new()
	farm_plot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(farm_plot_status)
	farm_action_button = Button.new()
	farm_action_button.custom_minimum_size = Vector2(0, 42)
	farm_action_button.pressed.connect(_on_farm_action_pressed)
	layout.add_child(farm_action_button)
	farm_message = Label.new()
	farm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(farm_message)
	_refresh_plot_panel()


func _refresh_plot_panel() -> void:
	if farm_panel_mode != "plot" or selected_plot == null or not is_instance_valid(selected_plot):
		return
	var crop_name := str(selected_plot.get("crop_name"))
	var selector_visible := crop_name.is_empty()
	farm_crop_selector.visible = selector_visible
	farm_action_button.disabled = false
	if selector_visible:
		farm_plot_status.text = "La tierra está lista. Elige una semilla para plantar."
		farm_action_button.text = "Sembrar"
		return

	var is_ready: bool = selected_plot.call("is_ready")
	var growth := float(selected_plot.get("growth_minutes"))
	var grow_time := float(selected_plot.get("grow_time_minutes"))
	var percent := int(growth / maxf(grow_time, 1.0) * 100.0)
	farm_plot_status.text = "%s · %s" % [crop_name, "lista para cosechar" if is_ready else "%d%% de crecimiento" % percent]
	farm_action_button.text = "Cosechar" if is_ready else "Todavía está creciendo"
	farm_action_button.disabled = not is_ready


func _on_farm_action_pressed() -> void:
	if selected_plot == null or not is_instance_valid(selected_plot):
		return
	if not str(selected_plot.get("crop_name")).is_empty():
		var harvested_crop := str(selected_plot.call("harvest"))
		if harvested_crop.is_empty():
			return
		crop_inventory[harvested_crop] = int(crop_inventory[harvested_crop]) + 1
		farm_message.text = "Cosechaste %s." % harvested_crop
		_refresh_inventory_label()
		_refresh_plot_panel()
		return

	var crop_index := farm_crop_selector.get_selected_id()
	if crop_index < 0 or crop_index >= CROP_OPTIONS.size():
		return
	var crop: Dictionary = CROP_OPTIONS[crop_index]
	var seed_cost := int(crop["seed_cost"])
	if coins < seed_cost:
		farm_message.text = "No alcanzan las monedas para esas semillas."
		return
	coins -= seed_cost
	selected_plot.call("plant", str(crop["name"]), float(crop["grow_minutes"]))
	farm_message.text = "Sembraste %s." % crop["name"]
	_refresh_inventory_label()
	_refresh_plot_panel()


func _open_orders_panel() -> void:
	if farm_panel_mode == "orders":
		_close_farm_panel()
		return
	if selected_villager != null:
		_close_inspector()
	if selected_plot != null and is_instance_valid(selected_plot):
		selected_plot.call("set_selected", false)
	selected_plot = null
	farm_panel_mode = "orders"
	farm_panel.visible = true
	var layout := _clear_farm_panel()
	_add_panel_header(layout, "Mercado del valle")
	order_selector = OptionButton.new()
	for index in range(LOCAL_ORDERS.size()):
		order_selector.add_item(LOCAL_ORDERS[index]["customer"], index)
	order_selector.item_selected.connect(_refresh_order_panel)
	layout.add_child(order_selector)
	order_details = Label.new()
	order_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(order_details)
	order_deliver_button = Button.new()
	order_deliver_button.text = "Entregar pedido"
	order_deliver_button.custom_minimum_size = Vector2(0, 42)
	order_deliver_button.pressed.connect(_deliver_order)
	layout.add_child(order_deliver_button)
	order_message = Label.new()
	order_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(order_message)
	_refresh_order_panel()


func _refresh_order_panel(_selected_index: int = 0) -> void:
	if farm_panel_mode != "orders" or order_selector == null:
		return
	var order_index := order_selector.get_selected_id()
	if order_index < 0 or order_index >= LOCAL_ORDERS.size():
		return
	var order: Dictionary = LOCAL_ORDERS[order_index]
	var crop_name: String = order["crop"]
	var quantity := int(order["quantity"])
	var available := int(crop_inventory[crop_name])
	order_details.text = "Piden %d %s.\nHay %d en el granero.\nPago: %d monedas." % [quantity, crop_name, available, int(order["reward"])]
	order_message.text = "Pedido %d completado." % delivered_orders if delivered_orders > 0 else "Encargos del pueblo, sin conexión."
	order_deliver_button.disabled = available < quantity


func _deliver_order() -> void:
	var order_index := order_selector.get_selected_id()
	if order_index < 0 or order_index >= LOCAL_ORDERS.size():
		return
	var order: Dictionary = LOCAL_ORDERS[order_index]
	var crop_name: String = order["crop"]
	var quantity := int(order["quantity"])
	if int(crop_inventory[crop_name]) < quantity:
		order_message.text = "Todavía faltan productos para este pedido."
		return
	crop_inventory[crop_name] = int(crop_inventory[crop_name]) - quantity
	coins += int(order["reward"])
	delivered_orders += 1
	order_message.text = "Pedido entregado. +%d monedas." % int(order["reward"])
	_refresh_inventory_label()
	_refresh_order_panel()


func _close_farm_panel() -> void:
	if selected_plot != null and is_instance_valid(selected_plot):
		selected_plot.call("set_selected", false)
	selected_plot = null
	farm_panel_mode = ""
	farm_panel.visible = false


func _refresh_inventory_label() -> void:
	if inventory_label == null:
		return
	inventory_label.text = "Monedas %d   ·   Trigo %d   ·   Zanahoria %d   ·   Tomate %d" % [coins, crop_inventory["Trigo"], crop_inventory["Zanahoria"], crop_inventory["Tomate"]]


func _add_action_button(parent: HBoxContainer, button_text: String, action_name: String) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(112, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_order_selected_action.bind(action_name))
	parent.add_child(button)


func _build_pond() -> void:
	pond_polygon = PackedVector2Array([
		_map_point(Vector2(0.76, 0.16)), _map_point(Vector2(0.79, 0.1)),
		_map_point(Vector2(0.85, 0.09)), _map_point(Vector2(0.91, 0.14)),
		_map_point(Vector2(0.94, 0.22)), _map_point(Vector2(0.91, 0.29)),
		_map_point(Vector2(0.85, 0.31)), _map_point(Vector2(0.79, 0.27)),
		_map_point(Vector2(0.75, 0.22))
	])

	var water := StaticBody2D.new()
	water.name = "Laguna"
	water.position = _map_point(Vector2(0.845, 0.2))
	water.collision_layer = 1
	water.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 82.0
	shape.shape = circle
	shape.scale = Vector2(1.25, 0.78)
	water.add_child(shape)
	add_child(water)


func _build_trees() -> void:
	for spot in TREE_SPOTS:
		var tree_position := _map_point(spot)
		tree_positions.append(tree_position)
		var tree := StaticBody2D.new()
		tree.name = "Arbol"
		tree.position = tree_position
		tree.collision_layer = 1
		tree.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 13.0
		shape.shape = circle
		tree.add_child(shape)
		add_child(tree)


func _build_buildings() -> void:
	var home_colors := [Color("#c98455"), Color("#bc7850"), Color("#d2a56c"), Color("#a86f58"), Color("#c99a65")]
	for index in range(RESIDENTS.size()):
		_add_building("Casa de " + RESIDENTS[index], HOME_SPOTS[index], home_colors[index], "casa")
	_add_building("Almacén", Vector2(0.46, 0.43), Color("#d2b86f"), "almacen")
	_add_building("Café", Vector2(0.76, 0.48), Color("#bd7667"), "cafe")
	_add_building("Huerta comunitaria", Vector2(0.22, 0.79), Color("#82965d"), "huerta", Vector2(126, 82))
	_add_building("Nexo Industrias", Vector2(0.63, 0.47), Color("#607982"), "empresa", Vector2(132, 82))


func _build_farm_plots() -> void:
	var first_plot_position := _map_point(Vector2(0.71, 0.66))
	for row in range(FARM_ROWS):
		for column in range(FARM_COLUMNS):
			var plot := FARM_PLOT_SCENE.instantiate() as Area2D
			plot.name = "Parcela_%d_%d" % [row + 1, column + 1]
			plot.position = first_plot_position + Vector2((column - row) * FARM_SPACING, (column + row) * FARM_SPACING * 0.5)
			plot.connect("selected", _open_plot_panel)
			farm_plots.append(plot)
			farm_plot_positions.append(plot.position)
			add_child(plot)


func _add_building(building_name: String, spot: Vector2, wall_color: Color, kind: String, building_size := Vector2(82, 66)) -> void:
	var building := StaticBody2D.new()
	building.name = building_name.replace(" ", "")
	building.position = _map_point(spot)
	building.collision_layer = 1
	building.collision_mask = 0
	building.set_meta("label", building_name)
	building.set_meta("wall_color", wall_color)
	building.set_meta("kind", kind)
	building.set_meta("size", building_size)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = building.get_meta("size")
	shape.shape = rectangle
	building.add_child(shape)
	buildings.append(building)
	add_child(building)


func _build_navigation() -> void:
	var columns := int(map_rect.size.x / CELL_SIZE)
	var rows := int(map_rect.size.y / CELL_SIZE)
	navigation.region = Rect2i(0, 0, columns, rows)
	navigation.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	navigation.offset = map_rect.position + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()

	for x in range(columns):
		for y in range(rows):
			var cell := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == columns - 1 or y == rows - 1
			if edge or _is_blocked(navigation.get_point_position(cell)):
				navigation.set_point_solid(cell)
			else:
				walkable_cells.append(cell)


func _is_blocked(point: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(point, pond_polygon):
		return true

	for building in buildings:
		var building_size: Vector2 = building.get_meta("size")
		var clearance := Vector2(20, 20)
		var bounds := Rect2(building.position - building_size / 2.0 - clearance, building_size + clearance * 2.0)
		if bounds.has_point(point):
			return true

	for tree_position in tree_positions:
		if point.distance_to(tree_position) < 34.0:
			return true

	for plot_position in farm_plot_positions:
		if absf(point.x - plot_position.x) < 30.0 and absf(point.y - plot_position.y) < 26.0:
			return true

	return false


func _spawn_villagers() -> void:
	var names := RESIDENTS
	var colors := [Color("#d66f55"), Color("#4c8580"), Color("#d4a447"), Color("#7089b0"), Color("#a16c91")]
	var used_cells: Array[Vector2i] = []

	for index in range(names.size()):
		var villager := VILLAGER_SCENE.instantiate() as CharacterBody2D
		villager.set("display_name", names[index])
		villager.set("body_color", colors[index])
		villager.set("simulation_speed", simulation_speed)
		villager.set("simulation_paused", paused)
		var home_name: String = "Casa de " + str(names[index])
		villager.call("set_home", home_name, _place_entry(home_name))
		var job: Dictionary = JOB_OPTIONS[index % JOB_OPTIONS.size()]
		villager.call("assign_job", job["title"], job["place"], _place_entry(job["place"]))
		var spawn_cell := _random_walkable_cell()
		for attempt in range(20):
			var candidate := _random_walkable_cell()
			var is_close := false
			for used_cell in used_cells:
				if navigation.get_point_position(candidate).distance_to(navigation.get_point_position(used_cell)) < 48.0:
					is_close = true
					break
			if not is_close:
				spawn_cell = candidate
				break
		used_cells.append(spawn_cell)
		villager.position = navigation.get_point_position(spawn_cell)
		villager.connect("destination_requested", _on_villager_destination_requested)
		villager.connect("selected", _show_inspector)
		villager.connect("activity_finished", _on_activity_finished)
		villagers.append(villager)
		add_child(villager)
		_assign_destination(villager)


func _assign_destination(villager: CharacterBody2D) -> void:
	_choose_next_action(villager)


func _random_walkable_cell() -> Vector2i:
	return walkable_cells[rng.randi_range(0, walkable_cells.size() - 1)]


func _world_to_cell(point: Vector2) -> Vector2i:
	var offset := navigation.offset
	return Vector2i(
		roundi((point.x - offset.x) / CELL_SIZE),
		roundi((point.y - offset.y) / CELL_SIZE)
	)


func _on_villager_destination_requested(villager: CharacterBody2D) -> void:
	_choose_next_action(villager)


func _choose_next_action(villager: CharacterBody2D) -> void:
	var needs: Dictionary = villager.get("needs")
	var hour := int(clock_minutes / 60.0) % 24
	if float(needs["Hambre"]) < 30.0 or (hour >= 11 and hour <= 13 and float(needs["Hambre"]) < 65.0):
		_order_action(villager, "Comer")
	elif float(needs["Energía"]) < 24.0 or hour >= 22 or hour < 6:
		_order_action(villager, "Descansar")
	elif float(needs["Social"]) < 32.0:
		_order_action(villager, "Socializar")
	elif float(needs["Diversión"]) < 28.0:
		_order_action(villager, "Jugar")
	elif hour >= 8 and hour < 17 and str(villager.get("job_title")) != "Sin trabajo":
		_order_action(villager, "Trabajar")
	elif hour >= 18 and hour <= 20 and float(needs["Hambre"]) < 72.0:
		_order_action(villager, "Comer")
	elif float(needs["Social"]) < float(needs["Diversión"]):
		_order_action(villager, "Socializar")
	else:
		_order_action(villager, "Jugar")


func _order_selected_action(action_name: String) -> void:
	if selected_villager != null and is_instance_valid(selected_villager):
		_order_action(selected_villager, action_name)


func _order_action(villager: CharacterBody2D, action_name: String) -> void:
	var place_name := ""
	var target := Vector2.ZERO
	var duration := 30.0
	match action_name:
		"Comer":
			place_name = "Café"
			target = _place_entry(place_name)
			duration = 35.0
		"Jugar":
			place_name = "Plaza"
			target = plaza_position + Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-24.0, 24.0))
			duration = 55.0
		"Descansar":
			place_name = str(villager.get("home_name"))
			target = villager.get("home_position")
			duration = 150.0
		"Socializar":
			place_name = "Plaza"
			target = plaza_position + Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-24.0, 24.0))
			duration = 50.0
		"Trabajar":
			if str(villager.get("job_title")) == "Sin trabajo":
				return
			place_name = str(villager.get("workplace_name"))
			target = villager.get("workplace_position")
			duration = 180.0
		_:
			return

	var start_cell := _nearest_walkable_cell(villager.global_position)
	var target_cell := _nearest_walkable_cell(target)
	var route := navigation.get_point_path(start_cell, target_cell)
	if route.is_empty():
		villager.call("cancel_action")
		return

	villager.call("begin_action", action_name, duration)
	villager.call("set", "current_action", "Va a " + place_name)
	villager.call("set_route", route)


func _nearest_walkable_cell(point: Vector2) -> Vector2i:
	var best_cell := walkable_cells[0]
	var best_distance := INF
	for cell in walkable_cells:
		var distance := point.distance_squared_to(navigation.get_point_position(cell))
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell


func _place_entry(place_name: String) -> Vector2:
	for building in buildings:
		if str(building.get_meta("label")) == place_name:
			var building_size: Vector2 = building.get_meta("size")
			return building.position + Vector2(0, building_size.y / 2.0 + 30.0)
	return plaza_position


func _show_inspector(villager: CharacterBody2D) -> void:
	if farm_panel_mode != "":
		_close_farm_panel()
	if selected_villager != null and is_instance_valid(selected_villager):
		selected_villager.call("set_selected", false)
	selected_villager = villager
	selected_villager.call("set_selected", true)
	inspector_panel.visible = true
	var selected_job := str(villager.get("job_title"))
	for index in range(JOB_OPTIONS.size()):
		if JOB_OPTIONS[index]["title"] == selected_job:
			job_selector.select(index)
			break
	_refresh_inspector()


func _refresh_inspector() -> void:
	if selected_villager == null or not is_instance_valid(selected_villager):
		_close_inspector()
		return

	inspector_name.text = str(selected_villager.get("display_name"))
	inspector_action.text = "Ahora: " + str(selected_villager.get("current_action"))
	inspector_job.text = "Trabaja: " + str(selected_villager.get("job_title"))
	var needs: Dictionary = selected_villager.get("needs")
	for need_name in need_bars:
		need_bars[need_name].value = float(needs.get(need_name, 0.0))
	inspector_relationships.text = _relationship_summary(selected_villager)


func _relationship_summary(villager: CharacterBody2D) -> String:
	var relationships: Dictionary = villager.get("relationships")
	var best_name := ""
	var best_score := 0.0
	for other_name in relationships:
		var score := float(relationships[other_name])
		if score > best_score:
			best_score = score
			best_name = str(other_name)
	if best_name.is_empty():
		return "Todavía no conoce a nadie."
	var relationship := "Conocido"
	if best_score >= 65.0:
		relationship = "Amigo"
	return "%s: %s" % [relationship, best_name]


func _assign_selected_job() -> void:
	if selected_villager == null or not is_instance_valid(selected_villager):
		return
	var job_index := job_selector.get_selected_id()
	if job_index < 0 or job_index >= JOB_OPTIONS.size():
		return
	var job: Dictionary = JOB_OPTIONS[job_index]
	var place_name: String = job["place"]
	selected_villager.call("assign_job", job["title"], place_name, _place_entry(place_name))
	_refresh_inspector()


func _close_inspector() -> void:
	if selected_villager != null and is_instance_valid(selected_villager):
		selected_villager.call("set_selected", false)
	selected_villager = null
	inspector_panel.visible = false


func _on_activity_finished(villager: CharacterBody2D, action_name: String) -> void:
	if action_name != "Socializar":
		return
	var closest: CharacterBody2D
	var closest_distance := 150.0
	for other in villagers:
		if other == villager:
			continue
		var distance := villager.global_position.distance_to(other.global_position)
		if distance < closest_distance:
			closest = other
			closest_distance = distance
	if closest == null:
		return
	villager.call("add_relationship", str(closest.get("display_name")), 18.0)
	closest.call("add_relationship", str(villager.get("display_name")), 18.0)


func _on_pause_toggled(value: bool) -> void:
	paused = value
	pause_button.text = "Seguir" if paused else "Pausar"
	for villager in villagers:
		villager.set("simulation_paused", paused)


func _on_speed_pressed() -> void:
	speed_index = (speed_index + 1) % 3
	simulation_speed = [1.0, 2.0, 3.0][speed_index]
	speed_button.text = "%dx" % int(simulation_speed)
	for villager in villagers:
		villager.set("simulation_speed", simulation_speed)


func _clock_text() -> String:
	var hours := int(clock_minutes) / 60
	var minutes := int(clock_minutes) % 60
	return "Día %d  %02d:%02d" % [game_day, hours, minutes]


func _map_point(spot: Vector2) -> Vector2:
	return map_rect.position + map_rect.size * spot


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#142b35"))
	draw_rect(map_rect, Color("#76965d"))

	for index in range(28):
		var spot := Vector2(fposmod(index * 0.371, 0.9) + 0.05, fposmod(index * 0.617, 0.86) + 0.07)
		var patch_position := _map_point(spot)
		draw_circle(patch_position, 10.0 + float(index % 4) * 3.0, Color("#88a768"))
	_draw_farm_field()

	var path_color := Color("#c6aa70")
	var path_edge := Color("#776142")
	_draw_path([Vector2(0.04, 0.86), Vector2(0.2, 0.8), Vector2(0.34, 0.72), Vector2(0.47, 0.69), Vector2(0.56, 0.69), Vector2(0.72, 0.67), Vector2(0.95, 0.78)], path_color, path_edge)
	_draw_path([Vector2(0.19, 0.8), Vector2(0.19, 0.63), Vector2(0.19, 0.57)], path_color, path_edge)
	_draw_path([Vector2(0.34, 0.72), Vector2(0.37, 0.53), Vector2(0.39, 0.2)], path_color, path_edge)
	_draw_path([Vector2(0.47, 0.69), Vector2(0.46, 0.5), Vector2(0.46, 0.43)], path_color, path_edge)
	_draw_path([Vector2(0.56, 0.69), Vector2(0.62, 0.5), Vector2(0.63, 0.47)], path_color, path_edge)
	_draw_path([Vector2(0.72, 0.67), Vector2(0.75, 0.53), Vector2(0.76, 0.48)], path_color, path_edge)
	_draw_path([Vector2(0.56, 0.69), Vector2(0.58, 0.35), Vector2(0.58, 0.19)], path_color, path_edge)

	draw_colored_polygon(pond_polygon, Color("#5b9f9a"))
	var pond_outline := pond_polygon.duplicate()
	pond_outline.append(pond_polygon[0])
	draw_polyline(pond_outline, Color("#c0d4b1"), 4.0, true)
	for index in range(4):
		var wave_x := map_rect.position.x + map_rect.size.x * (0.81 + index * 0.025)
		var wave_y := map_rect.position.y + map_rect.size.y * (0.18 + index * 0.025)
		draw_line(Vector2(wave_x, wave_y), Vector2(wave_x + 18, wave_y - 3), Color("#9bc9b1"), 2.0)

	for tree_position in tree_positions:
		_draw_tree(tree_position, 20.0)

	_draw_plaza()

	for building in buildings:
		_draw_building(building)

	draw_rect(map_rect, Color("#c8d2a3"), false, 4.0)
	draw_circle(Vector2(size.x - 104, 145), 20.0, Color("#e4e1bd"))
	draw_line(Vector2(size.x - 104, 158), Vector2(size.x - 104, 132), Color("#314943"), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 109, 125), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color("#314943"))


func _draw_path(spots: Array[Vector2], color: Color, edge_color: Color) -> void:
	var points := PackedVector2Array()
	for spot in spots:
		points.append(_map_point(spot))
	draw_polyline(points, edge_color, 48.0, true)
	draw_polyline(points, color, 40.0, true)


func _draw_tree(tree_position: Vector2, radius: float) -> void:
	draw_circle(tree_position + Vector2(2, 5), radius, Color("#526d48"))
	draw_circle(tree_position, radius, Color("#385943"))
	draw_circle(tree_position + Vector2(-4, -5), radius * 0.68, Color("#52784d"))


func _draw_building(building: StaticBody2D) -> void:
	var position := building.position
	var wall_color: Color = building.get_meta("wall_color")
	var label: String = building.get_meta("label")
	var building_size: Vector2 = building.get_meta("size")
	var kind: String = building.get_meta("kind")
	var top_left := position - building_size / 2.0
	draw_rect(Rect2(top_left + Vector2(2, 6), building_size), Color("#435443"))
	draw_rect(Rect2(top_left, building_size), wall_color)

	if kind == "empresa":
		draw_rect(Rect2(top_left + Vector2(6, 8), Vector2(building_size.x - 12, 10)), Color("#3f535b"))
		for window_index in range(5):
			draw_rect(Rect2(top_left + Vector2(12 + window_index * 21, 30), Vector2(12, 12)), Color("#c5d5c4"))
		draw_rect(Rect2(top_left + Vector2(18, -14), Vector2(12, 22)), Color("#435d63"))
		draw_rect(Rect2(top_left + Vector2(building_size.x - 32, -9), Vector2(10, 17)), Color("#435d63"))
	elif kind == "huerta":
		for row in range(4):
			var y := top_left.y + 15 + row * 12
			draw_line(Vector2(top_left.x + 12, y), Vector2(top_left.x + building_size.x - 12, y), Color("#684f36"), 3.0)
			for plant in range(7):
				var x := top_left.x + 22 + plant * 14
				draw_circle(Vector2(x, y - 3), 4.0, Color("#496f42"))
	else:
		draw_colored_polygon(PackedVector2Array([
			position + Vector2(-building_size.x / 2.0 - 4, -8),
			position + Vector2(-building_size.x / 2.0 + 8, -building_size.y / 2.0 - 5),
			position + Vector2(building_size.x / 2.0 - 8, -building_size.y / 2.0 - 5),
			position + Vector2(building_size.x / 2.0 + 4, -8)
		]), Color("#704c40"))
		if kind == "casa":
			draw_rect(Rect2(position + Vector2(-7, 8), Vector2(14, 20)), Color("#594538"))
			draw_rect(Rect2(position + Vector2(-27, 1), Vector2(10, 10)), Color("#d4dfc1"))
			draw_rect(Rect2(position + Vector2(17, 1), Vector2(10, 10)), Color("#d4dfc1"))
		else:
			draw_rect(Rect2(position + Vector2(-7, 8), Vector2(14, 20)), Color("#594538"))

	draw_string(ThemeDB.fallback_font, position + Vector2(-building_size.x / 2.0 - 8, building_size.y / 2.0 + 17), label, HORIZONTAL_ALIGNMENT_LEFT, building_size.x + 28, 12, Color("#f1efda"))


func _draw_plaza() -> void:
	draw_circle(plaza_position, 48.0, Color("#9c8e67"))
	draw_circle(plaza_position, 40.0, Color("#b4a274"))
	draw_circle(plaza_position, 12.0, Color("#6d9790"))
	draw_circle(plaza_position, 7.0, Color("#c4d0a1"))
	for bench_offset in [Vector2(-30, 0), Vector2(30, 0)]:
		draw_rect(Rect2(plaza_position + bench_offset + Vector2(-12, -4), Vector2(24, 8)), Color("#644a37"))
		draw_line(plaza_position + bench_offset + Vector2(-8, 4), plaza_position + bench_offset + Vector2(-8, 9), Color("#473a31"), 2.0)
		draw_line(plaza_position + bench_offset + Vector2(8, 4), plaza_position + bench_offset + Vector2(8, 9), Color("#473a31"), 2.0)


func _draw_farm_field() -> void:
	if farm_plot_positions.is_empty():
		return
	var first_plot := farm_plot_positions[0]
	var field_size := Vector2((FARM_COLUMNS - 1) * FARM_SPACING + 66.0, (FARM_ROWS - 1) * FARM_SPACING + 58.0)
	var field_rect := Rect2(first_plot - Vector2(33, 29), field_size)
	draw_rect(field_rect, Color("#657d4b"))
	draw_rect(field_rect, Color("#a9b76e"), false, 3.0)
	draw_string(ThemeDB.fallback_font, field_rect.position + Vector2(4, -7), "GRANJA DE LÍA", HORIZONTAL_ALIGNMENT_LEFT, 200, 13, Color("#f1efda"))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")