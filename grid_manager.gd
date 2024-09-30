extends Node
class_name GridManager

const GRID_SIZE: int = 10
const CELL_SIZE: int = 50

var grid: Array = []

signal cell_highlighted(cell: ColorRect)
signal cell_unhighlighted(cell: ColorRect)

func initialize_grid() -> GridContainer:
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

func get_cell_at_position(pos: Vector2) -> ColorRect:
	for row in grid:
		for cell in row:
			if cell.get_global_rect().has_point(pos):
				return cell
	return null

func highlight_cell(cell: ColorRect) -> void:
	if cell and cell.get_meta("available", true):
		create_tween().tween_property(cell, "modulate", Color(1.2, 1.2, 1.2), 0.1)
		emit_signal("cell_highlighted", cell)

func unhighlight_cell(cell: ColorRect) -> void:
	create_tween().tween_property(cell, "modulate", Color(1, 1, 1), 0.1)
	emit_signal("cell_unhighlighted", cell)

func place_lumin_orb(cell: ColorRect, lumin_orb: LuminOrb) -> void:
	cell.add_child(lumin_orb)
	cell.set_meta("available", false)
	_update_cell_color(cell, lumin_orb.original_color)

func remove_lumin_orb(cell: ColorRect) -> void:
	for child in cell.get_children():
		child.queue_free()
	cell.set_meta("available", true)
	_update_cell_color(cell, Color(0.1, 0.1, 0.1))

func _update_cell_color(cell: ColorRect, color: Color) -> void:
	var tween = create_tween()
	tween.tween_property(cell, "color", color.darkened(0.7), 0.3)

func update_background_ambiance(time: float) -> void:
	var day_color = Color(0.95, 0.95, 1.0)
	var night_color = Color(0.1, 0.1, 0.2)
	var t = (sin(time * 0.1) + 1) / 2
	var background_color = day_color.lerp(night_color, t)
	
	for row in grid:
		for cell in row:
			if cell.get_meta("available"):
				cell.color = cell.color.lerp(background_color, 0.05)

func blend_adjacent_colors() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = grid[y][x]
			var lumin_orb = cell.get_child(0) if cell.get_child_count() > 0 else null
			if lumin_orb is LuminOrb:
				var blended_color = lumin_orb.modulate
				var count = 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE:
							var neighbor = grid[ny][nx].get_child(0) if grid[ny][nx].get_child_count() > 0 else null
							if neighbor is LuminOrb:
								blended_color += neighbor.modulate
								count += 1
				blended_color /= count
				lumin_orb.modulate = lumin_orb.modulate.lerp(blended_color, 0.3)
				_update_cell_color(cell, blended_color)

func reset_grid() -> void:
	for row in grid:
		for cell in row:
			remove_lumin_orb(cell)
