extends Control

var servers := {}

var socket: StreamPeerTCP

var username := "User"

var users: PackedStringArray = []

var server_info: Dictionary = {}
var server_icon: Texture2D = preload("res://assets/textures/server_icon_default.svg")

var is_logged_in := false

var last_ping := 0.0

signal connected

func _ready() -> void:
	username += str(randi())
	connect_to_server()

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
					playsound(preload("res://assets/sounds/join.wav"))
		"users":
			is_logged_in = true
			connected.emit()
			users = msg.get("users", [])
			update_userlist()
			playsound(preload("res://assets/sounds/connect.wav"))
		"message":
			if username == msg["user"]:
				print_out("<YOU> %s" % msg["body"])
				playsound(preload("res://assets/sounds/send.wav"))
			else:
				print_out("<%s> %s" % [msg["user"], msg["body"]])
				playsound(preload("res://assets/sounds/receive.wav"))
		"join":
			var user = msg.get("user")
			print_out("[color=gray]>>> %s joined[/color]" % msg["user"])
			if user and not users.has(user):
				users.append(user)
			update_userlist()
			playsound(preload("res://assets/sounds/join.wav"))
		"leave":
			var user = msg.get("user")
			print_out("[color=gray]>>> %s left[/color]" % msg["user"])
			if user and users.has(user):
				users.erase(user)
			update_userlist()
			playsound(preload("res://assets/sounds/leave.wav"))
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
			playsound(preload("res://assets/sounds/leave.wav"))
		"success":
			print_out("[color=green]%s[/color]" % msg.get("body"))
			playsound(preload("res://assets/sounds/join.wav"))
		"ping":
			var now = Time.get_unix_time_from_system()
			update_status()
			last_ping = snappedf((now - msg.get("body")) * 1000, 0.1)
		"server_info":
			server_info = msg
			var icon = msg.get("icon")
			var bytes = Marshalls.base64_to_raw(icon)
			var img := Image.new()
			if img.load_png_from_buffer(bytes) != OK:
				return

			server_icon = ImageTexture.create_from_image(img)

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
	if socket.get_status() == 2:
		disconnect_from_server()
	elif socket.get_status() == 0:
		connect_to_server()
		update_status()

func send(message: String) -> void:
	var data = {
		"type": "message",
		"user": username,
		"body": message
	}
	send_json(data)
	%TextInput.text = ""

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
		push_error("Error seconding packet: ", error_string(err))

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

func playsound(stream: AudioStream) -> void:
	var ap := AudioStreamPlayer.new()
	ap.stream = stream
	ap.autoplay = true
	ap.finished.connect(ap.queue_free)
	add_child(ap)

func _on_clear_button_pressed() -> void:
	%ChatText.text = ""

func disconnect_from_server():
	if not socket.get_status() == StreamPeerTCP.STATUS_CONNECTED: return
	socket.disconnect_from_host()
	users = []
	update_userlist()
	playsound(preload("res://assets/sounds/disconnect.wav"))
	is_logged_in = false
	update_status()

func save_server():
	var data = {
		"name": server_info["name"],
		"description": server_info["description"],
		"addr": server_info["addr"],
		"port": int(server_info["port"])
	}
	servers[servers.size()] = data

	%ServerList.add_item(server_info["name"], server_icon)
	print_out("Saved server %s" % server_info["name"])

func add_server(addr: String, port: int):
	var data = {
		"name": "",
		"description": "",
		"addr": addr,
		"port": port
	}
	servers[servers.size()] = data

	connect_to_server(addr, port)
	await connected

	$AddServerPopup.hide()

	%ServerList.add_item(server_info["name"], server_icon)
	print_out("Saved server %s" % server_info["name"])

func _on_server_list_item_activated(index: int) -> void:
	disconnect_from_server()
	var host = servers[index]["addr"]
	var port = servers[index]["port"]
	connect_to_server(host, port)

func _on_save_server_button_pressed() -> void:
	save_server()

func _on_add_server_button_pressed() -> void:
	$AddServerPopup.show()
