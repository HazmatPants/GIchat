extends Control

@onready var username_input := $MarginContainer/VBoxContainer/LineEditUser
@onready var password_input := $MarginContainer/VBoxContainer/LineEditPass
@onready var password2_input := $MarginContainer/VBoxContainer/LineEditPass2

func _on_ok_button_pressed() -> void:
	if password_input.text == password2_input.text:
		owner.username = username_input.text
		owner.send_json({
			"type": "auth",
			"user": username_input.text,
			"pass": password_input.text
		})
		hide()
		username_input.clear()
		password_input.clear()
		password2_input.clear()
	else:
		owner.print_out("[color=red]Passwords do not match![/color]")

func _on_cancel_button_pressed() -> void:
	hide()
	username_input.clear()
	password_input.clear()
	password2_input.clear()
