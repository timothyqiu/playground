extends Control


func _ready() -> void:
	Game.music = 0
	$Menu.get_child(0).grab_focus()


func _on_NewGame_pressed() -> void:
	Transition.replace_scene("res://src/Maps/Home.tscn")


func _on_Load_pressed() -> void:
	pass # Replace with function body.


func _on_Exit_pressed() -> void:
	get_tree().quit()
