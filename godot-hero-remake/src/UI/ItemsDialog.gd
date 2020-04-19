class_name ItemsDialog
extends PopupPanel

signal item_selected(items, index)
signal finished

var items: Array setget set_items
var depreciation = 1.0

onready var slot_container = $VBoxContainer/ItemSlots
onready var item_title = $VBoxContainer/TitleBox/Title
onready var item_stats_label = $VBoxContainer/Display/StatsLabel
onready var item_stats_value = $VBoxContainer/Display/StatsValue
onready var item_description = $VBoxContainer/Display/Description
onready var stats_display = $VBoxContainer/Display/StatsDisplay
onready var info_label = $VBoxContainer/Info


func _ready() -> void:
	var slots = slot_container.get_children()
	
	# fix focus order
	var cols = slot_container.columns
	var rows = (slots.size() + cols - 1) / cols
	for i in range(slots.size()):
		var slot: ItemSlot = slots[i]
		
		var row = i / cols
		var col = i % cols
		
		var prev_row = rows - 1 if row == 0 else row - 1
		var prev_col = cols - 1 if col == 0 else col - 1
		var next_row = 0 if row == rows - 1 else row + 1
		var next_col = 0 if col == cols - 1 else col + 1
		
		slot.focus_neighbour_bottom = _get_item_slot_path(col, next_row)
		slot.focus_neighbour_top = _get_item_slot_path(col, prev_row)
		slot.focus_neighbour_left = _get_item_slot_path(prev_col, prev_row if col == 0 else row)
		slot.focus_neighbour_right = _get_item_slot_path(next_col, next_row if col == cols - 1 else row)
		
		var err := OK
		
		err = slot.connect("pressed", self, "_on_use_slot", [i, slot])
		assert(err == OK)
		err = slot.connect("focus_entered", self, "_on_focus_slot", [slot])
		assert(err == OK)
	
	slots[0].grab_focus()


func _get_item_slot_path(col: int, row: int) -> NodePath:
	var index = row * slot_container.columns + col
	var node = slot_container.get_child(index)
	return node.get_path()


func _on_use_slot(index: int, slot: ItemSlot) -> void:
	if slot.item_id == ItemDB.ItemId.NULL:
		return
	emit_signal("item_selected", items, index)


func _on_focus_slot(slot: ItemSlot) -> void:
	var item_exists = slot.item_id != ItemDB.ItemId.NULL and slot.item_id < ItemDB.ITEMS.size()
	_set_item_display_visible(item_exists)
	stats_display.visible = false
		
	if item_exists and slot.item_id < ItemDB.ITEMS.size():
		var item = ItemDB.ITEMS[slot.item_id]
		var price = max(1, int(item.money * depreciation))
		
		item_title.text = "%s（%d金）" % [item.name, price]
		item_description.text = item.description
		item_stats_value.text = "%d\n%d\n%d\n%d" % [
			item.exp, item.health, item.attack, item.defend
		]
	
	update_info()


func _set_item_display_visible(value: bool) -> void:
	item_title.visible = value
	item_description.visible = value
	item_stats_value.visible = value
	item_stats_label.visible = value


func show_stats() -> void:
	_set_item_display_visible(false)
	item_title.visible = true
	item_title.text = "现在的状态"
	
	stats_display.update_stats()
	stats_display.visible = true
	
	update_info()


func update_info(text: String = "") -> void:
	var info = "现有%d金" % PlayerStats.money
	if text:
		info += "，" + text
	info_label.text = info


func set_items(value: Array) -> void:
	items = value
	var slots = slot_container.get_children()
	for i in range(slots.size()):
		var slot: ItemSlot = slots[i]
		
		if i < items.size():
			slot.item_id = items[i]
		else:
			slot.item_id = ItemDB.ItemId.NULL


func _on_ItemsDialog_popup_hide() -> void:
	emit_signal("finished")
