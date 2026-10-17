extends Control


func _ready() -> void:
	var title := Label.new()
	title.text = "El valle"
	title.position = Vector2(30, 22)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	var note := Label.new()
	note.text = "Un lugar que empieza a tomar forma"
	note.position = Vector2(32, 58)
	add_child(note)

	var back_button := Button.new()
	back_button.text = "Volver al inicio"
	back_button.position = Vector2(size.x - 190, 24)
	back_button.custom_minimum_size = Vector2(160, 42)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

	_draw_map()


func _draw_map() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#142b35"))

	var map := Rect2(64, 100, size.x - 128, size.y - 142)
	draw_rect(map, Color("#76965d"))
	draw_rect(map, Color("#c8d2a3"), false, 4.0)

	var tree_spots := [
		Vector2(0.08, 0.05), Vector2(0.2, 0.04), Vector2(0.34, 0.06),
		Vector2(0.5, 0.04), Vector2(0.66, 0.06), Vector2(0.81, 0.04),
		Vector2(0.93, 0.06), Vector2(0.06, 0.3), Vector2(0.94, 0.27),
		Vector2(0.07, 0.56), Vector2(0.93, 0.56), Vector2(0.1, 0.83),
		Vector2(0.26, 0.94), Vector2(0.43, 0.92), Vector2(0.62, 0.95),
		Vector2(0.79, 0.92), Vector2(0.91, 0.84)
	]

	for spot in tree_spots:
		var tree_position := map.position + map.size * spot
		_draw_tree(tree_position, 20.0)

	draw_circle(Vector2(size.x - 104, 145), 20.0, Color("#e4e1bd"))
	draw_line(Vector2(size.x - 104, 158), Vector2(size.x - 104, 132), Color("#314943"), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 109, 125), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color("#314943"))


func _draw_tree(tree_position: Vector2, radius: float) -> void:
	draw_circle(tree_position + Vector2(2, 5), radius, Color("#526d48"))
	draw_circle(tree_position, radius, Color("#385943"))
	draw_circle(tree_position + Vector2(-4, -5), radius * 0.68, Color("#52784d"))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")