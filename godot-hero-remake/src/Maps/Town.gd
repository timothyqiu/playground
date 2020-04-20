extends Map


func _on_CityGate_decide_can_teleport(switcher) -> void:
	if Game.phase < Game.Phase.GO_OUTSIDE:
		switcher.can_teleport = false
		
		var data = [
			{
				"text": "⋯⋯现在出城去干什么呢？没什么事，还不如回家睡觉去。",
				"name": player.character_name,
				"avatar": player.talker_texture,
			}
		]
		DialogueBox.show_dialogue(data)
	elif Game.phase == Game.Phase.GO_OUTSIDE:
		var npc = $Structures/Npc3
		var data = [
			{
				"text": "咦！什么声音？",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "怎么大家都好像很惊慌的样子？刚才不是还好好的嘛！",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "不好了，十年前被剑圣打败的大魔王，刚才突然又出现了。",
				"name": npc.character_name,
				"avatar": npc.talker_texture,
			},
			{
				"text": "他干了些什么？",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "大魔王杀进了皇宫，把美丽的公主给掳走了，还限国王在三天之内交出王位，不然，就要杀掉公主！",
				"name": npc.character_name,
				"avatar": npc.talker_texture,
			},
			{
				"text": "什么！公主！ [我暗恋多年的公主！不行，绝对不行！]",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "大魔王太阴险了，现在剑圣已经死了。谁还可以制止大魔王呢？",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "我看没有人可以了，除非……",
				"name": npc.character_name,
				"avatar": npc.talker_texture,
			},
			{
				"text": "怎么样？",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
			{
				"text": "找到失落的「圣剑」！，不过希望太渺茫了……",
				"name": npc.character_name,
				"avatar": npc.talker_texture,
			},
			{
				"text": "不跟你说了，我还是先到乡下去躲一躲吧。",
				"name": npc.character_name,
				"avatar": npc.talker_texture,
			},
			{
				"text": "不行，不能让大魔王得逞。\n[等着吧。我一定会阻止这场浩劫的]",
				"name": player.character_name,
				"avatar": player.talker_texture,
			},
		]
		var err := Events.connect("dialogue_finished", self, "_on_dialogue_finished", [], CONNECT_ONESHOT)
		assert(err == OK)
		DialogueBox.show_dialogue(data)
		switcher.can_teleport = false
	else:
		switcher.can_teleport = true


func _on_dialogue_finished():
	Game.phase = Game.Phase.BEAT_WUPI
	
	var switch = $CityGate
	switch.monitorable = true
	switch.monitorable = false
