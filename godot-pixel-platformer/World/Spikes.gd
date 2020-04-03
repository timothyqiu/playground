extends Area2D


func _on_Spikes_body_entered(body):
	var player: Player = body
	player.hurt()
