extends Control

@onready var label = $RichTextLabel

func show_info(server_name: String, server_desc: String):
	label.text = ""

	label.append_text("[font_size=24px]%s[/font_size]" % server_name)

	var img = Image.load_from_file("user://icons/%s_icon.png" % server_name)
	var texture := ImageTexture.create_from_image(img)

	label.newline()
	label.add_image(texture)
	label.newline()

	label.append_text(server_desc)

	show()

func _on_ok_button_pressed() -> void:
	hide()
