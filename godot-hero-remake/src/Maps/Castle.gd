extends Map


func _on_Boss_dead() -> void:
	Game.phase = Game.Phase.OUTRO
	
	var boss = $Structures/Boss
	boss.talk(player)
	yield(Events, "dialogue_finished")
	
	$Structures/Pricess.talk(player)
	yield(Events, "dialogue_finished")
	
	var data = [
		{
			"text": "祝贺你成功打爆试玩版！",
		},
	]
	DialogueBox.show_dialogue(data)
	yield(Events, "dialogue_finished")
	
	Transition.replace_scene("res://src/UI/TitleScreen.tscn")
