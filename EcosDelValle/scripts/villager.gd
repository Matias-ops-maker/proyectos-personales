class_name Villager
extends CharacterBody2D

signal destination_requested(villager: CharacterBody2D)
signal selected(villager: CharacterBody2D)
signal activity_finished(villager: CharacterBody2D, action_name: String)

@export var display_name := "Lía"
@export var body_color := Color("#d66f55")

var movement_speed := 48.0
var simulation_speed := 1.0
var simulation_paused := false
var route := PackedVector2Array()
var route_index := 0
var wait_timer := 0.0
var waiting := false
var needs := {"Hambre": 78.0, "Energía": 76.0, "Diversión": 68.0, "Social": 64.0}
var current_action := "Paseando"
var active_action := ""
var action_duration_minutes := 0.0
var action_remaining_minutes := 0.0
var home_name := "Casa de Lía"
var home_position := Vector2.ZERO
var job_title := "Sin trabajo"
var workplace_name := ""
var workplace_position := Vector2.ZERO
var workplace_indoor := false
var relationships: Dictionary = {}
var is_selected := false
var animation_phase := 0.0

@onready var name_tag: Label = $NameTag


func _ready() -> void:
	name_tag.text = display_name
	input_event.connect(_on_input_event)
	queue_redraw()


func set_route(new_route: PackedVector2Array) -> void:
	route = new_route
	route_index = 1 if route.size() > 1 else 0
	waiting = false
	if route.is_empty():
		_wait_at_destination()
	elif route.size() == 1:
		_arrive_at_destination()


func set_home(place_name: String, position: Vector2) -> void:
	home_name = place_name
	home_position = position


func assign_job(title: String, place_name: String, position: Vector2) -> void:
	job_title = title
	workplace_name = place_name
	workplace_position = position
	workplace_indoor = place_name == "Nexo Industrias"


func begin_action(action_name: String, duration_minutes: float) -> void:
	active_action = action_name
	current_action = "Yendo a destino"
	action_duration_minutes = duration_minutes
	action_remaining_minutes = duration_minutes
	waiting = false
	visible = true


func cancel_action() -> void:
	active_action = ""
	current_action = "Paseando"
	waiting = false


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func add_relationship(other_name: String, amount: float) -> void:
	var score := float(relationships.get(other_name, 0.0))
	relationships[other_name] = clampf(score + amount, 0.0, 100.0)


func _physics_process(delta: float) -> void:
	if simulation_paused:
		velocity = Vector2.ZERO
		return
	var game_minutes := delta * simulation_speed * 10.0
	_update_needs(game_minutes)

	if waiting:
		if active_action != "":
			_apply_action_needs(game_minutes)
			action_remaining_minutes -= game_minutes
			if action_remaining_minutes <= 0.0:
				_finish_action()
		else:
			wait_timer -= delta * simulation_speed
			if wait_timer <= 0.0:
				waiting = false
			destination_requested.emit(self)
		return

	if route_index >= route.size():
		_wait_at_destination()
		return

	var target := route[route_index]
	var step := movement_speed * simulation_speed * delta
	if global_position.distance_to(target) <= step:
		global_position = target
		route_index += 1
		if route_index >= route.size():
			_arrive_at_destination()
			return
		target = route[route_index]

	var previous_position := global_position
	velocity = global_position.direction_to(target) * movement_speed * simulation_speed
	move_and_slide()
	if velocity.length_squared() > 1.0:
		animation_phase += delta * simulation_speed * 8.0
		queue_redraw()
	if get_slide_collision_count() > 0 and global_position.distance_to(previous_position) < 0.1:
		_wait_at_destination()
	elif route_index >= route.size() - 1 and global_position.distance_to(target) <= step:
		global_position = target
		_arrive_at_destination()


func _wait_at_destination() -> void:
	velocity = Vector2.ZERO
	route = PackedVector2Array()
	route_index = 0
	waiting = true
	wait_timer = randf_range(0.8, 2.4)
	current_action = "Paseando"


func _arrive_at_destination() -> void:
	velocity = Vector2.ZERO
	route = PackedVector2Array()
	route_index = 0
	waiting = true
	if active_action != "":
		current_action = active_action
		action_remaining_minutes = action_duration_minutes
		visible = not (active_action == "Trabajar" and workplace_indoor)
	else:
		current_action = "Paseando"
		wait_timer = randf_range(0.8, 2.4)


func _update_needs(game_minutes: float) -> void:
	needs["Hambre"] = maxf(float(needs["Hambre"]) - game_minutes * 0.014, 0.0)
	needs["Energía"] = maxf(float(needs["Energía"]) - game_minutes * 0.009, 0.0)
	needs["Diversión"] = maxf(float(needs["Diversión"]) - game_minutes * 0.007, 0.0)
	needs["Social"] = maxf(float(needs["Social"]) - game_minutes * 0.006, 0.0)


