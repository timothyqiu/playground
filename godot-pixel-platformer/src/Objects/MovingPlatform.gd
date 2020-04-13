extends Node2D


onready var animation_player = $AnimationPlayer


func on_lever(is_on):
	animation_player.playback_active = is_on
