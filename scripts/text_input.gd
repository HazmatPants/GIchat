extends TextEdit

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ENTER:
			if event.pressed and not event.echo:
				if event.shift_pressed:
					text += "\n"
					return
				if text.strip_edges():
					owner.send(text)
			elif not event.shift_pressed:
				text = text.strip_edges()
