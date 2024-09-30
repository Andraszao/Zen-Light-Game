extends Control

const INITIAL_ORB_COUNT: int = 5

var grid_manager: GridManager
var ui_manager: UIManager
var lumin_orbs: Array = []
var dragging_orb: LuminOrb = null
var highlighted_cell: ColorRect = null
var backlight_on: bool = false
var placed_orbs: int = 0
var move_history: Array = []
var orb_counts: Dictionary = {}

var ambient_player: AudioStreamPlayer
var place_sound: AudioStreamPlayer

func _ready() -> void:
	randomize()
	_initialize_managers()
	_setup_main_container()
	_initialize_lumin_orbs()
	_initialize_audio()
	_add_particle_effects()

func _process(delta: float) -> void:
	grid_manager.update_background_ambiance(Time.get_ticks_msec() / 1000.0)

func _initialize_managers() -> void:
	grid_manager = GridManager.new()
	add_child(grid_manager)
	
	ui_manager = UIManager.new()
	add_child(ui_manager)
	
	# Connect signals
	ui_manager.connect("backlight_toggled", Callable(self, "_on_backlight_toggled"))
	ui_manager.connect("undo_pressed", Callable(self, "_on_undo_pressed"))
	ui_manager.connect("reset_pressed", Callable(self, "_on_reset_pressed"))
	ui_manager.connect("theme_button_pressed", Callable(self, "_on_theme_button_pressed"))
	ui_manager.connect("save_pressed", Callable(self, "_save_arrangement"))
	ui_manager.connect("load_pressed", Callable(self, "_load_arrangement"))

func _setup_main_container() -> void:
	var main_container = HBoxContainer.new()
	main_container.size = get_viewport_rect().size
	add_child(main_container)

	var grid_container = grid_manager.initialize_grid()
	main_container.add_child(grid_container)

	var right_container = VBoxContainer.new()
	main_container.add_child(right_container)

	ui_manager.initialize_ui(right_container)

func _initialize_lumin_orbs() -> void:
	var orb_container = VBoxContainer.new()
	ui_manager.add_to_right_container(orb_container)

	for color in LuminOrb.COLORS:
		var hbox = HBoxContainer.new()
		orb_container.add_child(hbox)

		var orb = LuminOrb.new(color)
		hbox.add_child(orb)
		lumin_orbs.append(orb)

		ui_manager.create_piece_count_label(hbox, color)

		orb_counts[color] = INITIAL_ORB_COUNT
		ui_manager.update_piece_count(color, INITIAL_ORB_COUNT)
		
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_start_drag(event.global_position)
			else:
				_end_drag()
	elif event is InputEventMouseMotion and dragging_orb:
		dragging_orb.global_position = event.global_position - dragging_orb.size / 2
		var cell = grid_manager.get_cell_at_position(event.global_position)
		_update_grid_highlighting(cell)

func _try_start_drag(position: Vector2) -> void:
	for orb in lumin_orbs:
		if orb.get_global_rect().has_point(position):
			var color = orb.original_color
			if orb_counts[color] > 0:
				dragging_orb = orb.duplicate()
				dragging_orb.modulate = color
				add_child(dragging_orb)
				dragging_orb.global_position = position - dragging_orb.size / 2
			break

func _end_drag() -> void:
	if dragging_orb:
		var cell = grid_manager.get_cell_at_position(dragging_orb.global_position + dragging_orb.size / 2)
		if cell and cell.get_meta("available", true):
			_place_orb(cell, dragging_orb)
			ui_manager.provide_feedback("LuminOrb placed. Let it shine!")
			_play_place_sound()
		else:
			dragging_orb.queue_free()
			ui_manager.provide_feedback("This spot is already illuminated. Try another!", true)
		
		dragging_orb = null
		if highlighted_cell:
			grid_manager.unhighlight_cell(highlighted_cell)
		highlighted_cell = null

func _update_grid_highlighting(cell: ColorRect) -> void:
	if cell != highlighted_cell:
		if highlighted_cell:
			grid_manager.unhighlight_cell(highlighted_cell)
		if cell and cell.get_meta("available", true):
			grid_manager.highlight_cell(cell)
		highlighted_cell = cell

func _place_orb(cell: ColorRect, orb: LuminOrb) -> void:
	var snapped_position = cell.global_position + (cell.size - orb.size) / 2
	var tween = create_tween()
	tween.tween_property(orb, "global_position", snapped_position, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): 
		grid_manager.place_lumin_orb(cell, orb)
		placed_orbs += 1
		move_history.append({
			"orb": orb,
			"color": orb.original_color,
			"cell": cell
		})
		_animate_place_orb(orb)
		_update_orb_count(orb.original_color, -1)
		_update_glow_effects()
		grid_manager.blend_adjacent_colors()
	)

