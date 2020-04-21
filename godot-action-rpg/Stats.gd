extends Node

signal health_changed(value)
signal max_health_changed(value)
signal no_health()

export var max_health = 1 setget set_max_health

var health = 0 setget set_health


func _ready() -> void:
	self.health = max_health


func set_health(value):
	health = value
	emit_signal("health_changed", health)
	
	if health <= 0:
		emit_signal("no_health")


func set_max_health(value):
	max_health = value
	self.health = min(health, max_health)
	emit_signal("max_health_changed", max_health)
