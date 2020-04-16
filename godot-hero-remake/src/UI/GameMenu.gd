extends CanvasLayer

onready var menubar := $TextureRect
onready var menu_item_list := $TextureRect/VBoxContainer
onready var items_dialog := $ItemsDialog
onready var stats_dialog := $StatsDialog


func _ready() -> void:
	get_tree().paused = true
	menu_item_list.get_children()[0].grab_focus()
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


func _on_Items_pressed() -> void:
	items_dialog.set_items(Game.items)
	items_dialog.popup_centered()


func _on_Stats_pressed() -> void:
	stats_dialog.popup_centered()


func _on_ItemsDialog_item_selected(_items: Array, index: int) -> void:
	Game.use_item(index)
	items_dialog.set_items(Game.items)
	items_dialog.show_stats()
