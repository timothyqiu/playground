extends PopupPanel

onready var display := $StatsDisplay


#func _ready() -> void:
#	call_deferred("popup_centered")


func _on_Stats_about_to_show() -> void:
	display.update_stats()
