extends Node2D

signal game_over


func _on_Exit_body_entered(body):
	emit_signal("game_over")

func _on_Player_player_dead():
	emit_signal("game_over")
