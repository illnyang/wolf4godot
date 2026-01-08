# Performance Monitor
# Tracks FPS and provides performance metrics
extends Node

class_name PerformanceMonitor

var frame_times: Array[float] = []
var fps_history: Array[float] = []
var sample_duration: float = 5.0  # seconds
var is_recording: bool = false
var recording_start: float = 0.0

signal benchmark_complete(results: Dictionary)


func start_benchmark(duration: float = 10.0) -> void:
	frame_times.clear()
	fps_history.clear()
	is_recording = true
	recording_start = Time.get_ticks_msec() / 1000.0
	sample_duration = duration
	print("Performance benchmark started (%.1fs)..." % duration)


func _process(delta: float) -> void:
	if not is_recording:
		return
	
	frame_times.append(delta)
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - recording_start
	if elapsed >= sample_duration:
		_complete_benchmark()


func _complete_benchmark() -> void:
	is_recording = false
	
	if frame_times.is_empty():
		return
	
	# Calculate stats
	var total = frame_times.reduce(func(a, b): return a + b)
	var avg_frame_time = total / frame_times.size()
	var avg_fps = 1.0 / avg_frame_time
	
	# Find min/max
	var min_time = frame_times.min()
	var max_time = frame_times.max()
	var max_fps = 1.0 / min_time
	var min_fps = 1.0 / max_time
	
	# Calculate 1% lows (worst 1% of frames)
	var sorted = frame_times.duplicate()
	sorted.sort()
	var one_percent_idx = int(sorted.size() * 0.99)
	var one_percent_low_fps = 1.0 / sorted[one_percent_idx] if one_percent_idx < sorted.size() else min_fps
	
	var results = {
		"samples": frame_times.size(),
		"duration": sample_duration,
		"avg_fps": avg_fps,
		"max_fps": max_fps,
		"min_fps": min_fps,
		"one_percent_low": one_percent_low_fps
	}
	
	print("=== Performance Results ===")
	print("  Samples: %d" % results.samples)
	print("  Avg FPS: %.1f" % results.avg_fps)
	print("  Max FPS: %.1f" % results.max_fps)
	print("  Min FPS: %.1f" % results.min_fps)
	print("  1%% Low: %.1f" % results.one_percent_low)
	
	# Quality assessment
	if avg_fps >= 60:
		print("  Rating: EXCELLENT")
	elif avg_fps >= 30:
		print("  Rating: GOOD")
	else:
		print("  Rating: NEEDS OPTIMIZATION")
	
	benchmark_complete.emit(results)


## Get current FPS (call anytime)
static func get_current_fps() -> float:
	return Engine.get_frames_per_second()


## Print quick FPS to console
static func print_fps() -> void:
	print("Current FPS: %.1f" % Engine.get_frames_per_second())
