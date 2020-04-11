extends Area2D

export(String, MULTILINE) var dialogue = "Hello World"

var interactable = false


func _unhandled_input(event):
	if interactable and event.is_action_pressed("interact"):
		var dialogues = dialogue.split("\n---\n")
		Dialogue.show_dialogue(dialogues)


func _on_DialogTrigger_body_entered(_body):
	interactable = true


func _on_DialogTrigger_body_exited(_body):
	interactable = false
