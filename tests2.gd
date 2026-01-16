#!/usr/bin/env godot
extends SceneTree
#& "C:\Users\Kocio\Desktop\nowy\wolfgodot-master(11)\wolfgodot-master\wolfgodot.exe"  --headless -s tests2.gd
const EXTRACTOR_PATH = "res://extract_wolf3d.gd"
const OUTPUT_BASE = "user://assets/wolf3d/"

func _init():
	run_pipeline()
# Manages the high-level execution flow: Setup -> Extraction -> Delay -> Verification.
func run_pipeline():
	print("\n" + "=".repeat(60))
	print(" ROZPOCZĘCIE TESTÓW JEDNOSTKOWYCH (extract_wolf3d)")
	print("=".repeat(60))

	if not FileAccess.file_exists(EXTRACTOR_PATH):
		print("[ERROR] Extractor script not found at: " + EXTRACTOR_PATH)
		self.quit(1) 
		return

	var extractor_script = load(EXTRACTOR_PATH)
	if not extractor_script:
		print("[ERROR] Failed to load extractor script. Check for syntax errors.")
		self.quit(1)
		return
	var extractor = extractor_script.new()
	# In SceneTree, the 'root' node is the main Window. We add the extractor 
	# to the tree to ensure it remains active during asynchronous operations.
	self.root.add_child(extractor)
	
	# DATA DETECTION: Scan for original game files
	print("STEP 1: Detecting available game data...")
	extractor._detect_available_games()
	
	# EXTRACTION: If data is found, perform a trial extraction.
	if extractor.available_games.is_empty():
		print("[SKIP] No source files found. Skipping extraction, testing existing output.")
	else:
		print("STEP 2: Running trial extraction...")
		extractor._extract_game(extractor.GameType.WOLF3D)
	
	#SETTLE TIME: We wait 1.0 seconds to allow the OS to finalize file writes
	# and to ensure the Godot thread has finished processing the I/O buffer.
	await self.create_timer(1.0).timeout
	#VERIFICATION
	var results = {"passed": 0, "failed": 0, "errors": []}

	print("\nSTEP 3: Verifying output files:")
	run_test("Directory Structure", test_directories, results)
	run_test("Maps: Full JSON Batch Validation", test_maps_batch, results)
	run_test("Walls: Full PNG Batch Validation (64x64)", test_walls_batch, results)
	run_test("Audio: Full WAV Batch Validation (7042Hz)", test_audio_batch, results)
	print_summary(results)
	
	if results.failed > 0:
		self.quit(1)
	else:
		self.quit(0)


#Check if the extractor correctly created the sub-folder architecture.
#Iterates through a list of required sub-folders and verifies their 
#physical existence in the 'user://' directory using absolute path checks.
func test_directories() -> String:
	var required = ["maps/json", "walls", "sounds", "pics"]
	for d in required:
		if not DirAccess.dir_exists_absolute(OUTPUT_BASE + d):
			return "Missing expected folder: " + d
	return ""


# Iterates through ALL generated JSON maps and verifies their structure.
func test_maps_batch() -> String:
	var path = OUTPUT_BASE + "maps/json/"
	if not DirAccess.dir_exists_absolute(path): return "Map directory not found."
	
	var dir = DirAccess.open(path)
	var files = dir.get_files()
	if files.size() == 0: return "No JSON map files found in output."
	
	for file_name in files:
		if not file_name.ends_with(".json"): continue
		
		var f = FileAccess.open(path + file_name, FileAccess.READ)
		var json_string = f.get_as_text()
		var json = JSON.parse_string(json_string)
		
		if json == null: 
			return "File %s is corrupted or not valid JSON." % file_name
		if not json.has("Tiles"): 
			return "File %s missing 'Tiles' data key." % file_name
			
	return ""


#Iterates through ALL generated wall textures and verifies their dimensions.
func test_walls_batch() -> String:
	var path = OUTPUT_BASE + "walls/"
	if not DirAccess.dir_exists_absolute(path): return "Walls directory not found."
	
	var dir = DirAccess.open(path)
	var files = dir.get_files()
	if files.size() == 0: return "No wall textures found."
	
	for file_name in files:
		if not file_name.ends_with(".png"): continue
		
		var full_path = path + file_name
		var img = Image.load_from_file(full_path)
		
		if img == null: 
			return "Failed to load image: %s" % file_name
		if img.get_width() != 64 or img.get_height() != 64: 
			return "Invalid resolution in %s: %dx%d (Expected 64x64)" % [file_name, img.get_width(), img.get_height()]
			
	return ""


# Iterates through ALL generated audio files and verifies headers.
func test_audio_batch() -> String:
	var path = OUTPUT_BASE + "sounds/"
	if not DirAccess.dir_exists_absolute(path): return "Sounds directory not found."
	
	var dir = DirAccess.open(path)
	var files = dir.get_files()
	if files.size() == 0: return "No sound files found."
	
	for file_name in files:
		if not file_name.ends_with(".wav"): continue
		
		var f = FileAccess.open(path + file_name, FileAccess.READ)
		if f.get_length() < 44:
			return "File %s is too small to be a valid WAV." % file_name
			
		# The WAV file format stores the Sample Rate (Frequency) at byte offset 24.
		f.seek(24)
		var sample_rate = f.get_32()
		
		# Original Wolf3D sounds are digitized at 7042Hz.
		if sample_rate != 7042: 
			return "Incorrect Sample Rate in %s: %dHz (Expected 7042Hz)" % [file_name, sample_rate]
			
	return ""

func run_test(test_name: String, test_func: Callable, res: Dictionary):
	var error = test_func.call()
	if error == "":
		print("  [OK] %s" % test_name)
		res.passed += 1
	else:
		print("  [FAIL] %s -> %s" % [test_name, error])
		res.failed += 1
		res.errors.append(error)

func print_summary(res: Dictionary):
	print("\n" + "-".repeat(60))
	print("TEST SUMMARY: PASSED: %d | FAILED: %d" % [res.passed, res.failed])
	if res.failed > 0:
		print("Issues detected. Please check the logs above.")
	print("-".repeat(60) + "\n")
