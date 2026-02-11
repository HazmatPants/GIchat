extends Node

func playsound(stream: AudioStream) -> void:
	var ap := AudioStreamPlayer.new()
	ap.stream = stream
	ap.autoplay = true
	ap.finished.connect(ap.queue_free)
	get_tree().current_scene.add_child.call_deferred(ap)

func create_notification(text: String, text_color: Color=Color.WHITE):
	var notif = Notification.new().create(text, text_color)
	get_tree().current_scene.add_child(notif)
