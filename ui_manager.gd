extends Node
class_name UIManager

signal backlight_toggled
signal undo_pressed
signal reset_pressed
signal theme_button_pressed
signal save_pressed
signal load_pressed

var backlight_button: Button
var undo_button: Button
var reset_button: Button
var piece_count_labels: Dictionary = {}
var right_container: VBoxContainer

func initialize_ui(container: Control) -> void:
	right_container = container
	_initialize_ui_buttons()
	_add_theme_button()
	_add_save_load_buttons()

func _initialize_ui_buttons() -> void:
	backlight_button = _create_ui_button("Backlight: Off", "_on_backlight_toggled")
	undo_button = _create_ui_button("Undo", "_on_undo_pressed")
	reset_button = _create_ui_button("Reset", "_on_reset_pressed")
	
	right_container.add_child(backlight_button)
	right_container.add_child(backlight_button)
	right_container.add_child(undo_button)
	right_container.add_child(reset_button)

func _create_ui_button(text: String, callback: String) -> Button:
	var button = Button.new()
	button.text = text
	button.connect("pressed", Callable(self, callback))
	return button

func _add_theme_button() -> void:
	var theme_button = _create_ui_button("Get Theme Idea", "_on_theme_button_pressed")
	right_container.add_child(theme_button)

func _add_save_load_buttons() -> void:
	var save_button = _create_ui_button("Save Arrangement", "_on_save_pressed")
	var load_button = _create_ui_button("Load Arrangement", "_on_load_pressed")
	right_container.add_child(save_button)
	right_container.add_child(load_button)

func create_piece_count_label(container: HBoxContainer, color: Color) -> void:
	var count_label = Label.new()
	container.add_child(count_label)
	piece_count_labels[color] = count_label

func update_piece_count(color: Color, count: int) -> void:
	if color in piece_count_labels:
		piece_count_labels[color].text = str(count)

func update_all_piece_counts(counts: Dictionary) -> void:
	for color in counts:
		update_piece_count(color, counts[color])

func _on_backlight_toggled() -> void:
	emit_signal("backlight_toggled")
	backlight_button.text = "Backlight: " + ("On" if backlight_button.text == "Backlight: Off" else "Off")

func _on_undo_pressed() -> void:
	emit_signal("undo_pressed")

func _on_reset_pressed() -> void:
	emit_signal("reset_pressed")

func _on_theme_button_pressed() -> void:
	emit_signal("theme_button_pressed")

func _on_save_pressed() -> void:
	emit_signal("save_pressed")

func _on_load_pressed() -> void:
	emit_signal("load_pressed")

func show_random_theme() -> void:
	var themes = [
		"Create a sunset scene",
		"Design a starry night",
		"Craft a soothing forest glade",
		"Build a cozy campfire",
		"Paint a serene ocean view"
	]
	var random_theme = themes[randi() % themes.size()]
	provide_feedback("Theme idea: " + random_theme)

func provide_feedback(message: String, is_error: bool = false) -> void:
	var feedback_label = Label.new()
	feedback_label.text = message
	feedback_label.modulate = Color(0.9, 0.9, 1.0) if not is_error else Color(1.0, 0.8, 0.8)
	add_child(feedback_label)
	
	feedback_label.anchor_bottom = 1.0
	feedback_label.anchor_top = 1.0
	feedback_label.anchor_left = 0.0
	feedback_label.anchor_right = 1.0
	feedback_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	feedback_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	feedback_label.custom_minimum_size.y = 40
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var tween = create_tween()
	tween.tween_property(feedback_label, "modulate:a", 0, 2)
	tween.tween_callback(feedback_label.queue_free)

func add_to_right_container(node: Control) -> void:
	right_container.add_child(node)

func update_backlight_button(is_on: bool) -> void:
	backlight_button.text = "Backlight: " + ("On" if is_on else "Off")
