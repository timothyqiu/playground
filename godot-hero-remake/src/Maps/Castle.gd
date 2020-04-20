extends Map


func _on_Boss_dead() -> void:
	var boss = $Structures/Boss
	var data = [
			{
				"text": "什么？这……这……",
				"name": boss.character_name,
				"avatar": boss.talker_texture,
			},
			{
				"text": "不！不可能的！！绝对不可能的！！！",
				"name": boss.character_name,
				"avatar": boss.talker_texture,
			},
			{
				"text": "我纵横一生，经过了多少的大风大浪，想不到最后会死在一个毛头小子的手里，真是造化弄人啊！",
				"name": boss.character_name,
				"avatar": boss.talker_texture,
			},
			{
				"text": "这叫做「多行不义必自毙」！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "就算你再强大、再厉害，但是，你如果要破坏人类的和平！就一定会得到报应的！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "因为世界人民是不会在强权面前屈服的，相反你越是欺压他们，他们就越是会团结在一起。不管多强大的敌人，也一样可以击败！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "呼……呼…… 我终于明白了，不过已经太迟了",
				"name": boss.character_name,
				"avatar": boss.talker_texture,
			},
			{
				"text": "就让我来生做个好人吧！永别了……",
				"name": boss.character_name,
				"avatar": boss.talker_texture,
			},
			{
				"text": "……",
				"name": boss.character_name,
				"avatar": boss.talker_texture,
			},
			{
				"text": "……",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "[一切都结束了，从此「白云城」又会恢复和平。希望以后永远都不要再发生战斗了……]",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "祝贺你成功打爆试玩版！",
			},
		]
	
	DialogueBox.show_dialogue(data)
	yield(Events, "dialogue_finished")
	
	Transition.replace_scene("res://src/UI/TitleScreen.tscn")
