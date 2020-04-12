extends Area2D

onready var audio_player = $AudioStreamPlayer
onready var collision_shape = $CollisionShape2D


func _on_Coin_body_entered(_body):
	Game.coins_current_level += 1
	collision_shape.call_deferred("set_disabled", true)
	hide()
	audio_player.play()
	yield(audio_player, "finished")
	queue_free()
