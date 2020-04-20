extends Map


func _on_CastleGate_decide_can_teleport(switcher) -> void:
	if Game.phase < Game.Phase.SAVE_WORLD:
		switcher.can_teleport = false
		
		var data = [
			{
				"text": "再过去就是大魔王的宫殿了，我还没找到「圣剑」，进去等于是送死啊！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "还是先找「圣剑」吧！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			}
		]
		DialogueBox.show_dialogue(data)
	else:
		switcher.can_teleport = true


func _on_MiniBoss_dead() -> void:
	var boss = $Structures/MiniBoss
	var data = [
		{
			"text": "啊……",
			"name": boss.character_name,
			"avatar": boss.talker_texture,
		},
		{
			"text": "死吧！罪大恶极的强盗。",
			"name": player.character_name,
			"avatar": player.talker_texture,
		},
		{
			"text": "大哥，你一定要为我报仇啊！……",
			"name": boss.character_name,
			"avatar": boss.talker_texture,
		},
		{
			"text": "[难道大魔王就是他的大哥？等着吧！大魔王，我一定会阻止你的阴谋。]",
			"name": player.character_name,
			"avatar": player.talker_texture,
		},
		{
			"text": "太好了！终于找到了失落已久的“圣剑”，就用它的威力把大魔王彻底杀死吧！",
		},
	]
	DialogueBox.show_dialogue(data)
	
	Game.phase = Game.Phase.SAVE_WORLD
