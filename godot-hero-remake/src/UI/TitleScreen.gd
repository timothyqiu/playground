extends Control

onready var load_panel := $LoadPanel


func _ready() -> void:
	Game.music = 0
	$Menu.get_child(0).grab_focus()


func _on_NewGame_pressed() -> void:
	Transition.replace_scene("res://src/Maps/Home.tscn")


func _on_Load_pressed() -> void:
	load_panel.popup()


func _on_Exit_pressed() -> void:
	get_tree().quit()


func _on_LoadPanel_save_file_selected(path) -> void:
	Game.load_game(path)
