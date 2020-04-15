extends CanvasLayer

onready var menubar := $TextureRect
onready var item_list := $TextureRect/VBoxContainer


func _ready() -> void:
	get_tree().paused = true
	item_list.get_children()[0].grab_focus()
	Events.emit_signal("game_paused")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_Back_pressed()
		get_tree().set_input_as_handled()


func _on_Back_pressed() -> void:
	queue_free()
	get_tree().paused = false
	Events.emit_signal("game_unpaused")


func _on_Exit_pressed() -> void:
	get_tree().quit()
