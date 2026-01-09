# LevelComplete.gd
# Wolf3D Level Completion Screen - Shows stats after completing a level
extends CanvasLayer

const PICS_PATH = "res://assets/vga/pics/"

# Original Wolf3D positions (320x200)
const BJ_PIC_X = 48
const BJ_PIC_Y = 16
const TEXT_START_X = 168
const TEXT_START_Y = 24

# Timing for bonus counting animation
var count_timer: float = 0.0
var count_phase: int = 0  # 0=bonus, 1=time, 2=kill, 3=secret, 4=treasure, 5=done
var counting_done: bool = false

# Level stats
var floor_num: int = 1
var bonus_points: int = 0
var time_taken: float = 0.0
var par_time: float = 90.0
var kill_ratio: int = 0
var secret_ratio: int = 0
var treasure_ratio: int = 0

# UI elements
var bj_pic: TextureRect
var labels: Array[Label] = []
var scale_factor: float = 2.0

func _ready() -> void:
	# Allow this node to process while game is paused
	process_mode = PROCESS_MODE_ALWAYS
	
	# Calculate scale
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / 320.0
	
	# Get stats from GameState
	floor_num = GameState.current_map + 1
	if GameState.level_stats:
		time_taken = GameState.level_stats.level_time
		kill_ratio = GameState.level_stats.get_kill_ratio()
		secret_ratio = GameState.level_stats.get_secret_ratio()
		treasure_ratio = GameState.level_stats.get_treasure_ratio()
	
	# Calculate bonus (100% on each ratio = bonus)
	bonus_points = 0
	if kill_ratio == 100:
		bonus_points += 10000
	if secret_ratio == 100:
		bonus_points += 10000
	if treasure_ratio == 100:
		bonus_points += 10000
	
	# PAR times for each level (simplified - use 90 seconds default)
	par_time = 90.0
	
	_create_ui()

func _create_ui() -> void:
	# Dark blue background (matching original)
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.2, 0.4, 1.0)  # Dark blue like original
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# BJ Blazkowicz pic (040_L_GUYPIC.png)
	bj_pic = TextureRect.new()
	var bj_texture = _load_pic("040_L_GUYPIC.png")
	if bj_texture:
		bj_pic.texture = bj_texture
		bj_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bj_pic.stretch_mode = TextureRect.STRETCH_SCALE
		bj_pic.position = Vector2(BJ_PIC_X * scale_factor, BJ_PIC_Y * scale_factor)
		bj_pic.size = Vector2(bj_texture.get_width() * scale_factor, bj_texture.get_height() * scale_factor)
		add_child(bj_pic)
	
	# Create text labels
	var y_offset = TEXT_START_Y
	
	# FLOOR X COMPLETED
	_add_label("FLOOR %d" % floor_num, TEXT_START_X, y_offset, Color(0.0, 0.7, 1.0))
	y_offset += 16
	_add_label("COMPLETED", TEXT_START_X + 24, y_offset, Color(0.0, 0.7, 1.0))
	y_offset += 24
	
	# BONUS
	_add_label("BONUS", TEXT_START_X, y_offset, Color(0.0, 0.7, 1.0))
	_add_label("%d" % bonus_points, TEXT_START_X + 120, y_offset, Color.WHITE)
	y_offset += 24
	
	# TIME
	var minutes = int(time_taken) / 60
	var seconds = int(time_taken) % 60
	_add_label("TIME", TEXT_START_X + 24, y_offset, Color(0.0, 0.7, 1.0))
	_add_label("%02d:%02d" % [minutes, seconds], TEXT_START_X + 96, y_offset, Color.WHITE)
	y_offset += 16
	
	# PAR
	var par_min = int(par_time) / 60
	var par_sec = int(par_time) % 60
	_add_label("PAR", TEXT_START_X + 40, y_offset, Color(0.0, 0.7, 1.0))
	_add_label("%02d:%02d" % [par_min, par_sec], TEXT_START_X + 96, y_offset, Color.WHITE)
	y_offset += 32
	
	# KILL RATIO
	_add_label("KILL   RATIO", TEXT_START_X - 48, y_offset, Color(0.0, 0.7, 1.0))
	_add_label("%d%%" % kill_ratio, TEXT_START_X + 104, y_offset, Color.WHITE)
	y_offset += 16
	
	# SECRET RATIO
	_add_label("SECRET RATIO", TEXT_START_X - 48, y_offset, Color(0.0, 0.7, 1.0))
	_add_label("%d%%" % secret_ratio, TEXT_START_X + 104, y_offset, Color.WHITE)
	y_offset += 16
	
	# TREASURE RATIO
	_add_label("TREASURE RATIO", TEXT_START_X - 64, y_offset, Color(0.0, 0.7, 1.0))
	_add_label("%d%%" % treasure_ratio, TEXT_START_X + 104, y_offset, Color.WHITE)

func _add_label(text: String, x: float, y: float, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(x * scale_factor, y * scale_factor)
	add_child(label)
	labels.append(label)

func _load_pic(filename: String) -> Texture2D:
	var path = PICS_PATH + filename
	var texture = load(path) as Texture2D
	if texture:
		return texture
	var image = Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	return null

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

func _process(_delta: float) -> void:
	# Could add counting animation here
	pass
