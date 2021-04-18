class_name ItemSlot
extends Button

const ICONS_TEXTURE = preload("res://assets/ui/goods.png")

const ICON_COUNT := 15
const ATLAS_GRID := Vector2(48, 48)
const ATLAS_WIDTH := 8
const ATLAS_FIRST_ICON_OFFSET := 2
const ATLAS_UNKNOWN_ICON_OFFSET := 17
const ATLAS_EMPTY_ICON_OFFSET := 18

# Item ID:
# 0 - null
# 1, 2, 3, ...
var item_id: int = ItemDB.ItemId.NULL setget set_item_id

onready var atlas := AtlasTexture.new()


func _ready() -> void:
	atlas.atlas = ICONS_TEXTURE
	icon = atlas
	
	set_item_id(item_id)


func _item_id_to_icon(id: int) -> int:
	if id < 0 or ICON_COUNT < id:
		return ATLAS_UNKNOWN_ICON_OFFSET
	if id == 0:
		return ATLAS_EMPTY_ICON_OFFSET
	return ATLAS_FIRST_ICON_OFFSET + (id - 1)


func _set_atlas_icon(offset: int) -> void:
# warning-ignore:integer_division
	var row = offset / ATLAS_WIDTH
	var col = offset % ATLAS_WIDTH
	var rect = Rect2(ATLAS_GRID * Vector2(col, row), ATLAS_GRID)
	atlas.region = rect


func set_item_id(id: int) -> void:
	item_id = id
	_set_atlas_icon(_item_id_to_icon(id))
