extends Node
class_name LevelStats

var kill_count: int = 0
var kill_total: int = 0

var secret_count: int = 0
var secret_total: int = 0

var treasure_count: int = 0
var treasure_total: int = 0

var stored_time: float = 0.0
var time_start_msec: int = 0

# Computed property for level time in seconds
var level_time: float:
	get:
		return stored_time + float(Time.get_ticks_msec() - time_start_msec) / 1000.0

func start_level():
	kill_count = 0
	kill_total = 0
	secret_count = 0
	secret_total = 0
	treasure_count = 0
	treasure_total = 0
	stored_time = 0.0
	time_start_msec = Time.get_ticks_msec()

func get_time_seconds() -> int:
	return int((Time.get_ticks_msec() - time_start_msec) / 1000)

func get_kill_ratio() -> int:
	if kill_total <= 0:
		return 0
	return int(float(kill_count) / float(kill_total) * 100)

func get_secret_ratio() -> int:
	if secret_total <= 0:
		return 0
	return int(float(secret_count) / float(secret_total) * 100)

func get_treasure_ratio() -> int:
	if treasure_total <= 0:
		return 0
	return int(float(treasure_count) / float(treasure_total) * 100)
