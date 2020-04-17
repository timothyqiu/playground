extends Map


func _on_CastleGate_decide_can_teleport(switcher) -> void:
	if Game.phase != Game.Phase.SAVE_WORLD:
		switcher.can_teleport = false
		
		var data = [
			{
				"text": "再过去就是大魔王的宫殿了，我还没找到「圣剑」，进去等于是送死啊！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			}
		]
		Dialogue.show_dialogue(data)
	else:
		switcher.can_teleport = true


func _on_MiniBoss_dead() -> void:
	var data = [
			{
				"text": "拿到了圣剑，你可以去打大魔王了",
				"name": "作者",
			}
		]
	Dialogue.show_dialogue(data)
	
	Game.phase = Game.Phase.SAVE_WORLD
