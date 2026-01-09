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
	
	# Basic existence tests
	_test_pics_exist(results)
	_test_pics_dimensions(results)
	_test_walls_exist(results)
	_test_maps_structure(results)
	_test_sounds_format(results)
	
	# Pattern validation tests (check files match expected format)
	_test_pic_naming_pattern(results)
	_test_png_headers(results)
	_test_wall_dimensions(results)
	
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


# ===== PATTERN VALIDATION TESTS =====
# Verify files match expected patterns, not just existence

static func _test_pic_naming_pattern(results: Dictionary) -> void:
	# All pics should follow pattern: NNN_NAME.png where NNN is 3-digit number
	var dir = DirAccess.open("user://assets/wolf3d/pics/")
	if dir == null:
		results.failed += 1
		results.errors.append("Pics directory not found for pattern test")
		return
	
	var valid = 0
	var invalid = 0
	var regex = RegEx.new()
	regex.compile("^\\d{3}_[A-Z0-9_]+\\.png$")
	
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".png"):
			if regex.search(file):
				valid += 1
			else:
				invalid += 1
		file = dir.get_next()
	
	if invalid == 0:
		results.passed += 1
		print("  PASS: Pic naming pattern (all %d match NNN_NAME.png)" % valid)
	else:
		results.failed += 1
		results.errors.append("%d pics don't match pattern NNN_NAME.png" % invalid)


static func _test_png_headers(results: Dictionary) -> void:
	# Verify PNG files have valid PNG headers (magic bytes)
	var path = ProjectSettings.globalize_path("user://assets/wolf3d/pics/")
	var dir = DirAccess.open(path)
	if dir == null:
		results.failed += 1
		results.errors.append("Cannot open pics for header check")
		return
	
	var checked = 0
	var valid = 0
	var png_magic = PackedByteArray([0x89, 0x50, 0x4E, 0x47])  # PNG header
	
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "" and checked < 10:  # Sample first 10 files
		if file.ends_with(".png"):
			var f = FileAccess.open(path + "/" + file, FileAccess.READ)
			if f:
				var header = f.get_buffer(4)
				if header == png_magic:
					valid += 1
				f.close()
				checked += 1
		file = dir.get_next()
	
	if valid == checked and checked > 0:
		results.passed += 1
		print("  PASS: PNG headers valid (%d/%d)" % [valid, checked])
	else:
		results.failed += 1
		results.errors.append("PNG header check failed: %d/%d valid" % [valid, checked])


static func _test_wall_dimensions(results: Dictionary) -> void:
	# All wall textures should be exactly 64x64
	var path = ProjectSettings.globalize_path("user://assets/wolf3d/walls/")
	var dir = DirAccess.open(path)
	if dir == null:
		results.failed += 1
		results.errors.append("Cannot open walls for dimension check")
		return
	
	var correct = 0
	var wrong = 0
	
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".png"):
			var img = Image.load_from_file(path + "/" + file)
			if img and img.get_width() == 64 and img.get_height() == 64:
				correct += 1
			elif img:
				wrong += 1
		file = dir.get_next()
	
	if wrong == 0 and correct > 0:
		results.passed += 1
		print("  PASS: Wall dimensions (all %d are 64x64)" % correct)
	else:
		results.failed += 1
		results.errors.append("%d walls not 64x64" % wrong)
