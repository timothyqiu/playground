extends StaticBody2D

export var opened := false
export(ItemDB.ItemId) var item_id := ItemDB.ItemId.NULL
export var money := 0

var interactable := false
var close_after_message := false

onready var sprite := $AnimatedSprite


func _ready() -> void:
	add_to_group("persist")
	set_opened(opened)


func set_opened(value: bool) -> void:
	opened = value
	sprite.frame = 1 if opened else 0


func _on_Interactable_interact(_interacter) -> void:
	if opened:
		return
	
	set_opened(true)
	close_after_message = false
	
	var data = []
	
	if money:
		data.append({
			"text": "打开宝箱后，发现有%d金币，哈哈……我赚翻了#_$" % money,
		})
		PlayerStats.money += money
	
	if item_id != ItemDB.ItemId.NULL:
		var item = ItemDB.ITEMS[item_id]
		var err = Game.put_item(item_id)
		
		var message = "呵呵……赚了^_&"
		if err:
			message = "可是%s" % err
			close_after_message = true
		
		data.append({
			"text": "打开宝箱后，发现有一个%s，%s" % [item.name, message],
		})
	
	if data.empty():
		data.append({
			"text": "箱子里什么都没有，白高兴一场。"
		})
	
	var err := Events.connect("dialogue_finished", self, "_message_finished")
	assert(err == OK)
	DialogueBox.show_dialogue(data)


func _message_finished():
	if close_after_message:
		set_opened(false)


func to_dict():
	return {
		"opened": opened,
	}


func from_dict(data: Dictionary):
	set_opened(data.opened)

