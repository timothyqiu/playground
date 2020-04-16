extends Node

const NULL_ITEM = 0

var persist = {}
var items := [1, 2, 3, 6, 6, 6, 4, 5]
var stats := Stats.new()


func _ready() -> void:
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
