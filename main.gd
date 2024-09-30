extends Control

const GRID_SIZE: int = 10
const CELL_SIZE: int = 50
const COLORS: Array = [
	Color.RED,
	Color.ORANGE,
	Color.YELLOW,
	Color.GREEN,
	Color.BLUE,
	Color.INDIGO,
	Color.VIOLET
]
const INITIAL_PIECE_COUNT: int = 5

var grid: Array = []
var light_pieces: Array = []
var dragging_piece: TextureRect = null
var original_position: Vector2
var backlight_on: bool = false
var placed_lights: int = 0
var max_backlight_intensity: float = 1.0
var move_history: Array = []
var piece_counts: Dictionary = {}

var ui_manager: Node
var highlighted_cell: ColorRect = null

var ambient_player: AudioStreamPlayer
var place_sound: AudioStreamPlayer

func _ready() -> void:
	ui_manager = preload("res://ui_manager.gd").new()
	add_child(ui_manager)

	var main_container = HBoxContainer.new()
	main_container.size = get_viewport_rect().size
	add_child(main_container)

	var grid_container = _initialize_grid()
	main_container.add_child(grid_container)

	var right_container = VBoxContainer.new()
	main_container.add_child(right_container)

	_initialize_light_pieces(right_container)
	ui_manager.initialize_ui(right_container)
	_update_all_glows()
	_initialize_audio()
	_add_particle_effects()

	ui_manager.connect("backlight_toggled", Callable(self, "_on_backlight_toggled"))
	ui_manager.connect("undo_pressed", Callable(self, "_on_undo_pressed"))
	ui_manager.connect("reset_pressed", Callable(self, "_on_reset_pressed"))
	ui_manager.connect("theme_button_pressed", Callable(self, "_on_theme_button_pressed"))
	ui_manager.connect("save_pressed", Callable(self, "_save_arrangement"))
	ui_manager.connect("load_pressed", Callable(self, "_load_arrangement"))

