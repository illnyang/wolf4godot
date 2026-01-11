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

# UI elements
var scale_factor: float = 2.0
var bj_sprite: TextureRect
var bj_textures: Array[Texture2D] = []
var text_container: Control

# Stats
var floor_num: int = 1
var final_time_taken: float = 0.0
var final_kill_ratio: int = 0
var final_secret_ratio: int = 0
var final_treasure_ratio: int = 0
var par_time_str: String = "01:30"
var time_bonus_total: int = 0

# Animation State
enum Phase { TIME_BONUS, KILL_RATIO, SECRET_RATIO, TREASURE_RATIO, DONE }
var current_phase: Phase = Phase.TIME_BONUS

var display_time_bonus: int = 0
var display_kill_ratio: int = 0
var display_secret_ratio: int = 0
var display_treasure_ratio: int = 0

var anim_timer: float = 0.0
var phase_finished: bool = false
var bj_anim_timer: float = 0.0
var bj_frame: int = 0

# Character to image mapping
var char_pics: Dictionary = {}

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 100
	
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / float(ORIG_WIDTH)
	
	_load_assets()
	_init_stats()
	_create_ui()
	
	# Start music if available
	# SoundManager.play_music("ENDLEVEL_MUS")
	SoundManager.play_sfx("LEVELDONESND")

func _load_assets() -> void:
	# Load digits 0-9
	for i in range(10):
		var filename = "%03d_L_NUM%dPIC.png" % [42 + i, i]
		char_pics[str(i)] = _load_pic(filename)
	
	# Special characters
	char_pics[":"] = _load_pic("041_L_COLONPIC.png")
	char_pics["%"] = _load_pic("052_L_PERCENTPIC.png")
	char_pics["!"] = _load_pic("079_L_EXPOINTPIC.png")
	char_pics["'"] = _load_pic("080_L_APOSTROPHEPIC.png")
	
	# Letters A-Z
	for i in range(26):
		var letter = char("A".unicode_at(0) + i)
		var filename = "%03d_L_%sPIC.png" % [53 + i, letter]
		char_pics[letter] = _load_pic(filename)
	
	# BJ pics
	bj_textures.append(_load_pic("040_L_GUYPIC.png"))
	bj_textures.append(_load_pic("081_L_GUY2PIC.png"))

func _init_stats() -> void:
	floor_num = GameState.current_map + 1
	if GameState.level_stats:
		final_time_taken = GameState.level_stats.level_time
		final_kill_ratio = GameState.level_stats.get_kill_ratio()
		final_secret_ratio = GameState.level_stats.get_secret_ratio()
		final_treasure_ratio = GameState.level_stats.get_treasure_ratio()
	
	# Calculate time bonus
	var par_times = [1.5, 2, 2, 3.5, 3, 3, 2.5, 2.5, 0, 0] # Ep 1
	var par_time_strings = ["01:30", "02:00", "02:00", "03:30", "03:00", "03:00", "02:30", "02:30", "??:??", "??:??"]
	
	var level_idx = GameState.current_map % 10
	var par_seconds = par_times[level_idx] * 60.0
	par_time_str = par_time_strings[level_idx]
	
	if final_time_taken < par_seconds and par_seconds > 0:
		var time_left = int(par_seconds - final_time_taken)
		time_bonus_total = time_left * 500

func _create_ui() -> void:
	var window_size = get_viewport().get_visible_rect().size
	
	# Full screen background
	var bg = ColorRect.new()
	bg.color = Color(0.0, 65.0/255.0, 65.0/255.0, 1.0) # Original dark teal
	bg.size = window_size
	add_child(bg)
	
	text_container = Control.new()
	text_container.size = window_size
	add_child(text_container)
	
	# BJ Sprite
	bj_sprite = TextureRect.new()
	bj_sprite.texture = bj_textures[0]
	bj_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bj_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	bj_sprite.position = Vector2(0, 16 * scale_factor)
	bj_sprite.size = Vector2(bj_textures[0].get_width() * scale_factor, bj_textures[0].get_height() * scale_factor)
	add_child(bj_sprite)
	
	_update_display()

func _update_display() -> void:
	# Clear previous text
	for child in text_container.get_children():
		child.queue_free()
	
	_write(14, 2, "FLOOR")
	_write(14, 4, "COMPLETED")
	_write(26, 2, str(floor_num))
	
	_write(14, 7, "BONUS")
	_write_right(36, 7, str(display_time_bonus))
	
	_write(16, 10, "TIME")
	var m = int(final_time_taken) / 60
	var s = int(final_time_taken) % 60
	_write_time(26, 10, m, s)
	
	_write(16, 12, "PAR")
	_write(26, 12, par_time_str)
	
	_write(9, 14, "KILL RATIO")
	_write_right(37, 14, str(display_kill_ratio) + "%")
	
	_write(5, 16, "SECRET RATIO")
	_write_right(37, 16, str(display_secret_ratio) + "%")
	
	_write(1, 18, "TREASURE RATIO")
	_write_right(37, 18, str(display_treasure_ratio) + "%")
	
	# Show current score at the bottom status bar area (authentic style)
	_write(1, 22, "SCORE")
	_write_right(37, 22, str(GameState.score))

