extends Popup

onready var message = $Content/Message
onready var credits = $Content/Credits
onready var credits_content = $Content/Credits/Content
onready var tween = $Content/Credits/Tween


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if message.visible:
			message.hide()
			credits.show()
			tween.interpolate_property(
				credits_content, "rect_position:y",
				credits.rect_size.y,
				-credits_content.rect_size.y,
				40)
			tween.start()
		else:
			hide()


func _on_AboutDialog_about_to_show():
	message.show()
	credits.hide()


func _on_AboutDialog_popup_hide():
	tween.remove_all()


func _on_Tween_tween_all_completed():
	hide()
