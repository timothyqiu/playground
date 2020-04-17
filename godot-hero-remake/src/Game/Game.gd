extends Node

const MAX_ITEMS := 16

enum Phase {
	SAVE_ROUER,
	FIND_SWORD,
	SAVE_WORLD,
}

export(Phase) var phase = Phase.SAVE_ROUER
var persist = {}
export(Array, ItemDB.ItemId) var items := [
	1, 2, 3, 4,
	5, 6, 7, 8,
	9, 10, 11, 12,
]
var stats := Stats.new()


func _ready() -> void:
	for _i in range(items.size(), MAX_ITEMS):
		items.append(ItemDB.ItemId.NULL)
	
	var err := OK
	err = Events.connect("leaving_map", self, "_on_leaving_map")
	assert(err == OK)
	err = Events.connect("entering_map", self, "_on_entering_map")
	assert(err == OK)
	err = get_tree().connect("node_added", self, "_on_node_added")
	assert(err == OK)
	
	# hook existing scene
	_hook_children(get_tree().current_scene)


func _hook_children(parent: Node) -> void:
	for node in parent.get_children():
		_on_node_added(node)
		if node.get_child_count() > 0:
			_hook_children(node)


func _on_node_added(node: Node) -> void:
	if node is Button:
		var err := node.connect("mouse_entered", self, "_on_mouse_enter_button", [node])
		assert(err == OK)


func _on_mouse_enter_button(button: Button) -> void:
	button.grab_focus()


func _on_leaving_map(map: Map) -> void:
	var data = {}
	var nodes = get_tree().get_nodes_in_group("persist")
	for node in nodes:
		data[node.get_path()] = node.to_dict()
	
	persist[map.identifier] = data


func _on_entering_map(map: Map) -> void:
	var data = persist.get(map.identifier, {})
	for path in data:
		var node = get_tree().root.get_node(path)
		assert(node)
		node.from_dict(data[path])


func use_item(index: int) -> void:
	var item_id = items[index]
	if item_id == ItemDB.ItemId.NULL:
		printerr("Using null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	stats.current_exp += item.exp
	stats.health += item.health
	stats.attack += item.attack
	stats.defend += item.defend
	
	items[index] = ItemDB.ItemId.NULL


func buy_item(item_id: int):
	if item_id == ItemDB.ItemId.NULL:
		printerr("Buying null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	if item.money > stats.money:
		return "你的钱不够，兄弟"
	
	for i in range(items.size()):
		var id = items[i]
		if id == ItemDB.ItemId.NULL:
			items[i] = item_id
			stats.money -= item.money
			return
	
	return "你的背包已经满了"


func put_item(item_id: int):
	if item_id == ItemDB.ItemId.NULL:
		printerr("Putting null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	for i in range(items.size()):
		var id = items[i]
		if id == ItemDB.ItemId.NULL:
			items[i] = item_id
			return
	
	return "你的背包已经满了"


func sell_item(index: int, depreciation: float) -> void:
	var item_id = items[index]
	if item_id == ItemDB.ItemId.NULL:
		printerr("Selling null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	stats.money += item.money * depreciation
	
	items[index] = ItemDB.ItemId.NULL
