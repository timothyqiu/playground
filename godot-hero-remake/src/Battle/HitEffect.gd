extends AnimatedSprite


func _ready() -> void:
	play("Animate")


func _on_HitEffect_animation_finished() -> void:
	queue_free()
