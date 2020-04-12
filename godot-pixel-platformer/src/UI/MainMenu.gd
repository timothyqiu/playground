extends Control


func _ready():
	$Start.grab_focus()


func _unhandled_input(event):
	if event.is_action_pressed("exit"):
		get_tree().quit()


func _on_Start_pressed():
	Game.go_first_level()
