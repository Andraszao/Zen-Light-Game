extends TextureRect
class_name LuminOrb

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

var original_color: Color
var is_dragging: bool = false
var start_position: Vector2

signal drag_started(orb: LuminOrb)
signal drag_ended(orb: LuminOrb)

func _init(color: Color = COLORS[randi() % COLORS.size()]) -> void:
	custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	texture = _create_circle_texture(color)
	modulate = color
	original_color = color
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("original_color", color)

func _create_circle_texture(color: Color) -> ImageTexture:
	var image = Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0)) # Transparent background
	
	for x in range(CELL_SIZE):
		for y in range(CELL_SIZE):
			var dist = Vector2(x - CELL_SIZE/2, y - CELL_SIZE/2).length()
			if dist <= CELL_SIZE / 2:
				var alpha = 1.0 - smoothstep(CELL_SIZE / 2 - 5, CELL_SIZE / 2, dist)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	return ImageTexture.create_from_image(image)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				end_drag()
	elif event is InputEventMouseMotion and is_dragging:
		position += event.relative

func start_drag() -> void:
	is_dragging = true
	start_position = position
	modulate = original_color.lightened(0.2) # Slightly lighter when dragging
	scale = Vector2(1.1, 1.1) # Slightly larger when dragging
	emit_signal("drag_started", self)

func end_drag() -> void:
	is_dragging = false
	modulate = original_color
	scale = Vector2(1.0, 1.0)
	emit_signal("drag_ended", self)

func apply_glow_effect() -> void:
	var glow = TextureRect.new()
	glow.name = "Glow"
	glow.texture = _create_organic_glow_texture(original_color, int(size.x * 3))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.size = size * 3
	glow.position = -size
	glow.modulate.a = 0.5
	glow.z_index = -1
	
	add_child(glow)
	
	var glow_tween = create_tween()
	glow_tween.tween_property(glow, "modulate:a", 0.7, 0.2)
	glow_tween.tween_property(glow, "modulate:a", 0.5, 0.8)
	glow_tween.set_loops()

func remove_glow_effect() -> void:
	var glow = get_node_or_null("Glow")
	if glow:
		glow.queue_free()

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

func pulse() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)
	tween.set_loops()
