class_name Dialogue
extends Resource

export(int, "Intro", "Beat Tuyin", "Beat Daoba", "Go Outside", "Beat Wupi", "Beat Boss", "Outro") var phase = 0

# each line is one screen of text
# } player / { npc / @ null
export(String, MULTILINE) var content = ""


func is_active() -> bool:
	return not (Game.phase < phase)


func show(player, npc) -> void:
	var data = []
	
	var talker_mapping = {
		"}": player,
		"{": npc,
	}
	
	for line in content.split("\n", false):
		var entry = {
			"text": line.substr(1),
		}
		var talker = talker_mapping.get(line[0])
		if talker:
			entry["name"] = talker.character_name
			entry["avatar"] = talker.talker_texture
		data.append(entry)
	
	DialogueBox.show_dialogue(data)
