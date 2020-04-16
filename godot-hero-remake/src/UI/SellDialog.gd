extends CanvasLayer

signal item_sold(item_id)
signal finished()

onready var dialog = $ItemsDialog


func _ready() -> void:
	dialog.depreciation = 0.5


func _on_ItemsDialog_item_selected(items, index) -> void:
	var item_id = items[index]
	Game.sell_item(index, dialog.depreciation)
	emit_signal("item_sold", item_id)
	dialog.set_items(Game.items)
	dialog.update_info()


func _on_ItemsDialog_about_to_show() -> void:
	get_tree().paused = true
	dialog.set_items(Game.items)


func _on_ItemsDialog_popup_hide() -> void:
	emit_signal("finished")
	get_tree().paused = false


func show() -> void:
	dialog.popup_centered()
