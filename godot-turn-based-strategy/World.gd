extends Node2D

var astar = AStar2D.new()
var path_target = null
var path := []
var path_index = 0

onready var player = $Player
onready var map = $Map
onready var map_size = map.get_used_rect().size
onready var indicators = $Indicators
onready var arrow = $Arrow
onready var path_head_id = map.tile_set.find_tile_by_name("arrow_head")
onready var path_straight_id = map.tile_set.find_tile_by_name("arrow_body_straight")
onready var path_corner_id = map.tile_set.find_tile_by_name("arrow_body_corner")


func _ready():
	assert(map.position == Vector2.ZERO)
	assert(map.get_used_rect().position == Vector2.ZERO)
	_setup_astar()
	arrow.hide()
	indicators.hide()


func _unhandled_input(event):
	var mouse = event as InputEventMouseMotion
	if mouse and arrow.visible:
		_update_arrow(mouse.position)
		get_tree().set_input_as_handled()
	
	var button = event as InputEventMouseButton
	if button and button.button_index == BUTTON_LEFT and not button.is_pressed() and arrow.visible:
		var player_pos = map.world_to_map(player.position)
		if path_target == null or path_target == player_pos:
			print("Canceled")
		else:
			print("Target: ", path_target)
			var points = []
			for id in path:
				points.append(map.map_to_world(_decode_point_id(id)))
			player.go_along_path(points)
		
		arrow.hide()
		indicators.hide()
		player.is_selected = false
		get_tree().set_input_as_handled()


func _update_arrow(target):
	var player_pos = map.world_to_map(player.position)
	var pos = map.world_to_map(target)
	
	if not _is_walkable(pos):
		return
	
	if pos == path_target:
		return
	
	if indicators.get_cellv(pos) == -1 and pos != player_pos:
		return
	
	arrow.clear()
	path_target = pos
	path = astar.get_id_path(_make_point_id(player_pos), _make_point_id(pos))
	var last_pos: Vector2
	for i in path.size():
		var current = _decode_point_id(path[i])
		if i != 0:
			var tile_id = path_straight_id
			var flip_x = current.x > last_pos.x
			var flip_y = current.y > last_pos.y
			var transpose = current.x != last_pos.x
			
			if i == path.size() - 1:
				tile_id = path_head_id
			else:
				var next = _decode_point_id(path[i + 1])
				var same_x = current.x == last_pos.x
				
				match next - last_pos:
					Vector2(-1, -1):
						tile_id = path_corner_id
						flip_x = same_x
						flip_y = not same_x
						transpose = false
					Vector2(-1, +1):
						tile_id = path_corner_id
						flip_x = same_x
						flip_y = same_x
						transpose = false
					Vector2(+1, -1):
						tile_id = path_corner_id
						flip_x = not same_x
						flip_y = not same_x
						transpose = false
					Vector2(+1, +1):
						tile_id = path_corner_id
			
			arrow.set_cellv(current, tile_id, flip_x, flip_y, transpose)
		last_pos = current


func _make_point_id(pos):
	return pos.x + pos.y * map_size.x


func _decode_point_id(point_id):
	var width = map_size.x as int
	return Vector2(point_id % width, point_id / width)


func _is_inside_bounds(pos):
	if pos.x < 0 or pos.x >= map_size.x:
		return false
	if pos.y < 0 or pos.y >= map_size.y:
		return false
	return true


func _is_walkable(pos):
	return _is_inside_bounds(pos) and map.get_cellv(pos) == -1


func _setup_astar():
	for y in map_size.y:
		for x in map_size.x:
			var point = Vector2(x, y)
			if map.get_cellv(point) != -1:
				continue
			astar.add_point(_make_point_id(point), point)
	
	for y in map_size.y:
		for x in map_size.x:
			var current = Vector2(x, y)
			if map.get_cellv(current) != -1:
				continue
			var possible_connections = PoolVector2Array([
				current + Vector2.UP,
				current + Vector2.RIGHT,
				current + Vector2.DOWN,
				current + Vector2.LEFT,
			])
			for point in possible_connections:
				if not _is_walkable(point):
					continue
				astar.connect_points(_make_point_id(current), _make_point_id(point), false)


func _on_Player_selection_toggled(is_selected):
	arrow.visible = is_selected
	indicators.visible = is_selected
	
	if is_selected:
		indicators.clear()
		for ry in range(-player.movement, +player.movement + 1):
			for rx in range(-player.movement, +player.movement + 1):
				if rx == 0 and ry == 0:
					continue
				if abs(rx) + abs(ry) > player.movement:
					continue
				var player_pos = map.world_to_map(player.position) 
				var point = player_pos + Vector2(rx, ry)
				if map.get_cellv(point) != -1:
					continue
				if astar.get_id_path(_make_point_id(player_pos), _make_point_id(point)).size() <= player.movement + 1:
					indicators.set_cellv(point, indicators.tile_set.find_tile_by_name("tile_ok"))
		arrow.clear()
		path_target = null
