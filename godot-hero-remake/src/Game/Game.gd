extends Node

const NULL_ITEM := 0
const MAX_ITEMS := 16

var persist = {}
var items := [
	1, 2, 3, 4,
	5, 6, 7, 8,
]
var stats := Stats.new()


func _ready() -> void:
	for _i in range(items.size(), MAX_ITEMS):
		items.append(NULL_ITEM)
	
	var err := OK
	err = Events.connect("leaving_map", self, "_on_leaving_map")
	assert(err == OK)
	err = Events.connect("entering_map", self, "_on_entering_map")
	assert(err == OK)


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
	if item_id == NULL_ITEM:
		printerr("Using null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	stats.current_exp += item.exp
	stats.health += item.health
	stats.attack += item.attack
	stats.defend += item.defend
	
	items[index] = NULL_ITEM


func buy_item(item_id: int):
	if item_id == NULL_ITEM:
		printerr("Buying null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	if item.money > stats.money:
		return "你的钱不够，兄弟"
	
	for i in range(items.size()):
		var id = items[i]
		if id == NULL_ITEM:
			items[i] = item_id
			stats.money -= item.money
			return
	
	return "你的背包已经满了"


func sell_item(index: int, depreciation: float) -> void:
	var item_id = items[index]
	if item_id == NULL_ITEM:
		printerr("Selling null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	stats.money += item.money * depreciation
	
	items[index] = NULL_ITEM