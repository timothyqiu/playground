extends Area2D

onready var audio_player = $AudioStreamPlayer


func _on_Coin_body_entered(_body):
	Game.coins_current_level += 1
	hide()
	audio_player.play()
	yield(audio_player, "finished")
	queue_free()
