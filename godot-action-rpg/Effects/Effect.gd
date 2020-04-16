extends AnimatedSprite

func _ready():
	var err = connect("animation_finished", self, "_on_animation_finished")
	assert(err == OK)
	play("Animate")


func _on_animation_finished():
	queue_free()
