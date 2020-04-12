extends Area2D


func _on_Exit_body_entered(_body):
	Game.go_next_level()
