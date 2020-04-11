extends Node2D


func _unhandled_input(event):
	if event.is_action_pressed("exit"):
		SceneTransition.transition_to("res://UI/MainMenu.tscn")


func _on_Player_player_dead():
	Levels.reload()
