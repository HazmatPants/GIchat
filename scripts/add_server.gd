extends Control

@onready var addr_input: LineEdit = $MarginContainer/VBoxContainer/LineEditAddr
@onready var port_input: LineEdit = $MarginContainer/VBoxContainer/LineEditPort

func _on_ok_button_pressed() -> void:
	if not port_input.text.is_valid_int():
		owner.print_out("[color=red]Port must be an integer![/color]")
		return
	owner.add_server(addr_input.text, port_input.text.to_int())
	addr_input.clear()
	port_input.clear()

func _on_cancel_button_pressed() -> void:
	hide()
	addr_input.clear()
	port_input.clear()
