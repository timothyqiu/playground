extends Area2D

export var show_hit := true

const HitEffect = preload("res://Effects/HitEffect.tscn")


func _on_Hurtbox_area_entered(_area: Area2D) -> void:
	if show_hit:
		var effect = HitEffect.instance()
		var main = get_tree().current_scene
		main.add_child(effect)
		effect.global_position = global_position
