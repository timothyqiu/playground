extends Area2D

signal selection_toggled(is_selected)

var movement = 3

var is_selected

onready var sprite = $Sprite
onready var selection = $Selection
onready var tween = $Tween


func go_along_path(path):
	
	for i in range(1, path.size()):
		tween.interpolate_property(
			self, "position", path[i - 1] + Vector2(8, 8), path[i] + Vector2(8, 8),
			0.2, Tween.TRANS_EXPO, Tween.EASE_IN_OUT,
			0.2 * (i - 1))
	tween.start()


func _on_Player_mouse_entered():
	selection.show()


func _on_Player_mouse_exited():
	selection.hide()


func _on_Player_input_event(viewport, event, shape_idx):
	var mouse = event as InputEventMouseButton
	if mouse and mouse.button_index == BUTTON_LEFT:
		if mouse.is_pressed():
			sprite.modulate.a = 0.8
		else:
			sprite.modulate.a = 1.0
			is_selected = not is_selected
			emit_signal("selection_toggled", is_selected)
