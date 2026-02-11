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
	cfg.set_value("audio", "volume", %VolumeSlider.value)

	return cfg.save("user://settings.ini")

func load_settings():
	var err = cfg.load("user://settings.ini")

	if err != OK:
		GLOBAL.create_notification("Error loading settings! %s" % error_string(err), Color.RED)

	%UsernameField.text = cfg.get_value("user", "username", "")
	owner.username = %UsernameField.text

	%VolumeSlider.value = cfg.get_value("audio", "volume", 0.5)
	AudioServer.set_bus_volume_linear(0, %VolumeSlider.value)

func _on_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value)
	save_settings()
