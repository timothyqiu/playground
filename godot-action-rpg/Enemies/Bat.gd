extends KinematicBody2D

enum {
	IDLE,
	WANDER,
	CHASE,
}

const EnemyDeathEffect = preload("res://Effects/EnemyDeathEffect.tscn")

export var acceleration = 300.0
export var max_speed = 50.0
export var friction = 200.0

var knockback = Vector2.ZERO
var state = CHASE
var velocity = Vector2.ZERO

onready var stats = $Stats
onready var player_detection_zone = $PlayerDetectionZone
onready var sprite = $AnimatedSprite
onready var hurtbox = $Hurtbox


func _physics_process(delta):
	knockback = knockback.move_toward(Vector2.ZERO, friction * delta)
	knockback = move_and_slide(knockback)
	
	match state:
		IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			seek_player()
		
		WANDER:
			pass
		
		CHASE:
			var player = player_detection_zone.player
			if player == null:
				state = IDLE
			else:
				var direction = (player.global_position - global_position).normalized()
				velocity = velocity.move_toward(max_speed * direction, acceleration * delta)
			sprite.flip_h = velocity.x < 0
	
	velocity = move_and_slide(velocity)


func seek_player():
	if player_detection_zone.can_see_player():
		state = CHASE


func _on_Hurtbox_area_entered(area):
	stats.health -= area.damage
	knockback = area.knockback_vector * 150
	hurtbox.start_invincibility(0.5)
	hurtbox.create_hit_effect()


func _on_Stats_no_health():
	queue_free()
	var enemyDeathEffect = EnemyDeathEffect.instance()
	get_parent().add_child(enemyDeathEffect)
	enemyDeathEffect.global_position = global_position
