extends KinematicBody2D

enum NpcRole {
	NORMAL,
	PEDLAR,
	PAWNBROKER,
}

enum NpcState {
	WALK,
	IDLE,
	STATIONARY,
}

export var character_name := "无名氏"
export var is_stationary := false
export(NpcRole) var role := NpcRole.NORMAL
export(Array, int) var items = []
export var max_speed := 30.0
export var acceleration := 256.0
export var friction := 256.0
export var direction := Vector2.ZERO

var state = NpcState.IDLE
var velocity := Vector2.ZERO
var talker_texture := AtlasTexture.new()

onready var sprite := $Sprite
onready var animation_tree := $AnimationTree
onready var animation_state:AnimationNodeStateMachine = $AnimationTree.get("parameters/playback")
onready var walk_timer := $WalkTimer
onready var idle_timer := $IdleTimer


func _ready() -> void:
	add_to_group("persist")
	
	talker_texture.atlas = sprite.texture
	talker_texture.region = Rect2(0, 0, 32, 32)
	
	if is_stationary:
		_enter_stationary(direction)
	elif randi() % 2:
		_enter_idle()
	else:
		_enter_walk()


func _physics_process(_delta: float) -> void:
	velocity = move_and_slide(velocity)
	
	if state == NpcState.WALK and velocity.is_equal_approx(Vector2.ZERO):
		direction = Vector2.RIGHT.rotated(randi() % 4 * PI / 2)


func _process(delta: float) -> void:
	match state:
		NpcState.IDLE:
			_move(delta)
			if idle_timer.is_stopped():
				_enter_walk()
		
		NpcState.WALK:
			_move(delta)
			if walk_timer.is_stopped():
				_enter_idle()
		
		NpcState.STATIONARY:
			pass


func _move(delta: float) -> void:
	if direction == Vector2.ZERO:
		animation_state.travel("idle")
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		set_direction(direction)
		animation_state.travel("walk")
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)


func set_direction(value: Vector2) -> void:
	animation_tree.set("parameters/idle/blend_position", value)
	animation_tree.set("parameters/walk/blend_position", value)


func _enter_walk():
	state = NpcState.WALK
	direction = Vector2.RIGHT.rotated(randi() % 4 * PI / 2)
	walk_timer.start(5 + randi() % 5)


func _enter_idle():
	state = NpcState.IDLE
	direction = Vector2.ZERO
	idle_timer.start(1 + randi() % 5)


func _enter_stationary(dir: Vector2):
	state = NpcState.STATIONARY
	velocity = Vector2.ZERO
	direction = dir
	set_direction(dir)
	animation_state.travel("idle")


func _on_Interactable_interact(interacter) -> void:
	var data = [
		{
			"text": "你好呀！我是%s。" % character_name,
			"name": character_name,
			"avatar": talker_texture,
		},
		{
			"text": "再见，%s。" % character_name,
			"name": interacter.character_name,
			"avatar": interacter.talker_texture,
		}
	]
	
	var facing_interacter = interacter.global_position - global_position
	_enter_stationary(facing_interacter.normalized())
	
	var err := Events.connect("dialogue_finished", self, "_on_dialogue_finished", [], CONNECT_ONESHOT)
	assert(err == OK)
	
	Dialogue.show_dialogue(data)


func _on_dialogue_finished() -> void:
	set_direction(direction)
	
	match role:
		NpcRole.PEDLAR:
			var err := OK
			
			err = BuyDialog.connect("item_bought", self, "_on_item_bought")
			assert(err == OK)
			err = BuyDialog.connect("finished", self, "_on_shop_finished", [], CONNECT_ONESHOT)
			assert(err == OK)
			
			BuyDialog.show(items)
		
		NpcRole.PAWNBROKER:
			var err := SellDialog.connect("finished", self, "_on_shop_finished", [], CONNECT_ONESHOT)
			assert(err == OK)
			
			SellDialog.show()
		
		NpcRole.NORMAL:
			if not is_stationary:
				_enter_walk()


func _on_item_bought(index) -> void:
	items[index] = Game.NULL_ITEM
	BuyDialog.set_items(items)


func _on_shop_finished() -> void:
	match role:
		NpcRole.PEDLAR:
			BuyDialog.disconnect("item_bought", self, "_on_item_bought")
	
	if not is_stationary:
		_enter_walk()


func to_dict():
	return {
		"x": position.x,
		"y": position.y,
		"items": items,
	}


func from_dict(data: Dictionary):
	position = Vector2(data.x, data.y)
	items = data.items
