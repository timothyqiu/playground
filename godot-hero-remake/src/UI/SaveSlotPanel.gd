extends PopupPanel

signal save_file_selected(path)

export var only_existing := false


func _ready() -> void:
	for button in $VBoxContainer.get_children():
		if button.name != "Back":
			button.connect("pressed", self, "_on_Slot_pressed", [button.name])


func _on_Slot_pressed(basename) -> void:
	var path = _path_from_basename(basename)
	emit_signal("save_file_selected", path)
	hide()


func _on_Back_pressed() -> void:
	hide()


func _on_SaveSlotPanel_about_to_show() -> void:
	var file = File.new()
	for button in $VBoxContainer.get_children():
		if button.name != "Back":
			var path = _path_from_basename(button.name)
			button.disabled = only_existing and not file.file_exists(path)


func _path_from_basename(basename: String) -> String:
	return "user://save.%s.sav" % basename
