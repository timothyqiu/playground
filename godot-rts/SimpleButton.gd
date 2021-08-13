class_name SimpleButton
extends TextureButton


func _notification(what):
	match what:
		NOTIFICATION_READY:
			modulate = Color.white


func _gui_input(event):
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == BUTTON_LEFT:
		modulate = Color.darkgray if mb.is_pressed() else Color.white
	
	._gui_input(event)
