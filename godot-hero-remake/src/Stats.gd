class_name Stats
extends Node

const UPGRADE_EXP := 100
const HEALTH_INCR_PER_LEVEL := 30
const ATTACK_INCR_PER_LEVEL := 1
const DEFEND_INCR_PER_LEVEL := 1

export var level := 1
export var health := 50 setget set_health
export var max_health := 50
export var current_exp := 0 setget set_exp
export var attack := 1
export var defend := 1
export var speed := 8
export var money := 0


func set_health(value: int) -> void:
	health = int(clamp(value, 0, max_health))


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


func to_dict():
	return {
		"level": level,
		"health": health,
		"max_health": max_health,
		"current_exp": current_exp,
		"attack": attack,
		"defend": defend,
		"speed": speed,
		"money": money,
	}


func from_dict(dict):
	level = dict.level
	health = dict.health
	max_health = dict.max_health
	current_exp = dict.current_exp
	attack = dict.attack
	defend = dict.defend
	speed = dict.speed
	money = dict.money
