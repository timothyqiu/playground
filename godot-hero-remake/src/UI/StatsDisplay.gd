extends HBoxContainer

onready var level := $Values/Level
onready var ep := $Values/Exp
onready var hp := $Values/Hp
onready var atk := $Values/Atk
onready var def := $Values/Def
onready var spd := $Values/Spd
onready var money := $Values/Money


func update_stats() -> void:
	var stats: Stats = PlayerStats
	
	level.text = "%d" % stats.level
	ep.text = "%d/%d" % [stats.current_exp, stats.UPGRADE_EXP]
	hp.text = "%d/%d" % [stats.health, stats.max_health]
	atk.text = "%d" % stats.attack
	def.text = "%d" % stats.defend
	spd.text = "%d" % stats.speed
	money.text = "%d" % stats.money