func _process(delta: float) -> void:
	_update_background_ambiance(Time.get_ticks_msec() / 1000.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_process_mouse_button_event(event)
	elif event is InputEventMouseMotion:
		_process_mouse_motion_event(event)

func _initialize_grid() -> Control:
	var grid_container = GridContainer.new()
	grid_container.columns = GRID_SIZE
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var total_size = CELL_SIZE * GRID_SIZE
	grid_container.custom_minimum_size = Vector2(total_size, total_size)
	
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			var cell = _create_grid_cell()
			cell.set_meta("grid_pos", Vector2(x, y))
			cell.set_meta("available", true)
			grid_container.add_child(cell)
			row.append(cell)
		grid.append(row)
	
	return grid_container

func _create_grid_cell() -> ColorRect:
	var cell = ColorRect.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.color = Color(0.1, 0.1, 0.1)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	return cell

func _initialize_light_pieces(container: Control) -> void:
	var piece_container = VBoxContainer.new()
	container.add_child(piece_container)

	for color in COLORS:
		var hbox = HBoxContainer.new()
		piece_container.add_child(hbox)

		var piece = _create_light_piece(color)
		hbox.add_child(piece)
		light_pieces.append(piece)

		var count_label = ui_manager.create_piece_count_label(hbox)

		piece_counts[color] = INITIAL_PIECE_COUNT
		ui_manager.update_piece_count(color, INITIAL_PIECE_COUNT)

func _create_light_piece(color: Color) -> TextureRect:
	var piece = TextureRect.new()
	piece.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	piece.texture = _create_circle_texture(color)
	piece.modulate = color.darkened(0.5)
	piece.set_meta("original_color", color)
	piece.mouse_filter = Control.MOUSE_FILTER_STOP
	return piece

func _create_circle_texture(color: Color) -> ImageTexture:
	var image = Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	for x in range(CELL_SIZE):
		for y in range(CELL_SIZE):
			var dist = Vector2(x - CELL_SIZE/2, y - CELL_SIZE/2).length()
			if dist <= CELL_SIZE / 2:
				image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

func _process_mouse_button_event(event: InputEventMouseButton) -> void:
	if event.pressed and dragging_piece == null:
		_start_drag(event.position)
	elif dragging_piece != null and not event.pressed:
		_end_drag()

func _process_mouse_motion_event(event: InputEventMouseMotion) -> void:
	if dragging_piece != null:
		dragging_piece.global_position = event.global_position - dragging_piece.size / 2
		
		var cell = _get_cell_at_position(event.global_position)
		_update_grid_highlighting(cell)

func _update_grid_highlighting(cell: ColorRect) -> void:
	if cell != highlighted_cell:
		if highlighted_cell:
			_unhighlight_cell(highlighted_cell)
		if cell and cell.get_meta("available", true):
			_highlight_cell(cell)
		highlighted_cell = cell

func _highlight_cell(cell: ColorRect) -> void:
	create_tween().tween_property(cell, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _unhighlight_cell(cell: ColorRect) -> void:
	create_tween().tween_property(cell, "modulate", Color(1, 1, 1), 0.1)

func _get_cell_at_position(pos: Vector2) -> ColorRect:
	for row in grid:
		for cell in row:
			if cell.get_global_rect().has_point(pos):
				return cell
	return null

func _start_drag(position: Vector2) -> void:
	for piece in light_pieces:
		if piece.get_global_rect().has_point(position):
			var color = piece.get_meta("original_color")
			if piece_counts[color] > 0:
				dragging_piece = piece.duplicate()
				dragging_piece.modulate = color
				dragging_piece.set_meta("original_color", color)
				add_child(dragging_piece)
				dragging_piece.global_position = position - dragging_piece.size / 2
				original_position = piece.global_position
			break

func _end_drag() -> void:
	if dragging_piece:
		var cell = _get_cell_at_position(dragging_piece.global_position + dragging_piece.size / 2)
		if cell and cell.get_meta("available", true):
			var snapped_position = cell.global_position + (cell.size - dragging_piece.size) / 2
			dragging_piece.global_position = snapped_position
			_place_piece(cell, dragging_piece)
			ui_manager.provide_feedback("Light placed. Let it shine!")
			_play_place_sound()
		else:
			_return_piece(dragging_piece)
			ui_manager.provide_feedback("This spot is already illuminated. Try another!", true)
		
		dragging_piece.queue_free()
		dragging_piece = null
		if highlighted_cell:
			_unhighlight_cell(highlighted_cell)
		highlighted_cell = null

func _place_piece(cell: ColorRect, piece: TextureRect) -> void:
	var new_piece = piece.duplicate()
	new_piece.position = Vector2.ZERO
	cell.add_child(new_piece)
	cell.set_meta("available", false)
	
	placed_lights += 1
	move_history.append({
		"piece": new_piece,
		"color": new_piece.get_meta("original_color"),
		"cell": cell
	})
	_animate_place_light(new_piece)
	_update_piece_count(new_piece.get_meta("original_color"), -1)

func _return_piece(piece: TextureRect) -> void:
	var color = piece.get_meta("original_color")
	_animate_return_piece(piece)

func _update_piece_count(color: Color, delta: int) -> void:
	piece_counts[color] += delta
	ui_manager.update_piece_count(color, piece_counts[color])

func _animate_place_light(piece: TextureRect) -> void:
	var tween = create_tween()
	tween.tween_property(piece, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(piece, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_callback(_apply_organic_glow_effect.bind(piece))

func _animate_return_piece(piece: TextureRect) -> void:
	var tween = create_tween()
	tween.tween_property(piece, "global_position", original_position, 0.2)
	tween.tween_callback(piece.queue_free)

func _on_backlight_toggled() -> void:
	backlight_on = !backlight_on
	_update_all_glows()

func _update_all_glows() -> void:
	for row in grid:
		for cell in row:
			var piece = cell.get_child(0) if cell.get_child_count() > 0 else null
			if piece is TextureRect:
				var glow = cell.get_node_or_null("Glow")
				if backlight_on and not glow:
					_apply_organic_glow_effect(piece)
				elif not backlight_on and glow:
					glow.queue_free()
	_blend_adjacent_colors()

func _apply_organic_glow_effect(piece: TextureRect) -> void:
	var cell = piece.get_parent()
	var glow = TextureRect.new()
	glow.name = "Glow"
	glow.texture = _create_organic_glow_texture(piece.get_meta("original_color"), int(cell.size.x * 3))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.size = cell.size * 3
	glow.position = -cell.size
	glow.modulate.a = 0.5
	glow.z_index = -1
	
	cell.add_child(glow)
	
	var glow_tween = create_tween()
	glow_tween.tween_property(glow, "modulate:a", 0.7, 0.2)
	glow_tween.tween_property(glow, "modulate:a", 0.5, 0.8)
	glow_tween.set_loops()

func _on_undo_pressed() -> void:
	if move_history.size() > 0:
		var last_move = move_history.pop_back()
		var cell = last_move["cell"]
		for child in cell.get_children():
			child.queue_free()
		cell.set_meta("available", true)
		placed_lights -= 1
		_update_piece_count(last_move["color"], 1)
		_update_all_glows()
		ui_manager.provide_feedback("Step back taken. Feel free to try again!")

func _on_reset_pressed() -> void:
	for row in grid:
		for cell in row:
			for child in cell.get_children():
				child.queue_free()
			cell.set_meta("available", true)
	placed_lights = 0
	move_history.clear()
	for color in COLORS:
		piece_counts[color] = INITIAL_PIECE_COUNT
		ui_manager.update_piece_count(color, INITIAL_PIECE_COUNT)
	_update_all_glows()
	ui_manager.provide_feedback("Canvas cleared. Time for a fresh start!")

func _create_organic_glow_texture(color: Color, size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center = Vector2(size / 2, size / 2)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = 1.0 - smoothstep(0, size / 2, dist)
			var pixel_color = color
			pixel_color.a = alpha * 0.7  # Softer glow
			image.set_pixel(x, y, pixel_color)
	
	return ImageTexture.create_from_image(image)

func _update_background_ambiance(time: float) -> void:
	var day_color = Color(0.95, 0.95, 1.0)
	var night_color = Color(0.1, 0.1, 0.2)
	var t = (sin(time * 0.1) + 1) / 2  # Oscillate between 0 and 1, slower cycle
	var background_color = day_color.lerp(night_color, t)
	
	for row in grid:
		for cell in row:
			cell.color = cell.color.lerp(background_color, 0.05)  # Smooth transition

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
	else:
		print("Place sound effect played")  # Fallback for debugging

func _on_theme_button_pressed() -> void:
	ui_manager.show_random_theme()

func _blend_adjacent_colors() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = grid[y][x]
			var piece = cell.get_child(0) if cell.get_child_count() > 0 else null
			if piece is TextureRect:
				var blended_color = piece.modulate
				var count = 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE:
							var neighbor = grid[ny][nx].get_child(0) if grid[ny][nx].get_child_count() > 0 else null
							if neighbor is TextureRect:
								blended_color += neighbor.modulate
								count += 1
				blended_color /= count
				piece.modulate = piece.modulate.lerp(blended_color, 0.3)

func _save_arrangement() -> void:
	var save_data = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = grid[y][x]
			var piece = cell.get_child(0) if cell.get_child_count() > 0 else null
			if piece is TextureRect:
				save_data.append({
					"position": Vector2(x, y),
					"color": piece.get_meta("original_color")
				})
	
	var file = FileAccess.open("user://light_arrangement.save", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()
	ui_manager.provide_feedback("Light arrangement saved!")

func _load_arrangement() -> void:
	if FileAccess.file_exists("user://light_arrangement.save"):
		var file = FileAccess.open("user://light_arrangement.save", FileAccess.READ)
		var save_data = file.get_var()
		file.close()
		
		_on_reset_pressed()  # Clear the current arrangement
		
		for light_data in save_data:
			var cell = grid[light_data["position"].y][light_data["position"].x]
			var piece = _create_light_piece(light_data["color"])
			_place_piece(cell, piece)
		
		_update_all_glows()
		ui_manager.provide_feedback("Light arrangement loaded!")
	else:
		ui_manager.provide_feedback("No saved arrangement found.", true)
