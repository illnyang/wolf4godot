# LevelComplete.gd
# Wolf3D Level Completion Screen - Authentic 1:1 recreation using original image-based fonts
extends CanvasLayer

const PICS_PATH = "res://assets/vga/pics/"

# Original Wolf3D resolution
const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200

# Character size in original game
const CHAR_WIDTH = 16  # Most characters are 16 pixels wide
const CHAR_SMALL = 8   # Some characters like ':' are 8 pixels wide

# BJ breathing animation
const BJ_BREATHE_INTERVAL = 0.5  # ~35 ticks / 70 ticks per second

# Character to image mapping (following original WL_INTER.C Write() function)
# Index in alpha array: '0'-'9' = 0-9, ':' = 10, then skip to 'A'-'Z' = 17+
var char_pics: Dictionary = {}

# Level stats
var floor_num: int = 1
var bonus_points: int = 0
var time_taken: float = 0.0
var par_time: float = 90.0
var par_time_str: String = "01:30"
var kill_ratio: int = 0
var secret_ratio: int = 0
var treasure_ratio: int = 0

# UI elements
var scale_factor: float = 2.0
var bj_sprite: TextureRect
var bj_textures: Array[Texture2D] = []
var bj_anim_timer: float = 0.0
var bj_current_frame: int = 0

# Container for all text sprites
var text_container: Control

func _ready() -> void:
	# Allow this node to process while game is paused
	process_mode = PROCESS_MODE_ALWAYS
	
	# Calculate scale
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / float(ORIG_WIDTH)
	
	# Load character images
	_load_character_pics()
	
	# Get stats from GameState
	floor_num = GameState.current_map + 1
	if GameState.level_stats:
		time_taken = GameState.level_stats.level_time
		kill_ratio = GameState.level_stats.get_kill_ratio()
		secret_ratio = GameState.level_stats.get_secret_ratio()
		treasure_ratio = GameState.level_stats.get_treasure_ratio()
	
	# Calculate bonus (100% on each ratio = 10000 bonus)
	bonus_points = 0
	if kill_ratio == 100:
		bonus_points += 10000
	if secret_ratio == 100:
		bonus_points += 10000
	if treasure_ratio == 100:
		bonus_points += 10000
	
	# Get PAR time for this level
	_set_par_time()
	
	_create_ui()

func _load_character_pics() -> void:
	# Load number pics (0-9)
	for i in range(10):
		var filename = "%03d_L_NUM%dPIC.png" % [42 + i, i]
		char_pics[str(i)] = _load_pic(filename)
	
	# Load colon
	char_pics[":"] = _load_pic("041_L_COLONPIC.png")
	
	# Load percent
	char_pics["%"] = _load_pic("052_L_PERCENTPIC.png")
	
	# Load letters A-Z
	var letter_start = 53
	for i in range(26):
		var letter = char("A".unicode_at(0) + i)
		var filename = "%03d_L_%sPIC.png" % [letter_start + i, letter]
		char_pics[letter] = _load_pic(filename)
	
	# Load special characters
	char_pics["!"] = _load_pic("079_L_EXPOINTPIC.png")
	char_pics["'"] = _load_pic("080_L_APOSTROPHEPIC.png")
	
	# Load BJ pics for animation
	bj_textures.append(_load_pic("040_L_GUYPIC.png"))
	bj_textures.append(_load_pic("081_L_GUY2PIC.png"))

func _set_par_time() -> void:
	# PAR times from original Wolf3D (episode 1 for now)
	var par_times = [
		[1.5, "01:30"], [2.0, "02:00"], [2.0, "02:00"], [3.5, "03:30"], [3.0, "03:00"],
		[3.0, "03:00"], [2.5, "02:30"], [2.5, "02:30"], [0.0, "??:??"], [0.0, "??:??"]
	]
	
	var level_idx = (GameState.current_map) % 10
	if level_idx < par_times.size():
		par_time = par_times[level_idx][0] * 60.0  # Convert minutes to seconds
		par_time_str = par_times[level_idx][1]
	else:
		par_time = 90.0
		par_time_str = "01:30"

