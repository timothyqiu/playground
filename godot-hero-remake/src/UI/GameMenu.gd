extends CanvasLayer

onready var menu_panel := $MenuPanel
onready var menu_item_list := $MenuPanel/VBoxContainer
onready var items_dialog := $ItemsDialog
onready var stats_dialog := $StatsDialog
onready var load_panel := $LoadPanel
onready var save_panel := $SavePanel
onready var about_dialog := $AboutDialog


func show_menu() -> void:
	menu_panel.popup()


func _on_Back_pressed() -> void:
	menu_panel.hide()


func _on_Exit_pressed() -> void:
	Transition.replace_scene("res://src/UI/TitleScreen.tscn")
	menu_panel.hide()


func _on_Items_pressed() -> void:
	items_dialog.set_items(Game.items)
	items_dialog.popup_centered()


func _on_Stats_pressed() -> void:
	stats_dialog.popup_centered()


func _on_Load_pressed() -> void:
	load_panel.popup()


func _on_Save_pressed() -> void:
	save_panel.popup()


func _on_ItemsDialog_item_selected(_items: Array, index: int) -> void:
	Game.use_item(index)
	items_dialog.set_items(Game.items)
	items_dialog.show_stats()


func _on_MenuPanel_popup_hide() -> void:
	get_tree().paused = false
	Events.emit_signal("game_unpaused")


func _on_MenuPanel_about_to_show() -> void:
	menu_item_list.get_children()[0].grab_focus()
	Events.emit_signal("game_paused")
	get_tree().paused = true


func _on_SavePanel_save_file_selected(path) -> void:
	Game.save_game(path)
	menu_panel.hide()


func _on_LoadPanel_save_file_selected(path) -> void:
	Game.load_game(path)
	menu_panel.hide()


func _on_About_pressed():
	about_dialog.popup()
