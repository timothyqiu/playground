class_name Stats
extends Node

const UPGRADE_EXP := 100
const HEALTH_INCR_PER_LEVEL := 30
const ATTACK_INCR_PER_LEVEL := 1
const DEFEND_INCR_PER_LEVEL := 1

var level := 1
var health := 50 setget set_health
var max_health := 50
var current_exp := 0 setget set_exp
var attack := 1
var defend := 1
var speed := 8
var money := 100


func set_health(value: int) -> void:
	health = clamp(value, 0, max_health)


func set_exp(value: int) -> void:
	current_exp = value
	
	var upgrade_levels = current_exp / UPGRADE_EXP
	if upgrade_levels:
		level += upgrade_levels
		attack += upgrade_levels * ATTACK_INCR_PER_LEVEL
		defend += upgrade_levels * DEFEND_INCR_PER_LEVEL
		max_health += upgrade_levels * HEALTH_INCR_PER_LEVEL
		health += (max_health - health) / 2
		current_exp %= UPGRADE_EXP
