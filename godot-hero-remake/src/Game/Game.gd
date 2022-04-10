extends Node

const MAX_ITEMS := 16

const MUSICS = [
	preload("res://assets/audio/music/title.ogg"),
	preload("res://assets/audio/music/back.ogg"),
]

enum Phase {
	INTRO,
	BEAT_TUYIN,
	BEAT_DAOBA,
	GO_OUTSIDE,
	BEAT_WUPI,
	BEAT_BOSS,
	OUTRO,
}

var phase: int = Phase.INTRO
var items = []

var music setget set_music

var persist = {}

onready var music_player := $BackgroundMusicPlayer


func _ready() -> void:
	reset()
	
	var err := OK
	err = Events.connect("leaving_map", self, "_on_leaving_map")
	assert(err == OK)
	err = Events.connect("entering_map", self, "_on_entering_map")
	assert(err == OK)
	err = get_tree().connect("node_added", self, "_on_node_added")
	assert(err == OK)
	
	# hook existing scene
	_hook_children(get_tree().root)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


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


func reset() -> void:
	phase = Phase.INTRO
	items = []
	for _i in range(16):
		items.append(ItemDB.ItemId.NULL)
	items[0] = ItemDB.ItemId.HERB
	PlayerStats.reset()
	persist = {}
	
	if OS.is_debug_build():
#		put_item(ItemDB.ItemId.ACIENT_ARMOR)
		put_item(ItemDB.ItemId.ACIENT_ARMOR)
		put_item(ItemDB.ItemId.MANUAL)
#		put_item(ItemDB.ItemId.MANUAL)
#		put_item(ItemDB.ItemId.MANUAL)
#		put_item(ItemDB.ItemId.ICE_SWORD)


func new_game() -> void:
	reset()
	Transition.replace_scene("res://src/UI/Prologue.tscn")


func use_item(index: int) -> void:
	var item_id = items[index]
	if item_id == ItemDB.ItemId.NULL:
		printerr("Using null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	PlayerStats.current_exp += item.exp
	PlayerStats.health += item.health
	PlayerStats.attack += item.attack
	PlayerStats.defend += item.defend
	
	items[index] = ItemDB.ItemId.NULL


func buy_item(item_id: int):
	if item_id == ItemDB.ItemId.NULL:
		printerr("Buying null item!")
		return
	var item: Dictionary = ItemDB.ITEMS[item_id]
	
	if item.money > PlayerStats.money:
		return "你的钱不够，兄弟"
	
	for i in range(items.size()):
		var id = items[i]
		if id == ItemDB.ItemId.NULL:
			items[i] = item_id
			PlayerStats.money -= item.money
			return
	
	return "你的背包已经满了"


func put_item(item_id: int):
	if item_id == ItemDB.ItemId.NULL:
		printerr("Putting null item!")
		return
	
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
	
	PlayerStats.money += item.money * depreciation
	
	items[index] = ItemDB.ItemId.NULL


func set_music(value: int) -> void:
	var changed = music != value
	music = value
	
	if changed:
		music_player.stream = MUSICS[music]
		music_player.play()


func load_game(path: String) -> void:
	var file = File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		printerr("Failed to open file for read: %d" % err)
		return
	
	var data = parse_json(file.get_as_text())
	file.close()
	
	phase = data.phase
	items = data.items
	persist = data.persist
	PlayerStats.from_dict(data.stats)
	
	Transition.replace_scene(data.map, {
		"skip_persist": true,
		"target_player": data.player,
	})


func save_game(path: String) -> void:
	var file = File.new()
	var err = file.open(path, File.WRITE)
	if err != OK:
		printerr("Failed to open file for write: %d" % err)
		return
	
	var map = get_tree().current_scene
	_on_leaving_map(map)
	
	var data = {
		"phase": phase,
		"items": items,
		"stats": PlayerStats.to_dict(),
		"persist": persist,
		"player": map.player.to_dict(),
		"map": map.filename,
	}
	file.store_string(to_json(data))
	file.close()
