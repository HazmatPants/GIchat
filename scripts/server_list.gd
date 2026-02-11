extends ItemList

var clicked_idx: int = 0

func _on_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		$PopupMenu.show()
		$PopupMenu.position = at_position
		clicked_idx = index

func _on_popup_menu_id_pressed(id: int) -> void:
	match id:
		0:
			owner._on_server_list_item_activated(clicked_idx)
		1:
			var server_name = get_item_text(clicked_idx)
			var server_desc = owner.servers[server_name]["description"]
			%ServerInfoPopup.show_info(server_name, server_desc)
		2:
			var server_name = get_item_text(clicked_idx)
			owner.servers.erase(server_name)
			remove_item(clicked_idx)
			owner.save_server_list()
			GLOBAL.create_notification("Removed %s" % server_name)
