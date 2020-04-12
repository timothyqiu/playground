extends Node2D


var coins_total = 0


func _ready():
	var coins = get_node("Coins")
	if coins:
		coins_total = coins.get_child_count()


func _unhandled_input(event):
	if event.is_action_pressed("exit"):
		SceneTransition.transition_to("res://UI/MainMenu.tscn")


func _on_Player_player_dead():
	Game.reload()
