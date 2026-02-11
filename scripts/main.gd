extends Control

var servers := {}

var socket: StreamPeerTCP

var username := "User"
var target_host := "127.0.0.1"
var target_port := 8765

var users: PackedStringArray = []

var server_info: Dictionary = {}
var server_icon: Texture2D = preload("res://assets/textures/server_icon_default.svg")

var is_logged_in := false

var last_ping := 0.0

signal connected
signal disconnected
signal server_info_updated

func _ready() -> void:
	username += str(randi())

	load_server_list()

func connect_to_server(host: String = "127.0.0.1", port: int=8765):
	socket = StreamPeerTCP.new()
	var err = socket.connect_to_host(host, port)
	socket.set_no_delay(true)

	if err != OK:
		print_out("[color=red]Error connecting to server! %s[/color]" % error_string(err))
		return

func print_out(text: String, end="\n") -> void:
	%ChatText.append_text(text + end)

var ping_timer: float = 0.0

func _process(delta: float) -> void:
	if not socket: return
	socket.poll()
	update_status()

	if socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		while true:
			var msg := recv_json()
			if msg.is_empty():
				break
			handle_message(msg)

	if is_logged_in:
		ping_timer += delta

		if ping_timer > 1.0:
			send_json({
				"type": "ping"
			})
			ping_timer = 0.0

func handle_message(msg: Dictionary) -> void:
	match msg.get("type"):
		"request":
			match msg["body"]:
				"username":
					send_json({
						"type": "response",
						"body": username
					})
				"auth":
					$AuthPopup.show()
					GLOBAL.playsound(preload("res://assets/sounds/join.wav"))
		"users":
			is_logged_in = true
			connected.emit()
			users = msg.get("users", [])
			update_userlist()
			GLOBAL.playsound(preload("res://assets/sounds/connect.wav"))
		"message":
			if username == msg["user"]:
				print_out("<YOU> %s" % msg["body"])
				GLOBAL.playsound(preload("res://assets/sounds/send_done.wav"))
			else:
				print_out("<%s> %s" % [msg["user"], msg["body"]])
				GLOBAL.playsound(preload("res://assets/sounds/receive.wav"))
		"join":
			var user = msg.get("user")
			print_out("[color=gray]>>> %s joined[/color]" % msg["user"])
			if user and not users.has(user):
				users.append(user)
			update_userlist()
			GLOBAL.playsound(preload("res://assets/sounds/join.wav"))
		"leave":
			var user = msg.get("user")
			print_out("[color=gray]>>> %s left[/color]" % msg["user"])
			if user and users.has(user):
				users.erase(user)
			update_userlist()
			GLOBAL.playsound(preload("res://assets/sounds/leave.wav"))
		"motd":
			%ChatText.add_hr()
			%ChatText.newline()
			%ChatText.add_image(server_icon, 64, 64)
			%ChatText.append_text("   [font_size=30px]%s[/font_size]" % server_info["name"])
			%ChatText.newline()
			print_out(msg.get("body"))
			%ChatText.add_hr()
			%ChatText.newline()
		"error":
			print_out("[color=red]Error! %s[/color]" % msg.get("body"))
			GLOBAL.playsound(preload("res://assets/sounds/leave.wav"))
		"success":
			print_out("[color=green]%s[/color]" % msg.get("body"))
			GLOBAL.playsound(preload("res://assets/sounds/join.wav"))
		"ping":
			var now = Time.get_unix_time_from_system()
			update_status()
			last_ping = snappedf((msg.get("body") - now), 0.1)
		"server_info":
			server_info = msg
			server_info_updated.emit()
			var icon = msg.get("icon")
			if icon:
				server_icon = load_server_icon(server_info["icon"])
			DisplayServer.window_set_title("GIchat Client - " + server_info["name"])

func update_status():
	match socket.get_status():
			StreamPeerTCP.STATUS_NONE:
				%StatusLabel.text = "[color=red]Not connected to a server[/color]"
				%ConnectionButton.text = "Connect"
				%ConnectionButton.disabled = false
			StreamPeerTCP.STATUS_CONNECTING:
				%StatusLabel.text = "[color=yellow]Connecting to server...[/color]"
				%ConnectionButton.disabled = true
			StreamPeerTCP.STATUS_CONNECTED:
				%StatusLabel.text = ""
				var host = socket.get_connected_host()
				var port = socket.get_connected_port()
				%StatusLabel.append_text("[color=green]Connected to %s[/color] " % server_info.get("name", "%s:%d" % [host, port]))
				%StatusLabel.add_image(server_icon, 16, 16)
				%StatusLabel.append_text("\nPing:%smsec" % last_ping)
				%ConnectionButton.text = "Disconnect"
				%ConnectionButton.disabled = false
			StreamPeerTCP.STATUS_ERROR:
				%StatusLabel.text = "[color=red]Error connecting to server![/color]"
				%ConnectionButton.text = "Connect"
				%ConnectionButton.disabled = false

func update_userlist():
	%UserList.clear()
	for user in users:
		if user == username:
			user += " (YOU)"
		%UserList.add_item(user)

