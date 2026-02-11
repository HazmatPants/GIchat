extends Control

var cfg := ConfigFile.new()

func _ready() -> void:
	await owner.ready

	load_settings()

func _on_connected():
	%UsernameField.editable = false

func _on_disconnected() -> void:
	%UsernameField.editable = true
 
func _on_settings_close_button_pressed() -> void:
	if %UsernameField.text:
		hide()
		var err = save_settings()
		if err != OK:
			GLOBAL.create_notification("Error saving settings! %s" % error_string(err), Color.RED)
		else:
			GLOBAL.create_notification("Settings saved")
	else:
		GLOBAL.create_notification("Set username!", Color.RED)

	load_settings()

func save_settings() -> Error:
	owner.username = %UsernameField.text
	cfg.set_value("user", "username", owner.username)

	return cfg.save("user://settings.ini")

func load_settings():
	var err = cfg.load("user://settings.ini")

	if err != OK:
		GLOBAL.create_notification("Error loading settings! %s" % error_string(err), Color.RED)

	%UsernameField.text = cfg.get_value("user", "username", "")
	owner.username = %UsernameField.text
