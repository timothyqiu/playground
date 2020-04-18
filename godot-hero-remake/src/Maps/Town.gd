extends Map


func _on_CityGate_decide_can_teleport(switcher) -> void:
	if Game.phase == Game.Phase.SAVE_ROUER:
		switcher.can_teleport = false
		
		var data = [
			{
				"text": "⋯⋯现在出城去干什么呢？没什么事，还不如回家睡觉去。",
				"name": player.character_name,
				"avatar": player.talker_texture,
			}
		]
		DialogueBox.show_dialogue(data)
	else:
		switcher.can_teleport = true
