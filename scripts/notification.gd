extends Control
class_name Notification

var dismiss_timer := 0.0

var start_pos := Vector2.ZERO
var target_pos := Vector2.ZERO

func create(text: String, text_color: Color=Color.WHITE):
	var panel = Panel.new()

	var stylebox = preload("res://assets/tres/stylebox.tres")
	panel.add_theme_stylebox_override("panel", stylebox)

	add_child(panel)
	panel.size.y = 60

	var label = Label.new()
	label.text = text
	label.modulate = text_color
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)

	panel.size.x += label.size.x + 32
	panel.position = -panel.size / 2

	return self

func _ready() -> void:
	GLOBAL.playsound(preload("res://assets/sounds/notification.wav"))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	position.y = -100
	start_pos = position
	target_pos = position
	target_pos.y = 50

func _process(delta: float) -> void:
	dismiss_timer += delta

	if dismiss_timer > 2.0:
		position = position.lerp(start_pos, 0.2)
	else:
		position = position.lerp(target_pos, 0.2)

	if dismiss_timer > 3.0:
		queue_free()