func _write(gx: int, gy: int, text: String) -> void:
	var px = gx * 8
	var py = gy * 8
	var cx = px
	for ch in text.to_upper():
		if ch == " ":
			cx += CHAR_WIDTH
		elif ch == "\n":
			cx = px
			py += CHAR_WIDTH
		else:
			_draw_char(cx, py, ch)
			cx += CHAR_SMALL if ch == ":" else CHAR_WIDTH

func _write_right(gx: int, gy: int, text: String) -> void:
	# Total width is 40 grid units (320px). Right align at gx.
	var length = 0
	for ch in text:
		length += 8 if ch == ":" else 16
	_write(gx - length/8, gy, text)

func _write_time(gx: int, gy: int, m: int, s: int) -> void:
	var time_str = "%02d:%02d" % [m, s]
	_write(gx, gy, time_str)

func _draw_char(x: float, y: float, ch: String) -> void:
	if not char_pics.has(ch): return
	var tex = char_pics[ch]
	if not tex: return
	var tr = TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = Vector2(x * scale_factor, y * scale_factor)
	tr.size = Vector2(tex.get_width() * scale_factor, tex.get_height() * scale_factor)
	text_container.add_child(tr)

func _process(delta: float) -> void:
	# BJ Breathing
	bj_anim_timer += delta
	if bj_anim_timer >= 0.5:
		bj_anim_timer = 0.0
		bj_frame = 1 - bj_frame
		bj_sprite.texture = bj_textures[bj_frame]
	
	# Counting Animation
	if current_phase == Phase.DONE: return
	
	anim_timer += delta
	if anim_timer < 0.02: return # Speed of counting
	anim_timer = 0.0
	
	match current_phase:
		Phase.TIME_BONUS:
			if display_time_bonus < time_bonus_total:
				var step = 500
				display_time_bonus = min(display_time_bonus + step, time_bonus_total)
				if display_time_bonus % 1000 == 0:
					SoundManager.play_sfx("ENDBONUS1SND")
				_update_display()
			else:
				_finish_phase()
				
		Phase.KILL_RATIO:
			if display_kill_ratio < final_kill_ratio:
				display_kill_ratio += 1
				if display_kill_ratio % 10 == 0:
					SoundManager.play_sfx("ENDBONUS1SND")
				_update_display()
			else:
				_finish_phase()
				
		Phase.SECRET_RATIO:
			if display_secret_ratio < final_secret_ratio:
				display_secret_ratio += 1
				if display_secret_ratio % 10 == 0:
					SoundManager.play_sfx("ENDBONUS1SND")
				_update_display()
			else:
				_finish_phase()
				
		Phase.TREASURE_RATIO:
			if display_treasure_ratio < final_treasure_ratio:
				display_treasure_ratio += 1
				if display_treasure_ratio % 10 == 0:
					SoundManager.play_sfx("ENDBONUS1SND")
				_update_display()
			else:
				_finish_phase()

func _finish_phase() -> void:
	match current_phase:
		Phase.TIME_BONUS:
			SoundManager.play_sfx("ENDBONUS2SND")
			current_phase = Phase.KILL_RATIO
		Phase.KILL_RATIO:
			_play_ratio_complete_sound(final_kill_ratio)
			current_phase = Phase.SECRET_RATIO
		Phase.SECRET_RATIO:
			_play_ratio_complete_sound(final_secret_ratio)
			current_phase = Phase.TREASURE_RATIO
		Phase.TREASURE_RATIO:
			_play_ratio_complete_sound(final_treasure_ratio)
			_finish_intermission()

func _play_ratio_complete_sound(ratio: int) -> void:
	if ratio == 100:
		SoundManager.play_sfx("PERCENT100SND")
	elif ratio == 0:
		SoundManager.play_sfx("NOITEMSND") # Approximate NOBONUSSND
	else:
		SoundManager.play_sfx("ENDBONUS2SND")

func _finish_intermission() -> void:
	current_phase = Phase.DONE
	# Award bonuses to GameState
	var total_bonus = time_bonus_total
	if final_kill_ratio == 100: total_bonus += 10000
	if final_secret_ratio == 100: total_bonus += 10000
	if final_treasure_ratio == 100: total_bonus += 10000
	
	GameState.give_points(total_bonus)
	_update_display()

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			if current_phase != Phase.DONE:
				# Skip animation
				_skip_to_end()
			else:
				# Proceed to next level
				_proceed()

func _skip_to_end() -> void:
	display_time_bonus = time_bonus_total
	display_kill_ratio = final_kill_ratio
	display_secret_ratio = final_secret_ratio
	display_treasure_ratio = final_treasure_ratio
	_finish_intermission()

func _proceed() -> void:
	GameState.current_map += 1
	var next_map_path = _get_next_map_path()
	if next_map_path != "":
		GameState.selected_map_path = next_map_path
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://main.tscn")
	queue_free()

func _get_next_map_path() -> String:
	var maps_path = "user://assets/%s/maps/json/" % GameState.selected_game
	var dir = DirAccess.open(maps_path)
	if not dir: return ""
	var map_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			map_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	map_files.sort()
	if GameState.current_map < map_files.size():
		return maps_path + map_files[GameState.current_map]
	return ""

func _load_pic(filename: String) -> Texture2D:
	var path = PICS_PATH + filename
	var tex = load(path) as Texture2D
	if tex: return tex
	var img = Image.load_from_file(path)
	if img: return ImageTexture.create_from_image(img)
	return null
