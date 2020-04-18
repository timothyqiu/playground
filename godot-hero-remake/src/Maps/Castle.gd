extends Map


func _on_Boss_dead() -> void:
	print("Complete!")
	
	var data = [
			{
				"text": "游戏结束，哈哈",
				"name": "作者",
			}
		]
	
	var err := Events.connect("dialogue_finished", self, "_on_outro_finished", [], CONNECT_ONESHOT)
	assert(err == OK)
	DialogueBox.show_dialogue(data)


func _on_outro_finished() -> void:
	Transition.replace_scene("res://src/UI/TitleScreen.tscn")