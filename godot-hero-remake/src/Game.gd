extends Node

var persist = {}


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
