class_name Npc
extends KinematicBody2D

signal dead()
signal interact(interactor)
signal interaction_finished()

enum NpcRole {
	NORMAL,
	PEDLAR,
	PAWNBROKER,
	PASSIVE_ENEMY,
	ACTIVE_ENEMY,
}

enum NpcState {
	DEAD,
	WALK,
	IDLE,
	STATIONARY,
}

export var character_name := "无名氏"
export var is_stationary := false
export(NpcRole) var role := NpcRole.NORMAL
export(Array, ItemDB.ItemId) var items = []
export var max_speed := 30.0
export var acceleration := 256.0
export var friction := 256.0
export var direction := Vector2.ZERO setget set_direction
export(Array, Resource) var dialogues = []  # [Dialogue]

var state: int setget set_state
var velocity := Vector2.ZERO
var talker_texture := AtlasTexture.new()

onready var stats := $Stats
onready var sprite := $Sprite
onready var animation_tree := $AnimationTree
onready var animation_state = $AnimationTree.get("parameters/playback")
onready var walk_timer := $WalkTimer
onready var idle_timer := $IdleTimer
onready var interactable := $Interactable


func _ready() -> void:
	add_to_group("persist")
	
	talker_texture.atlas = sprite.texture
	talker_texture.region = Rect2(0, 0, 32, 32)
	
	if role == NpcRole.ACTIVE_ENEMY:
		interactable.is_passive = false
	
	if is_stationary:
		self.state = NpcState.STATIONARY
		self.direction = direction
	elif randi() % 2:
		self.state = NpcState.IDLE
	else:
		self.state = NpcState.WALK


func _physics_process(_delta: float) -> void:
	velocity = move_and_slide(velocity)
	
	if state == NpcState.WALK and velocity.is_equal_approx(Vector2.ZERO):
		direction = Vector2.RIGHT.rotated(randi() % 4 * PI / 2)


func _process(delta: float) -> void:
	match state:
		NpcState.IDLE:
			_move(delta)
			if idle_timer.is_stopped():
				self.state = NpcState.WALK
		
		NpcState.WALK:
			_move(delta)
			if walk_timer.is_stopped():
				self.state = NpcState.IDLE


func _move(delta: float) -> void:
	if direction == Vector2.ZERO:
		animation_state.travel("idle")
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		set_direction(direction)
		animation_state.travel("walk")
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)


func set_direction(value: Vector2) -> void:
	direction = value
	
	if animation_tree:
		animation_tree.set("parameters/idle/blend_position", value)
		animation_tree.set("parameters/walk/blend_position", value)


func is_alive() -> bool:
	return state != NpcState.DEAD


func set_state(value: int):
	state = value
	match state:
		NpcState.IDLE:
			direction = Vector2.ZERO
			idle_timer.start(1 + randi() % 5)
		
		NpcState.WALK:
			direction = Vector2.RIGHT.rotated(randi() % 4 * PI / 2)
			walk_timer.start(5 + randi() % 5)
		
		NpcState.STATIONARY:
			velocity = Vector2.ZERO
			animation_state.travel("idle")


func _get_active_dialogue():
	var max_dialogue = null
	for dialogue in dialogues:
		if dialogue.is_active() and (max_dialogue == null or max_dialogue.phase < dialogue.phase):
			max_dialogue = dialogue
	return max_dialogue


func _on_Interactable_interact(interacter) -> void:
	if get_signal_connection_list("interact"):
		emit_signal("interact", interacter)
	else:
		interact(interacter)


func talk(interacter):
	# they shared the same parent, or just use global_position
	self.state = NpcState.STATIONARY
	self.direction = position.direction_to(interacter.position)
	
	var dialogue = _get_active_dialogue()
	if dialogue:
		dialogue.show(interacter, self)
	else:
		DialogueBox.show_dialogue([])


func interact(interacter) -> void:
	self.pause_mode = Node.PAUSE_MODE_PROCESS
	talk(interacter)
	yield(Events, "dialogue_finished")
	self.pause_mode = Node.PAUSE_MODE_INHERIT
	
	match role:
		NpcRole.PEDLAR:
			var err := BuyDialog.connect("item_bought", self, "_on_item_bought")
			assert(err == OK)
			
			BuyDialog.show(items)
			yield(BuyDialog, "finished")
			
			BuyDialog.disconnect("item_bought", self, "_on_item_bought")
			if not is_stationary:
				self.state = NpcState.WALK
		
		NpcRole.PAWNBROKER:
			SellDialog.show()
			yield(SellDialog, "finished")

			if not is_stationary:
				self.state = NpcState.WALK
		
		NpcRole.PASSIVE_ENEMY, NpcRole.ACTIVE_ENEMY:
			Transition.push_scene("res://src/Battle/Battle.tscn", {
				"enemy_stats": stats,
				"enemy_texture": sprite.texture,
				"enemy_items": items,
			})
			
			var result = yield(Events, "battle_finished")
			match result:
				Battle.BattleResult.PLAYER_WIN:
					# just a temporary trick
					position = Vector2(-999, -999)
					state = NpcState.DEAD
					emit_signal("dead")
				
				Battle.BattleResult.PLAYER_LOSE:
					yield(Transition, "transition_finished")
					Transition.replace_scene("res://src/UI/TitleScreen.tscn", {"skip_persist": true})
				
				Battle.BattleResult.RETREAT:
					interactable._turn_off()
		
		NpcRole.NORMAL:
			if not is_stationary:
				self.state = NpcState.WALK
	
	emit_signal("interaction_finished")


func _on_item_bought(index) -> void:
	items[index] = ItemDB.ItemId.NULL
	BuyDialog.set_items(items)


func to_dict():
	return {
		"state": state,
		"direction_x": direction.x,
		"direction_y": direction.y,
		"x": position.x,
		"y": position.y,
		"items": items,
		"is_stationary": is_stationary,
	}


func from_dict(data: Dictionary):
	self.state = data.state
	self.direction = Vector2(data.direction_x, data.direction_y)
	position = Vector2(data.x, data.y)
	items = data.items
	is_stationary = data.is_stationary
