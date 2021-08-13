extends Node

const UNITS := [
	{
		name="Farmer",
		texture=preload("res://assets/kenney.nl/sci-fi-rts/units/farmer.tres"),
	},
	{
		name="Solider",
		texture=preload("res://assets/kenney.nl/sci-fi-rts/units/solider.tres"),
	},
]
const BUILDINGS := [
	{
		name="Base",
		texture=preload("res://assets/kenney.nl/sci-fi-rts/buildings/base.tres"),
		unit_ids=[0],
	},
	{
		name="Barrack",
		texture=preload("res://assets/kenney.nl/sci-fi-rts/buildings/barrack.tres"),
		unit_ids=[1],
	},
]

const TILE_SET: TileSet = preload("res://assets/kenney.nl/sci-fi-rts/scifi_tilesheet.tres")

var _tile_id_map: Dictionary


func _ready():
	for i in BUILDINGS.size():
		var building = BUILDINGS[i]
		_tile_id_map[TILE_SET.find_tile_by_name(building.name)] = i


func get_building(id):
	return BUILDINGS[id]


func get_building_tile_id(id):
	return TILE_SET.find_tile_by_name(BUILDINGS[id].name)


func get_building_id_by_tile_id(tile_id):
	return _tile_id_map.get(tile_id, -1)