func _apply_action_needs(game_minutes: float) -> void:
	match active_action:
		"Comer":
			needs["Hambre"] = minf(float(needs["Hambre"]) + game_minutes * 0.72, 100.0)
		"Descansar":
			needs["Energía"] = minf(float(needs["Energía"]) + game_minutes * 0.3, 100.0)
		"Jugar":
			needs["Diversión"] = minf(float(needs["Diversión"]) + game_minutes * 0.55, 100.0)
			needs["Energía"] = maxf(float(needs["Energía"]) - game_minutes * 0.04, 0.0)
		"Socializar":
			needs["Social"] = minf(float(needs["Social"]) + game_minutes * 0.48, 100.0)
		"Trabajar":
			needs["Energía"] = maxf(float(needs["Energía"]) - game_minutes * 0.018, 0.0)
			needs["Hambre"] = maxf(float(needs["Hambre"]) - game_minutes * 0.01, 0.0)


func _finish_action() -> void:
	var finished_action := active_action
	active_action = ""
	waiting = false
	current_action = "Paseando"
	visible = true
	activity_finished.emit(self, finished_action)
	destination_requested.emit(self)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)


func _draw() -> void:
	var bob := sin(animation_phase) * 1.2 if velocity.length_squared() > 1.0 else 0.0
	draw_set_transform(Vector2(1, 10), 0.0, Vector2(1.4, 0.48))
	draw_circle(Vector2.ZERO, 12.0, Color(0.16, 0.27, 0.13, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_selected:
		draw_set_transform(Vector2(0, 9), 0.0, Vector2(1.45, 0.55))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color("#f4df89"), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var step := sin(animation_phase) * 3.0 if velocity.length_squared() > 1.0 else 0.0
	draw_line(Vector2(-4, 5 + bob), Vector2(-5 - step, 15), Color("#604b39"), 4.0)
	draw_line(Vector2(4, 5 + bob), Vector2(5 + step, 15), Color("#604b39"), 4.0)
	draw_circle(Vector2(-5 - step, 15), 2.5, Color("#f0d59f"))
	draw_circle(Vector2(5 + step, 15), 2.5, Color("#f0d59f"))

	draw_line(Vector2(-8, -10 + bob), Vector2(-13, -1 + bob), body_color.darkened(0.12), 5.0)
	draw_line(Vector2(8, -10 + bob), Vector2(13, -2 + bob), body_color.darkened(0.12), 5.0)
	draw_circle(Vector2(-13, -1 + bob), 2.7, Color("#e8b996"))
	draw_circle(Vector2(13, -2 + bob), 2.7, Color("#e8b996"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -17 + bob), Vector2(-5, -20 + bob), Vector2(5, -20 + bob),
		Vector2(9, -15 + bob), Vector2(8, -3 + bob), Vector2(5, 5 + bob),
		Vector2(-5, 5 + bob), Vector2(-8, -3 + bob)
	]), body_color)
	draw_line(Vector2(-5, -14 + bob), Vector2(5, -14 + bob), body_color.lightened(0.25), 2.0)
	draw_circle(Vector2(0, -8 + bob), 1.3, Color("#f4d78f"))
	draw_circle(Vector2(0, -2 + bob), 1.3, Color("#f4d78f"))

	draw_circle(Vector2.ZERO + Vector2(0, -24 + bob), 8.0, Color("#edbd92"))
	draw_circle(Vector2(-7, -24 + bob), 2.0, Color("#dca981"))
	draw_circle(Vector2(7, -24 + bob), 2.0, Color("#dca981"))
	draw_arc(Vector2(0, -25 + bob), 8.2, PI, TAU, 20, Color("#634538"), 4.0)
	draw_arc(Vector2(0, -28 + bob), 7.5, PI + 0.25, TAU - 0.25, 12, Color("#49382f"), 3.5)
	draw_circle(Vector2(-2.5, -24 + bob), 0.9, Color("#49382f"))
	draw_circle(Vector2(2.5, -24 + bob), 0.9, Color("#49382f"))
	draw_arc(Vector2(0, -20 + bob), 2.0, 0.2, PI - 0.2, 10, Color("#a65b4e"), 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -29 + bob), Vector2(-5, -35 + bob), Vector2(5, -35 + bob),
		Vector2(9, -29 + bob), Vector2(12, -27 + bob), Vector2(-11, -27 + bob)
	]), Color("#e3bd6d"))
	draw_arc(Vector2(0, -29 + bob), 10.0, PI, TAU, 16, Color("#9d754b"), 2.0)