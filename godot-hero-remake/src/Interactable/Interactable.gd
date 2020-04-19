extends Area2D

signal interact(interacter)

var is_passive := true
var interacter = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_passive:
		return
	if interacter and event.is_action_pressed("ui_select"):
		emit_signal("interact", interacter)
		get_tree().set_input_as_handled()


func _on_Interactable_area_entered(area: Area2D) -> void:
	interacter = area.get_parent()
	if not is_passive:
		emit_signal("interact", interacter)


func _on_Interactable_area_exited(_area: Area2D) -> void:
	interacter = null
