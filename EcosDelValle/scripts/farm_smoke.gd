extends SceneTree

const VALLEY_SCENE = preload("res://scenes/valle.tscn")


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var valley := VALLEY_SCENE.instantiate()
	root.add_child(valley)
	await process_frame
	assert(valley.farm_plots.size() == 6)

	var starting_coins: int = valley.coins
	for plot_index in range(3):
		var plot: Area2D = valley.farm_plots[plot_index]
		valley._open_plot_panel(plot)
		valley.farm_crop_selector.select(0)
		valley._on_farm_action_pressed()
		assert(str(plot.get("crop_name")) == "Trigo")
		plot.call("advance", 30.0)
		assert(plot.call("is_ready"))
		valley._on_farm_action_pressed()

	assert(int(valley.crop_inventory["Trigo"]) == 3)
	valley._open_orders_panel()
	valley.order_selector.select(0)
	valley._deliver_order()
	assert(int(valley.crop_inventory["Trigo"]) == 0)
	assert(valley.coins == starting_coins - 9 + 27)
	print("FARM_SMOKE_OK")
	quit()