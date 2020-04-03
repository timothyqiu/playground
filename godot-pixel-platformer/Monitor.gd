extends Node2D

onready var animationPlayer = $CanvasLayer/AnimationPlayer

func _on_World_game_over():
	animationPlayer.play("TransitionOut")

func transition_out_finished():
	get_tree().reload_current_scene()