func _animate_place_orb(orb: LuminOrb) -> void:
	var tween = create_tween()
	tween.tween_property(orb, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(orb, "scale", Vector2(1.0, 1.0), 0.1)

func _update_orb_count(color: Color, delta: int) -> void:
	orb_counts[color] += delta
	ui_manager.update_piece_count(color, orb_counts[color])

func _update_glow_effects() -> void:
	for row in grid_manager.grid:
		for cell in row:
			var orb = cell.get_child(0) if cell.get_child_count() > 0 else null
			if orb is LuminOrb:
				if backlight_on:
					orb.apply_glow_effect()
				else:
					orb.remove_glow_effect()
	grid_manager.blend_adjacent_colors()

func _on_backlight_toggled() -> void:
	backlight_on = !backlight_on
	_update_glow_effects()

func _on_undo_pressed() -> void:
	if move_history.size() > 0:
		var last_move = move_history.pop_back()
		grid_manager.remove_lumin_orb(last_move["cell"])
		placed_orbs -= 1
		_update_orb_count(last_move["color"], 1)
		_update_glow_effects()
		ui_manager.provide_feedback("Step back taken. Feel free to try again!")

func _on_reset_pressed() -> void:
	grid_manager.reset_grid()
	placed_orbs = 0
	move_history.clear()
	for color in LuminOrb.COLORS:
		orb_counts[color] = INITIAL_ORB_COUNT
		ui_manager.update_piece_count(color, INITIAL_ORB_COUNT)
	_update_glow_effects()
	ui_manager.provide_feedback("Canvas cleared. Time for a fresh start!")

func _on_orb_drag_started(orb: LuminOrb) -> void:
	if orb_counts[orb.original_color] > 0:
		dragging_orb = orb.duplicate()
		add_child(dragging_orb)
		dragging_orb.global_position = orb.global_position
		dragging_orb.connect("drag_ended", Callable(self, "_on_orb_drag_ended"))

func _on_orb_drag_ended(orb: LuminOrb) -> void:
	if dragging_orb:
		var cell = grid_manager.get_cell_at_position(dragging_orb.global_position + dragging_orb.size / 2)
		if cell and cell.get_meta("available", true):
			_place_orb(cell, dragging_orb)
			ui_manager.provide_feedback("LuminOrb placed. Let it shine!")
			_play_place_sound()
		else:
			dragging_orb.queue_free()
			ui_manager.provide_feedback("This spot is already illuminated. Try another!", true)
		
		dragging_orb = null
		if highlighted_cell:
			grid_manager.unhighlight_cell(highlighted_cell)
		highlighted_cell = null

func _initialize_audio() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.stream = _create_placeholder_audio_stream()
	ambient_player.volume_db = -10
	ambient_player.play()
	add_child(ambient_player)

	place_sound = AudioStreamPlayer.new()
	place_sound.stream = _create_placeholder_audio_stream()
	place_sound.volume_db = -5
	add_child(place_sound)

func _create_placeholder_audio_stream() -> AudioStream:
	var audio_stream = AudioStreamGenerator.new()
	audio_stream.mix_rate = 44100
	audio_stream.buffer_length = 0.1
	return audio_stream

func _play_place_sound() -> void:
	if place_sound:
		place_sound.play()

func _add_particle_effects() -> void:
	var particles = CPUParticles2D.new()
	particles.amount = 50
	particles.lifetime = 20.0
	particles.texture = null
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.gravity = Vector2(0, -5)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 10.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 2.0
	particles.scale_amount_curve = null
	particles.color = Color(1, 1, 1, 0.1)  # Soft white color
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	add_child(particles)

func _on_theme_button_pressed() -> void:
	ui_manager.show_random_theme()

func _save_arrangement() -> void:
	var save_data = {
		"grid": [],
		"orb_counts": orb_counts,
		"backlight_on": backlight_on
	}
	for row in grid_manager.grid:
		for cell in row:
			var orb = cell.get_child(0) if cell.get_child_count() > 0 else null
			if orb is LuminOrb:
				save_data["grid"].append({
					"position": cell.get_meta("grid_pos"),
					"color": orb.original_color
				})
	
	var file = FileAccess.open("user://lumin_orb_arrangement.save", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()
	ui_manager.provide_feedback("LuminOrb arrangement saved!")

func _load_arrangement() -> void:
	if FileAccess.file_exists("user://lumin_orb_arrangement.save"):
		var file = FileAccess.open("user://lumin_orb_arrangement.save", FileAccess.READ)
		var save_data = file.get_var()
		file.close()
		
		_on_reset_pressed()  # Clear the current arrangement
		
		for orb_data in save_data["grid"]:
			var cell = grid_manager.grid[orb_data["position"].y][orb_data["position"].x]
			var orb = LuminOrb.new(orb_data["color"])
			_place_orb(cell, orb)
		
		orb_counts = save_data["orb_counts"]
		ui_manager.update_all_piece_counts(orb_counts)
		
		backlight_on = save_data["backlight_on"]
		ui_manager.update_backlight_button(backlight_on)
		
		_update_glow_effects()
		grid_manager.blend_adjacent_colors()
		ui_manager.provide_feedback("LuminOrb arrangement loaded!")
	else:
		ui_manager.provide_feedback("No saved arrangement found.", true)