func _on_connection_button_pressed() -> void:
	if not socket:
		print_out("[color=red]No server selected![/color]")
		return
	if socket.get_status() == 2:
		disconnect_from_server()
	elif socket.get_status() == 0:
		connect_to_server(target_host, target_port)
		update_status()

func send(message: String) -> void:
	var data = {
		"type": "message",
		"user": username,
		"body": message
	}
	send_json(data)
	%TextInput.text = ""

	GLOBAL.playsound(preload("res://assets/sounds/send.wav"))

func recv_line() -> String:
	var data := ""

	while "\n" not in data:
		var result = socket.get_partial_data(1024)
		var err = result[0]
		var chunk: PackedByteArray = result[1]

		if err != OK:
			return ""

		if chunk.size() == 0:
			return ""

		data += chunk.get_string_from_utf8()

	return data.strip_edges()

func send_json(data: Dictionary) -> void:
	var json = JSON.stringify(data)
	var err = socket.put_data((json + "\n").to_utf8_buffer())
	if err != OK:
		push_error("Error sending packet: ", error_string(err))

var recv_buffer := ""

func recv_json() -> Dictionary:
	while true:
		if "\n" in recv_buffer:
			var line := recv_buffer.split("\n", false, 1)[0]
			recv_buffer = recv_buffer.substr(line.length() + 1)

			var parsed = JSON.parse_string(line)
			return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

		var result = socket.get_partial_data(1024)
		if result[0] != OK:
			return {}

		if result[1].size() == 0:
			return {}

		recv_buffer += result[1].get_string_from_utf8()
	return {}

func _on_clear_button_pressed() -> void:
	%ChatText.text = ""

func disconnect_from_server():
	if not socket: return
	if not socket.get_status() == StreamPeerTCP.STATUS_CONNECTED: return
	socket.disconnect_from_host()
	users = []
	update_userlist()
	GLOBAL.playsound(preload("res://assets/sounds/disconnect.wav"))
	is_logged_in = false
	update_status()
	disconnected.emit()

func save_server():
	if not is_logged_in:
		print_out("[color=red]Not connected to a server![/color]")
		return
	var data = {
		"name": server_info["name"],
		"description": server_info["description"],
		"addr": server_info["addr"],
		"port": int(server_info["port"])
	}
	servers[server_info["name"]] = data

	%ServerList.add_item(server_info["name"], server_icon)
	print_out("Saved server %s" % server_info["name"])

func add_server(addr: String, port: int):
	var data = {
		"name": "",
		"description": "",
		"addr": addr,
		"port": port
	}

	connect_to_server(addr, port)
	await server_info_updated

	$AddServerPopup.hide()

	var server_name = server_info["name"]
	data["name"] = server_name
	data["description"] = server_info["description"]

	server_icon = load_server_icon(server_info["icon"])

	servers[server_name] = data
	%ServerList.add_item(server_name, server_icon)

func load_server_icon(b64: String):
	var bytes = Marshalls.base64_to_raw(b64)
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return

	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://icons"))
	img.save_png("user://icons/%s_icon.png" % server_info["name"])

	return ImageTexture.create_from_image(img)

func add_server_from_list(addr: String, port: int, server_name: String, icon: Texture2D, server_desc: String):
	var data = {
		"name": server_name,
		"description": server_desc,
		"addr": addr,
		"port": port
	}
	servers[server_name] = data

	%ServerList.add_item(server_name, icon)

func save_server_list():
	var cfg = ConfigFile.new()

	for server in servers.keys():
		cfg.set_value(servers[server]["name"], "addr", servers[server]["addr"])
		cfg.set_value(servers[server]["name"], "port", servers[server]["port"])
		cfg.set_value(servers[server]["name"], "desc", servers[server]["description"])

	var err = cfg.save("user://server_list.ini")

	if err != OK:
		GLOBAL.create_notification("Error saving server list! %s" % error_string(err), Color.RED)
	else:
		print("saved server list")

func load_server_list():
	var cfg = ConfigFile.new()

	var err = cfg.load("user://server_list.ini")

	for server in cfg.get_sections():
		var addr = cfg.get_value(server, "addr")
		var port = cfg.get_value(server, "port")
		var desc = cfg.get_value(server, "desc", "")
		var img = Image.load_from_file("user://icons/%s_icon.png" % server)
		var texture := ImageTexture.create_from_image(img)
		add_server_from_list(addr, port, server, texture, desc)

	if err != OK:
		GLOBAL.create_notification("Error loading server list! %s" % error_string(err), Color.RED)

func _on_server_list_item_activated(index: int) -> void:
	disconnect_from_server()
	var server_name = %ServerList.get_item_text(index)
	target_host = servers[server_name]["addr"]
	target_port = servers[server_name]["port"]
	connect_to_server(target_host, target_port)

func _on_save_server_button_pressed() -> void:
	save_server()
	save_server_list()

func _on_add_server_button_pressed() -> void:
	$AddServerPopup.show()

func _on_settings_button_pressed() -> void:
	$SettingsPopup.show()
