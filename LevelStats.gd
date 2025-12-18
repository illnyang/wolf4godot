extends Node
class_name LevelStats

var kill_count: int = 0
var kill_total: int = 0

var secret_count: int = 0
var secret_total: int = 0

var treasure_count: int = 0
var treasure_total: int = 0

var time_start_msec: int = 0

func start_level():
	kill_count = 0
	secret_count = 0
	treasure_count = 0
	time_start_msec = Time.get_ticks_msec()

func get_time_seconds() -> int:
	return int((Time.get_ticks_msec() - time_start_msec) / 1000)
