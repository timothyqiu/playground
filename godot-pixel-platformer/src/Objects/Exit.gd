extends Area2D


func _on_Exit_body_entered(body):
	var player: Player = body
	player.go_right()
	Game.go_next_level()
