extends Control

var subtitle_label: Label
var start_button: Button
var back_button: Button


func _ready() -> void:
	_build_screen()


func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#142b35")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 300)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "ECOS DEL VALLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	layout.add_child(title)

	subtitle_label = Label.new()
	subtitle_label.text = "Un pequeño pueblo. Muchas vidas. Cada decisión deja huella."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(subtitle_label)

	start_button = Button.new()
	start_button.text = "Despertar el valle"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.pressed.connect(_on_start_pressed)
	layout.add_child(start_button)

	back_button = Button.new()
	back_button.text = "Volver al inicio"
	back_button.custom_minimum_size = Vector2(0, 48)
	back_button.visible = false
	back_button.pressed.connect(_on_back_pressed)
	layout.add_child(back_button)


func _on_start_pressed() -> void:
	subtitle_label.text = "La base del juego está lista. En las próximas partes construiremos el valle y sus habitantes."
	start_button.visible = false
	back_button.visible = true


func _on_back_pressed() -> void:
	subtitle_label.text = "Un pequeño pueblo. Muchas vidas. Cada decisión deja huella."
	start_button.visible = true
	back_button.visible = false
