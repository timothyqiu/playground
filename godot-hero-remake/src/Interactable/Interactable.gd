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


func _on_Interactable_area_exited(_area: Area2D) -> void:
	set_deferred("monitorable", true)
	interacter = null


func _turn_off() -> void:
	interacter = null
	
	monitorable = false
	monitoring = false
	
	yield(Game.get_tree().create_timer(2.0), "timeout")
	
	monitorable = true
	monitoring = true


func _on_Interactable_body_entered(body: Node) -> void:
	if not is_passive:
		emit_signal("interact", body)
