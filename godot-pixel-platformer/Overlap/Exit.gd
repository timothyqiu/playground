extends Area2D


func _on_Exit_body_entered(_body):
	Levels.go_next_level()
