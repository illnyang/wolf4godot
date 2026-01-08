# Test Asset Extraction
# Validates extracted files exist AND match expected patterns
extends Node

class_name TestExtraction

## Run all extraction tests
static func run_all() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"errors": []
	}
	
	print("=== Running Extraction Tests ===")
	
	_test_pics_exist(results)
	_test_pics_dimensions(results)
	_test_walls_exist(results)
	_test_maps_structure(results)
	_test_sounds_format(results)
	
	print("=== Results: %d passed, %d failed ===" % [results.passed, results.failed])
	for error in results.errors:
		print("  FAIL: " + error)
	
	return results


static func _test_pics_exist(results: Dictionary) -> void:
	var dir = DirAccess.open("user://assets/wolf3d/pics/")
	if dir == null:
		results.failed += 1
		results.errors.append("Pics directory not found")
		return
	
	var count = 0
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".png"):
			count += 1
		file = dir.get_next()
	
	if count >= 130:
		results.passed += 1
		print("  PASS: Pics count (%d)" % count)
	else:
		results.failed += 1
		results.errors.append("Expected 130+ pics, got %d" % count)


static func _test_pics_dimensions(results: Dictionary) -> void:
	# Test TITLEPIC (should be 320x200)
	var path = "user://assets/wolf3d/pics/084_TITLEPIC.png"
	var img = Image.load_from_file(ProjectSettings.globalize_path(path))
	
	if img == null:
		results.failed += 1
		results.errors.append("TITLEPIC not found or invalid")
		return
	
	if img.get_width() == 320 and img.get_height() == 200:
		results.passed += 1
		print("  PASS: TITLEPIC dimensions (320x200)")
	else:
		results.failed += 1
		results.errors.append("TITLEPIC wrong size: %dx%d" % [img.get_width(), img.get_height()])


static func _test_walls_exist(results: Dictionary) -> void:
	var dir = DirAccess.open("user://assets/wolf3d/walls/")
	if dir == null:
		results.failed += 1
		results.errors.append("Walls directory not found")
		return
	
	var count = 0
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".png"):
			count += 1
		file = dir.get_next()
	
	# Wolf3D has ~100 wall textures (50 pairs of light/dark)
	if count >= 50:
		results.passed += 1
		print("  PASS: Wall textures count (%d)" % count)
	else:
		results.failed += 1
		results.errors.append("Expected 50+ wall textures, got %d" % count)


static func _test_maps_structure(results: Dictionary) -> void:
	var maps_path = "user://assets/wolf3d/maps/json/"
	var dir = DirAccess.open(maps_path)
	if dir == null:
		results.failed += 1
		results.errors.append("Maps directory not found")
		return
	
	# Find first JSON file
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "" and not file.ends_with(".json"):
		file = dir.get_next()
	
	if file == "":
		results.failed += 1
		results.errors.append("No map JSON files found")
		return
	
	# Verify JSON structure
	var json_file = FileAccess.open(maps_path + file, FileAccess.READ)
	var content = json_file.get_as_text()
	var data = JSON.parse_string(content)
	
	if data == null:
		results.failed += 1
		results.errors.append("Map JSON parse failed: " + file)
		return
	
	var required_keys = ["Name", "Tiles", "Things", "CeilingColor", "FloorColor"]
	var missing = []
	for key in required_keys:
		if not data.has(key):
			missing.append(key)
	
	if missing.is_empty():
		results.passed += 1
		print("  PASS: Map JSON structure valid")
	else:
		results.failed += 1
		results.errors.append("Map missing keys: " + str(missing))


static func _test_sounds_format(results: Dictionary) -> void:
	var sounds_path = "user://assets/wolf3d/sounds/"
	var dir = DirAccess.open(sounds_path)
	if dir == null:
		results.failed += 1
		results.errors.append("Sounds directory not found")
		return
	
	var count = 0
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".wav"):
			count += 1
		file = dir.get_next()
	
	if count >= 40:
		results.passed += 1
		print("  PASS: Sound files count (%d)" % count)
	else:
		results.failed += 1
		results.errors.append("Expected 40+ sounds, got %d" % count)
