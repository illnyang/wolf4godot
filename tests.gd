#!/usr/bin/env godot
extends SceneTree
#& "C:\Users\Kocio\Desktop\nowy\wolfgodot-master(11)\wolfgodot-master\wolfgodot.exe"  --headless -s tests.gd
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
	
	# DATA DETECTION: Scan for original game files.
	print("STEP 1: Detecting available game data...")
	extractor._detect_available_games()
	
	# EXTRACTION: If data is found, perform a trial extraction.
	if extractor.available_games.is_empty():
		print("[SKIP] No source files found. Skipping extraction, testing existing output.")
	else:
		print("STEP 2: Running trial extraction...")
		# Executes the specific Wolf3D extraction method defined in the source script.
		extractor._extract_game(extractor.GameType.WOLF3D)
	
	# SETTLE TIME: We wait 1.0 seconds to allow the OS to finalize file writes
	# and to ensure the Godot thread has finished processing the I/O buffer.
	await self.create_timer(1.0).timeout

	# VERIFICATION.
	var results = {"passed": 0, "failed": 0, "errors": []}

	print("\nSTEP 3: Verifying output files:")
	run_test("Directory Structure", test_directories, results)
	run_test("Maps: JSON Structure", test_maps, results)
	run_test("Walls: PNG Dimensions (64x64)", test_walls, results)
	run_test("Audio: WAV Header (7042Hz)", test_audio, results)

	# FINALIZATION.
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


## Verify that map data was successfully converted from binary to JSON format.
func test_maps() -> String:
	var path = OUTPUT_BASE + "maps/json/"
	if not DirAccess.dir_exists_absolute(path): return "Map directory not found."
	
	var dir = DirAccess.open(path)
	var files = dir.get_files()
	if files.size() == 0: return "No JSON map files found in output."
	
	# Load the first file and attempt to parse it as a JSON object.
	var f = FileAccess.open(path + files[0], FileAccess.READ)
	var json_string = f.get_as_text()
	var json = JSON.parse_string(json_string)
	
	if json == null: return "JSON file is corrupted or not valid JSON."
	# 'Tiles' is a specific key expected in our custom Wolf3D map format.
	if not json.has("Tiles"): return "JSON parsed but missing 'Tiles' data key."
	return ""


# Verify that walls were exported as valid images with the correct Wolf3D resolution.
func test_walls() -> String:
	var wall_path = OUTPUT_BASE + "walls/00.png"
	if not FileAccess.file_exists(wall_path): return "Wall texture '00.png' was not generated."
	
	var img = Image.load_from_file(wall_path)
	if img == null: return "File exists but could not be loaded as a Godot Image."
	# Original Wolf3D walls MUST be exactly 64x64 pixels.
	if img.get_width() != 64 or img.get_height() != 64: 
		return "Invalid resolution: %dx%d (Expected 64x64)" % [img.get_width(), img.get_height()]
	return ""


## Verify audio quality by inspecting the WAV header metadata.
func test_audio() -> String:
	var snd_path = OUTPUT_BASE + "sounds/HALTSND.wav"
	if not FileAccess.file_exists(snd_path): return "Sound file 'HALTSND.wav' is missing."
	
	var f = FileAccess.open(snd_path, FileAccess.READ)
	# The WAV file format stores the Sample Rate (Frequency) as a 4-byte 
	# Little-Endian integer starting at byte offset 24.
	f.seek(24)
	var sample_rate = f.get_32()
	
	# Wolfenstein 3D original sounds are digitized at 7042Hz.
	if sample_rate != 7042: 
		return "Incorrect Sample Rate: %dHz (Expected 7042Hz)" % sample_rate
	return ""


# --- UTILITY FUNCTIONS ---

## Generic wrapper to execute a test function and record its success or failure.
## [param test_name]: Descriptive name shown in the console.
## [param test_func]: The Callable function to execute.
## [param res]: The dictionary used to accumulate pass/fail counts.
func run_test(test_name: String, test_func: Callable, res: Dictionary):
	var error = test_func.call()
	if error == "":
		print("  [OK] %s" % test_name)
		res.passed += 1
	else:
		print("  [FAIL] %s -> %s" % [test_name, error])
		res.failed += 1
		res.errors.append(error)


## Displays the final results in a clean, readable format.
func print_summary(res: Dictionary):
	print("\n" + "-".repeat(60))
	print("TEST SUMMARY: PASSED: %d | FAILED: %d" % [res.passed, res.failed])
	if res.failed > 0:
		print("Issues detected. Please check the logs above.")
	print("-".repeat(60) + "\n")