func _create_ui() -> void:
	# Dark blue/gray background (color 127 in original palette = #7F7F7F, but original uses darker blue)
	var bg = ColorRect.new()
	bg.color = Color(0.298, 0.298, 0.498, 1.0)  # Approximation of original blue-gray
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Container for text
	text_container = Control.new()
	text_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(text_container)
	
	# BJ Blazkowicz pic at (0, 16) in original coordinates
	bj_sprite = TextureRect.new()
	if bj_textures.size() > 0 and bj_textures[0]:
		bj_sprite.texture = bj_textures[0]
		bj_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bj_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		bj_sprite.position = Vector2(0, 16 * scale_factor)
		bj_sprite.size = Vector2(bj_textures[0].get_width() * scale_factor, bj_textures[0].get_height() * scale_factor)
		add_child(bj_sprite)
	
	# Draw all text using original coordinates (in 8-pixel grid units)
	# "FLOOR" at (14, 2) and "\nCOMPLETED" 
	_write(14, 2, "FLOOR")
	_write(14, 4, "COMPLETED")
	
	# Floor number at (26, 2)
	_write(26, 2, str(floor_num))
	
	# "BONUS" at (14, 7) with value
	_write(14, 7, "BONUS")
	var bonus_str = str(bonus_points)
	var bonus_x = 36 - len(bonus_str) * 2  # Right-align
	_write(bonus_x, 7, bonus_str)
	
	# "TIME" at (16, 10) with value
	_write(16, 10, "TIME")
	var minutes = int(time_taken) / 60
	var seconds = int(time_taken) % 60
	if minutes > 99:
		minutes = 99
		seconds = 99
	# Draw time at position 26
	_write_time(26, 10, minutes, seconds)
	
	# "PAR" at (16, 12) with value
	_write(16, 12, "PAR")
	_write(26, 12, par_time_str)
	
	# Ratio labels and values
	# "KILL RATIO" at (9, 14)
	_write(9, 14, "KILL RATIO")
	var kr_str = str(kill_ratio) + "%"
	_write(37 - len(kr_str) * 2, 14, kr_str)
	
	# "SECRET RATIO" at (5, 16)
	_write(5, 16, "SECRET RATIO")
	var sr_str = str(secret_ratio) + "%"
	_write(37 - len(sr_str) * 2, 16, sr_str)
	
	# "TREASURE RATIO" at (1, 18)  
	_write(1, 18, "TREASURE RATIO")
	var tr_str = str(treasure_ratio) + "%"
	_write(37 - len(tr_str) * 2, 18, tr_str)

func _write(grid_x: int, grid_y: int, text: String) -> void:
	# Convert grid coordinates to pixels (8 pixels per grid unit)
	var px = grid_x * 8
	var py = grid_y * 8
	
	var current_x = px
	
	for ch in text.to_upper():
		if ch == " ":
			current_x += CHAR_WIDTH
			continue
		elif ch == "\n":
			current_x = px
			py += CHAR_WIDTH
			continue
		elif ch == ":":
			_draw_char(current_x, py, ch)
			current_x += CHAR_SMALL
			continue
		else:
			_draw_char(current_x, py, ch)
			current_x += CHAR_WIDTH

func _write_time(grid_x: int, grid_y: int, minutes: int, seconds: int) -> void:
	# Draw time in MM:SS format using number pics
	var px = grid_x * 8
	var py = grid_y * 8
	
	# Minutes tens digit
	_draw_char(px, py, str(minutes / 10))
	px += CHAR_WIDTH
	# Minutes ones digit
	_draw_char(px, py, str(minutes % 10))
	px += CHAR_WIDTH
	# Colon
	_draw_char(px, py, ":")
	px += CHAR_SMALL
	# Seconds tens digit
	_draw_char(px, py, str(seconds / 10))
	px += CHAR_WIDTH
	# Seconds ones digit
	_draw_char(px, py, str(seconds % 10))

func _draw_char(x: float, y: float, ch: String) -> void:
	if not char_pics.has(ch):
		return
	
	var texture = char_pics[ch]
	if texture == null:
		return
	
	var img = TextureRect.new()
	img.texture = texture
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.position = Vector2(x * scale_factor, y * scale_factor)
	img.size = Vector2(texture.get_width() * scale_factor, texture.get_height() * scale_factor)
	text_container.add_child(img)

func _load_pic(filename: String) -> Texture2D:
	var path = PICS_PATH + filename
	var texture = load(path) as Texture2D
	if texture:
		return texture
	# Try loading as raw image file
	var image = Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	return null

func _process(delta: float) -> void:
	# BJ breathing animation
	bj_anim_timer += delta
	if bj_anim_timer >= BJ_BREATHE_INTERVAL:
		bj_anim_timer = 0.0
		bj_current_frame = 1 - bj_current_frame  # Toggle 0 <-> 1
		if bj_sprite and bj_textures.size() > bj_current_frame and bj_textures[bj_current_frame]:
			bj_sprite.texture = bj_textures[bj_current_frame]

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			# Add bonus to score
			GameState.give_points(bonus_points)
			
			# Proceed to next level
			GameState.current_map += 1
			
			# Update the map path to the next level
			var next_map_path = _get_next_map_path()
			if next_map_path != "":
				GameState.selected_map_path = next_map_path
				GameState.start_level()
				
				# Unpause and reload scene for next level
				get_tree().paused = false
				get_tree().reload_current_scene()
			else:
				# No more levels - back to main menu
				get_tree().paused = false
				get_tree().change_scene_to_file("res://main.tscn")
			
			queue_free()

func _get_next_map_path() -> String:
	# Scan maps folder and find the map at current_map index
	var maps_path = "user://assets/%s/maps/json/" % GameState.selected_game
	var dir = DirAccess.open(maps_path)
	if dir == null:
		return ""
	
	var map_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			map_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Sort by filename
	map_files.sort()
	
	# Get the map at current_map index
	if GameState.current_map < map_files.size():
		return maps_path + map_files[GameState.current_map]
	
	return ""  # No more maps
