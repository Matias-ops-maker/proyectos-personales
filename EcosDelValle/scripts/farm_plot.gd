extends Area2D

signal selected(plot: Area2D)

var crop_name := ""
var growth_minutes := 0.0
var grow_time_minutes := 0.0
var selected_plot := false
var last_drawn_stage := -1


func _ready() -> void:
	input_event.connect(_on_input_event)
	input_pickable = true
	queue_redraw()


func plant(seed_name: String, grow_minutes: float) -> bool:
	if not crop_name.is_empty():
		return false
	crop_name = seed_name
	growth_minutes = 0.0
	grow_time_minutes = grow_minutes
	last_drawn_stage = -1
	queue_redraw()
	return true


func advance(game_minutes: float) -> void:
	if crop_name.is_empty() or is_ready():
		return
	growth_minutes = minf(growth_minutes + game_minutes, grow_time_minutes)
	var stage := _growth_stage()
	if stage != last_drawn_stage:
		last_drawn_stage = stage
		queue_redraw()


func harvest() -> String:
	if not is_ready():
		return ""
	var harvested_crop := crop_name
	crop_name = ""
	growth_minutes = 0.0
	grow_time_minutes = 0.0
	last_drawn_stage = -1
	queue_redraw()
	return harvested_crop


func is_ready() -> bool:
	return not crop_name.is_empty() and growth_minutes >= grow_time_minutes


func set_selected(value: bool) -> void:
	selected_plot = value
	queue_redraw()


func _growth_stage() -> int:
	if crop_name.is_empty() or grow_time_minutes <= 0.0:
		return 0
	return clampi(int(floor(growth_minutes / grow_time_minutes * 3.0)) + 1, 1, 3)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)


func _draw() -> void:
	var tile := PackedVector2Array([
		Vector2(-31, 0), Vector2(-18, -20), Vector2(13, -23),
		Vector2(31, -4), Vector2(23, 18), Vector2(-13, 22)
	])
	var shadow := PackedVector2Array()
	for point in tile:
		shadow.append(point + Vector2(2, 6))
	draw_colored_polygon(shadow, Color("#557844"))
	draw_colored_polygon(tile, Color("#8f633d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-25, 0), Vector2(-14, -16), Vector2(11, -19),
		Vector2(25, -3), Vector2(18, 14), Vector2(-11, 18)
	]), Color("#b98750"))
	for row in range(3):
		var row_y := -10.0 + row * 9.0
		draw_line(Vector2(-16, row_y - 4), Vector2(16, row_y + 4), Color("#765035"), 2.0)

	var stage := _growth_stage()
	if stage > 0:
		var plant_color := Color("#609247")
		var leaf_color := Color("#aed45e")
		match crop_name:
			"Trigo":
				plant_color = Color("#8ca84a")
				leaf_color = Color("#d5bd5c")
			"Zanahoria":
				plant_color = Color("#4c854f")
				leaf_color = Color("#a2c267")
			"Tomate":
				plant_color = Color("#47794a")
				leaf_color = Color("#91b35d")
		for plant_index in range(3):
			var plant_position := Vector2(-12 + plant_index * 12, 7)
			var plant_top := plant_position + Vector2(0, -4 - stage * 4)
			draw_line(plant_position + Vector2(0, 7), plant_top, plant_color, 3.5)
			_draw_leaf(plant_top + Vector2(-5, 2), Vector2(6, 3), leaf_color)
			_draw_leaf(plant_top + Vector2(5, -1), Vector2(6, 3), leaf_color)
			if stage == 3:
				var fruit_color := Color("#d5bd5c") if crop_name == "Trigo" else Color("#df8551")
				if crop_name == "Tomate":
					fruit_color = Color("#d95e4d")
				draw_circle(plant_top + Vector2(0, -2), 4.5, fruit_color)

	var border := tile.duplicate()
	border.append(tile[0])
	if selected_plot:
		draw_polyline(border, Color("#fff0a4"), 4.0, true)
	elif is_ready():
		draw_polyline(border, Color("#f2d76b"), 3.0, true)


func _draw_leaf(center: Vector2, radii: Vector2, leaf_color: Color) -> void:
	var leaf := PackedVector2Array()
	for index in range(12):
		var angle := TAU * index / 12.0
		leaf.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(leaf, leaf_color)