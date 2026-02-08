extends TextEdit

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ENTER:
			if event.pressed and not event.echo:
				if text.strip_edges():
					owner.send(text)
			else:
				text = text.strip_edges()
