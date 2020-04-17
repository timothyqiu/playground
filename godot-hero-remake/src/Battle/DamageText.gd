extends Position2D

onready var label := $DamageLabel


func _on_AnimationPlayer_animation_finished(_anim_name: String) -> void:
	queue_free()


func set_text(text: String):
	label.text = text
