extends Node2D

var GrassEffect = load("res://Effects/GrassEffect.tscn")

func _on_Hurtbox_area_entered(area):
	var grassEffect = GrassEffect.instance()
	grassEffect.global_position = global_position
	var world = get_tree().current_scene
	world.add_child(grassEffect)
	queue_free()
