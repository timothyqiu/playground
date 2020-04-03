extends Node2D

onready var animationPlayer = $CanvasLayer/AnimationPlayer

func _on_Exit_body_entered(body):
	animationPlayer.play("TransitionOut")

func transition_out_finished():
	get_tree().reload_current_scene()

func _on_Player_player_dead():
	animationPlayer.play("TransitionOut")
