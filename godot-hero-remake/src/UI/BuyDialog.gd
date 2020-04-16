extends CanvasLayer

signal item_bought(index)
signal finished()

onready var dialog := $ItemsDialog


func _on_ItemsDialog_item_selected(items, index) -> void:
	var item_id = items[index]
	var err = Game.buy_item(item_id)
	if err:
		dialog.update_info(err)
	else:
		emit_signal("item_bought", index)


func _on_ItemsDialog_about_to_show() -> void:
	get_tree().paused = true


func _on_ItemsDialog_popup_hide() -> void:
	emit_signal("finished")
	get_tree().paused = false


func set_items(items: Array) -> void:
	dialog.set_items(items)


func show(items: Array) -> void:
	dialog.set_items(items)
	dialog.popup_centered()
