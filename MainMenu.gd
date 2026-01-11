# MainMenu.gd
# Authentic Wolf3D-style main menu with original graphics
extends Control

# Original Wolf3D coordinates (320x200 VGA)
const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200

# Menu layout from WL_MENU.H
const MENU_X = 76
const MENU_Y = 55
const MENU_W = 178
const MENU_H = 136

# Colors from Wolf3D palette (indices to RGB)
# BKGDCOLOR = 0x2d (often red/purple depending on version), here user specifically wants 138 RED
const COLOR_BACKGROUND = Color(164.0/255.0, 0.0, 0.0)  # Index 138 Red
const COLOR_BORDER = Color(110.0/255.0, 0.0, 0.0)      # Darker red for borders
const COLOR_STRIPE = Color(0.0, 0.0, 0.0)             # Black stripes
const COLOR_TEXT = Color(0.9, 0.9, 0.9)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.0)  # Yellow
const COLOR_DEACTIVE = Color(0.5, 0.5, 0.5)
const COLOR_VIEW_BORDER = Color(0.0, 65.0/255.0, 65.0/255.0)  # Authentic teal/cyan

# Menu states
enum MenuState { MAIN, EPISODE_SELECT, DIFFICULTY_SELECT, GAME_SELECT, MAP_SELECT, VIEW_SIZE, SAVE_GAME, LOAD_GAME }
var current_state: MenuState = MenuState.MAIN

# Selection indices
var main_menu_index: int = 0
var episode_index: int = 0
var difficulty_index: int = 1  # Default to "Bring 'em on!"
var game_index: int = 0
var map_index: int = 0
var save_slot_index: int = 0

# Save game system
const MAX_SAVE_SLOTS = 8
var save_slots: Array[Dictionary] = []
var save_input_text: String = ""
var save_input_active: bool = false

# Available games and maps
var available_games: Array[Dictionary] = []
var available_maps: Array[Dictionary] = []
var selected_episode: int = 0

# Scale factor for 320x200 -> current resolution
var scale_factor: float = 1.0

# Store view size before entering Change View screen
var pre_view_size: int = 15

# Track if we entered menu from game (before flag is reset)
var entered_from_game: bool = false

# Loaded textures
var pics: Dictionary = {}

# UI nodes
var background: TextureRect
var menu_window: ColorRect
var cursor_rect: TextureRect
var cursor_frame: int = 0
var cursor_timer: float = 0.0

# Menu options with original Wolf3D labels
var main_menu_options = [
	{"text": "New Game", "active": true},
	{"text": "Sound", "active": true},
	{"text": "Control", "active": true},
	{"text": "Load Game", "active": false},  # Disabled until saves exist
	{"text": "Save Game", "active": false},  # Disabled until in-game
	{"text": "Change View", "active": true},
	{"text": "Read This!", "active": true},
	{"text": "View Scores", "active": true},
	{"text": "Back to Demo", "active": true},
	{"text": "Quit", "active": true}
]

var episode_options = [
	{"text": "Episode 1\nEscape from Wolfenstein", "pic": "C_EPISODE1PIC"},
	{"text": "Episode 2\nOperation: Eisenfaust", "pic": "C_EPISODE2PIC"},
	{"text": "Episode 3\nDie, Fuhrer, Die!", "pic": "C_EPISODE3PIC"},
	{"text": "Episode 4\nA Dark Secret", "pic": "C_EPISODE4PIC"},
	{"text": "Episode 5\nTrail of the Madman", "pic": "C_EPISODE5PIC"},
	{"text": "Episode 6\nConfrontation", "pic": "C_EPISODE6PIC"}
]

var difficulty_options = [
	{"text": "Can I play, Daddy?", "pic": "C_BABYMODEPIC"},
	{"text": "Don't hurt me.", "pic": "C_EASYPIC"},
	{"text": "Bring 'em on!", "pic": "C_NORMALPIC"},
	{"text": "I am Death incarnate!", "pic": "C_HARDPIC"}
]


func _ready() -> void:
	# Wait for extraction
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	# Run extraction tests (output appears in console)
	var TestRunner = preload("res://tests/test_extraction.gd")
	TestRunner.run_all()
	
	_calculate_scale()
	_load_pics()
	_detect_games()
	_create_ui()
	
	# Check if coming from game
	if GameState.menu_from_game:
		# We're coming from in-game, enable Save Game option and add Resume option
		entered_from_game = true
		
		# Add "Resume Game" as first option if not already there
		if main_menu_options[0].text != "Resume Game":
			main_menu_options.insert(0, {"text": "Resume Game", "active": true})
		
		# Enable Save Game (now at index 5 because of Resume Game insertion)
		main_menu_options[5].active = true  # Save Game
		
		GameState.menu_from_game = false  # Reset flag
	
	_show_main_menu()
	
	# Play title music - already played in TitleScreen
	# MusicManager.play_title_music()


func _calculate_scale() -> void:
	var window_size = get_viewport().get_visible_rect().size
	# Scale to fit 320x200 into window, maintaining aspect ratio
	var scale_x = window_size.x / ORIG_WIDTH
	var scale_y = window_size.y / ORIG_HEIGHT
	scale_factor = min(scale_x, scale_y)


func _get_pics_path() -> String:
	# Try runtime extracted first, fall back to pre-extracted
	var game_id = GameState.selected_game if GameState.selected_game != "" else "wolf3d"
	var user_path = "user://assets/%s/pics/" % game_id
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(user_path)):
		return user_path
	return "res://assets/vga/pics/"


func _load_pics() -> void:
	var path = _get_pics_path()
	
	# Load all needed pics
	var pic_files = {
		"TITLEPIC": "084_TITLEPIC.png",
		"C_OPTIONSPIC": "007_C_OPTIONSPIC.png",
		"C_MOUSELBACKPIC": "015_C_MOUSELBACKPIC.png",
		"C_CURSOR1PIC": "008_C_CURSOR1PIC.png",
		"C_CURSOR2PIC": "009_C_CURSOR2PIC.png",
		"C_BABYMODEPIC": "016_C_BABYMODEPIC.png",
		"C_EASYPIC": "017_C_EASYPIC.png",
		"C_NORMALPIC": "018_C_NORMALPIC.png",
		"C_HARDPIC": "019_C_HARDPIC.png",
		"C_EPISODE1PIC": "027_C_EPISODE1PIC.png",
		"C_EPISODE2PIC": "028_C_EPISODE2PIC.png",
		"C_EPISODE3PIC": "029_C_EPISODE3PIC.png",
		"C_EPISODE4PIC": "030_C_EPISODE4PIC.png",
		"C_EPISODE5PIC": "031_C_EPISODE5PIC.png",
		"C_EPISODE6PIC": "032_C_EPISODE6PIC.png",
		"C_LOADGAMEPIC": "025_C_LOADGAMEPIC.png",
		"C_SAVEGAMEPIC": "026_C_SAVEGAMEPIC.png",
		"HIGHSCORESPIC": "087_HIGHSCORESPIC.png"
	}
	
	for pic_name in pic_files:
		var full_path = path + pic_files[pic_name]
		var texture = _load_texture(full_path)
		if texture:
			pics[pic_name] = texture


func _load_texture(path: String) -> Texture2D:
	# Try load() first for res:// paths
	if path.begins_with("res://"):
		var tex = load(path)
		if tex:
			return tex
	
	# For user:// paths, load image directly
	var image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image:
		return ImageTexture.create_from_image(image)
	
	# Fallback to res:// version
	var fallback_path = "res://assets/vga/pics/" + path.get_file()
	return load(fallback_path)


func _detect_games() -> void:
	available_games.clear()
	
	# Check for Wolf3D
	if DirAccess.open("user://assets/wolf3d/maps/json/") != null:
		available_games.append({
			"id": "wolf3d",
			"name": "WOLFENSTEIN 3D",
			"maps_path": "user://assets/wolf3d/maps/json/"
		})
	
	# Check for SOD
	if DirAccess.open("user://assets/sod/maps/json/") != null:
		available_games.append({
			"id": "sod",
			"name": "SPEAR OF DESTINY",
			"maps_path": "user://assets/sod/maps/json/"
		})
	
	# Check for Blake Stone
	if DirAccess.open("user://assets/blake_stone/maps/json/") != null:
		available_games.append({
			"id": "blake_stone",
			"name": "BLAKE STONE",
			"maps_path": "user://assets/blake_stone/maps/json/"
		})
	
	# Auto-select Wolf3D if available
	if available_games.size() >= 1:
		GameState.selected_game = available_games[0].id


func _create_ui() -> void:
	# Create background (will be set per screen)
	background = TextureRect.new()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Cursor
	cursor_rect = TextureRect.new()
	cursor_rect.texture = pics.get("C_CURSOR1PIC")
	cursor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cursor_rect.visible = false
	add_child(cursor_rect)


func _show_main_menu() -> void:
	current_state = MenuState.MAIN
	main_menu_index = 0
	
	# Check if there are any saved games
	var has_saves = _check_for_saved_games()
	print("[MainMenu] has_saves = ", has_saves, ", setting Load Game active to: ", has_saves)
	
	# Find Load Game option (account for Resume Game being inserted)
	var load_game_index = -1
	for i in range(main_menu_options.size()):
		if main_menu_options[i].text == "Load Game":
			load_game_index = i
			break
	
	if load_game_index >= 0:
		main_menu_options[load_game_index].active = has_saves
		print("[MainMenu] Set Load Game (index ", load_game_index, ") active = ", has_saves)
	
	_clear_menu_items()
	_draw_menu_background()
	
	# Draw menu header (C_OPTIONSPIC)
	if pics.has("C_OPTIONSPIC"):
		var header = TextureRect.new()
		header.name = "MenuHeader"
		header.texture = pics["C_OPTIONSPIC"]
		header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.stretch_mode = TextureRect.STRETCH_SCALE
		header.position = Vector2(84 * scale_factor, 0)
		header.size = Vector2(pics["C_OPTIONSPIC"].get_width() * scale_factor, 
							   pics["C_OPTIONSPIC"].get_height() * scale_factor)
		add_child(header)
	
	# Draw menu items
	var menu_start_y = MENU_Y + 10
	for i in range(main_menu_options.size()):
		var item = main_menu_options[i]
		var label = Label.new()
		label.name = "MenuItem_%d" % i
		label.text = item.text
		label.add_theme_font_size_override("font_size", int(12 * scale_factor))
		
		if not item.active:
			label.add_theme_color_override("font_color", COLOR_DEACTIVE)
		elif i == main_menu_index:
			label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			label.add_theme_color_override("font_color", COLOR_TEXT)
		
		label.position = Vector2((MENU_X + 24) * scale_factor, (menu_start_y + i * 13) * scale_factor)
		add_child(label)
	
	# Draw footer (C_MOUSELBACKPIC)
	if pics.has("C_MOUSELBACKPIC"):
		var footer = TextureRect.new()
		footer.name = "MenuFooter"
		footer.texture = pics["C_MOUSELBACKPIC"]
		footer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		footer.stretch_mode = TextureRect.STRETCH_SCALE
		footer.position = Vector2(112 * scale_factor, 184 * scale_factor)
		footer.size = Vector2(pics["C_MOUSELBACKPIC"].get_width() * scale_factor,
							   pics["C_MOUSELBACKPIC"].get_height() * scale_factor)
		add_child(footer)
	
	_update_cursor()


func _show_episode_select() -> void:
	current_state = MenuState.EPISODE_SELECT
	episode_index = 0
	
	_clear_menu_items()
	_draw_menu_background()
	
	# Episode selection header
	var header = Label.new()
	header.name = "EpisodeHeader"
	header.text = "Which episode to play?"
	header.add_theme_font_size_override("font_size", int(14 * scale_factor))
	header.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 30 * scale_factor)
	header.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(header)
	
	# Draw episode options
	for i in range(episode_options.size()):
		var ep = episode_options[i]
		
		# Episode pic
		if pics.has(ep.pic):
			var pic_rect = TextureRect.new()
			pic_rect.name = "EpisodePic_%d" % i
			pic_rect.texture = pics[ep.pic]
			pic_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic_rect.stretch_mode = TextureRect.STRETCH_SCALE
			pic_rect.position = Vector2(30 * scale_factor, (50 + i * 24) * scale_factor)
			pic_rect.size = Vector2(pics[ep.pic].get_width() * scale_factor,
									 pics[ep.pic].get_height() * scale_factor)
			add_child(pic_rect)
		
		# Episode text
		var label = Label.new()
		label.name = "EpisodeLabel_%d" % i
		label.text = ep.text.split("\n")[0]  # Just first line
		label.add_theme_font_size_override("font_size", int(10 * scale_factor))
		label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == episode_index else COLOR_TEXT)
		label.position = Vector2(120 * scale_factor, (52 + i * 24) * scale_factor)
		add_child(label)
	
	_update_cursor()


func _show_difficulty_select() -> void:
	current_state = MenuState.DIFFICULTY_SELECT
	difficulty_index = 2  # Default to "Bring 'em on!"
	
	_clear_menu_items()
	_draw_menu_background()
	
	# Header
	var header = Label.new()
	header.name = "DifficultyHeader"
	header.text = "How tough are you?"
	header.add_theme_font_size_override("font_size", int(14 * scale_factor))
	header.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 50 * scale_factor)
	header.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(header)
	
	# Draw difficulty options with face pics
	for i in range(difficulty_options.size()):
		var diff = difficulty_options[i]
		
		# Face pic
		if pics.has(diff.pic):
			var pic_rect = TextureRect.new()
			pic_rect.name = "DiffPic_%d" % i
			pic_rect.texture = pics[diff.pic]
			pic_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic_rect.stretch_mode = TextureRect.STRETCH_SCALE
			pic_rect.position = Vector2(50 * scale_factor, (85 + i * 26) * scale_factor)
			pic_rect.size = Vector2(pics[diff.pic].get_width() * scale_factor,
									 pics[diff.pic].get_height() * scale_factor)
			add_child(pic_rect)
		
		# Difficulty text
		var label = Label.new()
		label.name = "DiffLabel_%d" % i
		label.text = diff.text
		label.add_theme_font_size_override("font_size", int(11 * scale_factor))
		label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == difficulty_index else COLOR_TEXT)
		label.position = Vector2(130 * scale_factor, (90 + i * 26) * scale_factor)
		add_child(label)
	
	_update_cursor()


func _show_map_select() -> void:
	current_state = MenuState.MAP_SELECT
	map_index = 0
	
	# Calculate which map to start based on episode (10 maps per episode)
	var start_map = selected_episode * 10
	
	# Scan maps for selected game
	var maps_path = "user://assets/%s/maps/json/" % GameState.selected_game
	_scan_maps(maps_path)
	
	_clear_menu_items()
	_draw_menu_background()
	
	# Header
	var header = Label.new()
	header.name = "MapHeader"
	header.text = "Select Level - Episode %d" % (selected_episode + 1)
	header.add_theme_font_size_override("font_size", int(14 * scale_factor))
	header.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 30 * scale_factor)
	header.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(header)
	
	# Show maps for this episode (max 10)
	var episode_maps = []
	for i in range(start_map, mini(start_map + 10, available_maps.size())):
		episode_maps.append(available_maps[i])
	
	for i in range(episode_maps.size()):
		var label = Label.new()
		label.name = "MapLabel_%d" % i
		label.text = episode_maps[i].name
		label.add_theme_font_size_override("font_size", int(10 * scale_factor))
		label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == map_index else COLOR_TEXT)
		label.position = Vector2(80 * scale_factor, (50 + i * 14) * scale_factor)
		add_child(label)
	
	_update_cursor()


func _scan_maps(maps_path: String) -> void:
	available_maps.clear()
	
	var dir = DirAccess.open(maps_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var map_info = {
				"filename": file_name,
				"path": maps_path + file_name,
				"name": _extract_map_name(file_name)
			}
			available_maps.append(map_info)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	available_maps.sort_custom(func(a, b): return a.filename < b.filename)


func _extract_map_name(filename: String) -> String:
	var name = filename.replace(".json", "")
	var underscore_pos = name.find("_")
	if underscore_pos >= 0 and underscore_pos < 3:
		name = name.substr(underscore_pos + 1)
	return name


func _draw_menu_background() -> void:
	# Dark background
	background.texture = null
	background.visible = false
	
	var bg = ColorRect.new()
	bg.name = "MenuBG"
	bg.color = COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Draw stripes at top
	for i in range(0, 10, 2):
		var stripe = ColorRect.new()
		stripe.name = "Stripe_%d" % i
		stripe.color = COLOR_STRIPE
		stripe.position = Vector2(0, (10 + i * 2) * scale_factor)
		stripe.size = Vector2(get_viewport().get_visible_rect().size.x, 2 * scale_factor)
		add_child(stripe)
	
	# Menu window
	var window = ColorRect.new()
	window.name = "MenuWindow"
	window.color = Color(0.1, 0.0, 0.0, 0.95)  # Very dark red/black for window background
	window.position = Vector2((MENU_X - 8) * scale_factor, (MENU_Y - 3) * scale_factor)
	window.size = Vector2(MENU_W * scale_factor, MENU_H * scale_factor)
	add_child(window)
	
	# Window border
	var border = ColorRect.new()
	border.name = "WindowBorder"
	border.color = COLOR_BORDER
	border.position = Vector2((MENU_X - 10) * scale_factor, (MENU_Y - 5) * scale_factor)
	border.size = Vector2((MENU_W + 4) * scale_factor, (MENU_H + 4) * scale_factor)
	add_child(border)
	move_child(border, get_child_count() - 2)  # Behind window


func _clear_menu_items() -> void:
	# Remove all children except background and cursor
	for child in get_children():
		if child != background and child != cursor_rect:
			child.queue_free()


func _update_cursor() -> void:
	cursor_rect.texture = pics.get("C_CURSOR1PIC") if cursor_frame == 0 else pics.get("C_CURSOR2PIC")
	cursor_rect.visible = true
	
	# Scale cursor
	if cursor_rect.texture:
		cursor_rect.size = Vector2(cursor_rect.texture.get_width() * scale_factor,
									cursor_rect.texture.get_height() * scale_factor)
	
	var target_y: float = 0
	var target_x: float = 0
	
	match current_state:
		MenuState.MAIN:
			target_x = (MENU_X) * scale_factor
			target_y = (MENU_Y + 10 + main_menu_index * 13) * scale_factor
		MenuState.EPISODE_SELECT:
			target_x = 15 * scale_factor
			target_y = (52 + episode_index * 24) * scale_factor
		MenuState.DIFFICULTY_SELECT:
			target_x = 35 * scale_factor
			target_y = (88 + difficulty_index * 26) * scale_factor
		MenuState.MAP_SELECT:
			target_x = 65 * scale_factor
			target_y = (50 + map_index * 14) * scale_factor
		MenuState.SAVE_GAME:
			if not save_input_active:
				target_x = (MENU_X) * scale_factor
				target_y = (MENU_Y + 10 + save_slot_index * 15) * scale_factor
			else:
				# Hide cursor when typing
				cursor_rect.visible = false
				return
		MenuState.LOAD_GAME:
			target_x = (MENU_X) * scale_factor
			target_y = (MENU_Y + 10 + save_slot_index * 15) * scale_factor
	
	cursor_rect.position = Vector2(target_x, target_y)
	
	# Ensure cursor is on top
	move_child(cursor_rect, get_child_count() - 1)


func _update_menu_highlights() -> void:
	match current_state:
		MenuState.MAIN:
			for i in range(main_menu_options.size()):
				var label = get_node_or_null("MenuItem_%d" % i) as Label
				if label:
					if not main_menu_options[i].active:
						label.add_theme_color_override("font_color", COLOR_DEACTIVE)
					elif i == main_menu_index:
						label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
					else:
						label.add_theme_color_override("font_color", COLOR_TEXT)
		
		MenuState.EPISODE_SELECT:
			for i in range(episode_options.size()):
				var label = get_node_or_null("EpisodeLabel_%d" % i) as Label
				if label:
					label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == episode_index else COLOR_TEXT)
		
		MenuState.DIFFICULTY_SELECT:
			for i in range(difficulty_options.size()):
				var label = get_node_or_null("DiffLabel_%d" % i) as Label
				if label:
					label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == difficulty_index else COLOR_TEXT)
		
		MenuState.MAP_SELECT:
			var visible_count = get_children().filter(func(c): return c.name.begins_with("MapLabel_")).size()
			for i in range(visible_count):
				var label = get_node_or_null("MapLabel_%d" % i) as Label
				if label:
					label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == map_index else COLOR_TEXT)
		
		MenuState.SAVE_GAME:
			for i in range(MAX_SAVE_SLOTS):
				var label = get_node_or_null("SaveSlot_%d" % i) as Label
				if label:
					label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == save_slot_index else COLOR_TEXT)
		
		MenuState.LOAD_GAME:
			for i in range(MAX_SAVE_SLOTS):
				var label = get_node_or_null("SaveSlot_%d" % i) as Label
				if label:
					label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == save_slot_index else COLOR_TEXT)


func _process(delta: float) -> void:
	# Animate cursor
	cursor_timer += delta
	if cursor_timer > 0.15:
		cursor_timer = 0.0
		cursor_frame = 1 - cursor_frame
		if cursor_rect.visible:
			cursor_rect.texture = pics.get("C_CURSOR1PIC") if cursor_frame == 0 else pics.get("C_CURSOR2PIC")


func _input(event: InputEvent) -> void:
	# Handle text input for save game name - check this FIRST before action presses
	if current_state == MenuState.SAVE_GAME and save_input_active:
		if event is InputEventKey and event.pressed and not event.is_echo():
			print("[Input] Key pressed - keycode: ", event.keycode, ", unicode: ", event.unicode)
			# Handle backspace
			if event.keycode == KEY_BACKSPACE:
				if save_input_text.length() > 0:
					save_input_text = save_input_text.substr(0, save_input_text.length() - 1)
					print("[Input] After backspace: '", save_input_text, "'")
					_refresh_save_screen()
				get_viewport().set_input_as_handled()
				return
			# Handle regular characters (printable ASCII)
			elif event.unicode >= 32 and event.unicode < 127:
				if save_input_text.length() < 24:
					save_input_text += char(event.unicode)
					print("[Input] After add char: '", save_input_text, "'")
					_refresh_save_screen()
				get_viewport().set_input_as_handled()
				return
			# Let ENTER and ESC pass through
			elif event.keycode != KEY_ENTER and event.keycode != KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				return
	
	if event.is_action_pressed("ui_accept"):
		_handle_accept()
	elif event.is_action_pressed("ui_cancel"):
		_handle_cancel()
	elif event.is_action_pressed("ui_up"):
		_handle_up()
	elif event.is_action_pressed("ui_down"):
		_handle_down()
	elif event.is_action_pressed("ui_left"):
		_handle_left()
	elif event.is_action_pressed("ui_right"):
		_handle_right()


func _handle_accept() -> void:
	match current_state:
		MenuState.MAIN:
			_handle_main_menu_select()
		MenuState.EPISODE_SELECT:
			selected_episode = episode_index
			_show_difficulty_select()
		MenuState.DIFFICULTY_SELECT:
			GameState.difficulty = difficulty_index
			_show_map_select()
		MenuState.MAP_SELECT:
			_start_game()
		MenuState.VIEW_SIZE:
			_show_main_menu()  # Save and return
		MenuState.SAVE_GAME:
			if save_input_active:
				# Save the game
				if save_input_text.length() > 0:
					_save_game_to_slot(save_slot_index, save_input_text)
			else:
				# Start entering name
				save_input_active = true
				# Pre-fill with existing name if overwriting, or leave empty
				if save_slot_index < save_slots.size() and save_slots[save_slot_index].has("name"):
					save_input_text = save_slots[save_slot_index].get("name", "")
				else:
					save_input_text = ""
				_show_save_game_screen()
		MenuState.LOAD_GAME:
			# Load game from selected slot if it has data
			if save_slot_index < save_slots.size() and save_slots[save_slot_index].has("name"):
				_load_game_from_slot(save_slot_index)


func _handle_main_menu_select() -> void:
	if not main_menu_options[main_menu_index].active:
		return
	
	# Check if first option is Resume Game
	var offset = 0
	if entered_from_game and main_menu_options[0].text == "Resume Game":
		offset = 1
		if main_menu_index == 0:
			# Resume Game - return to Wolf.tscn with saved state
			get_tree().change_scene_to_file("res://Wolf.tscn")
			return
	
	match main_menu_index - offset:
		0:  # New Game
			if available_games.size() > 0:
				GameState.selected_game = available_games[0].id
				# Clear saved state when starting new game
				GameState.clear_saved_state()
				_show_episode_select()
		1:  # Sound - placeholder
			pass
		2:  # Control - placeholder
			pass
		3:  # Load Game
			_show_load_game_screen()
		4:  # Save Game
			if entered_from_game:
				_show_save_game_screen()
		5:  # Change View
			_show_view_size_screen()
		6:  # Read This! - placeholder
			pass
		7:  # View Scores - placeholder
			pass
		8:  # Back to Demo
			get_tree().change_scene_to_file("res://TitleScreen.tscn")
		9:  # Quit
			get_tree().quit()


func _handle_cancel() -> void:
	match current_state:
		MenuState.MAIN:
			if entered_from_game:
				# Return to game if we came from it - state will be restored in Wolf.tscn
				get_tree().change_scene_to_file("res://Wolf.tscn")
			else:
				# Return to title screen if we came from there
				get_tree().change_scene_to_file("res://TitleScreen.tscn")
		MenuState.EPISODE_SELECT:
			_show_main_menu()
		MenuState.DIFFICULTY_SELECT:
			_show_episode_select()
		MenuState.MAP_SELECT:
			_show_difficulty_select()
		MenuState.VIEW_SIZE:
			GameState.set_view_size(pre_view_size)
			_show_main_menu()
		MenuState.SAVE_GAME:
			if save_input_active:
				# Cancel input - return to slot list
				save_input_active = false
				save_input_text = ""
				_refresh_save_screen()
			else:
				# Exit save screen - return to main menu
				_show_main_menu()
		MenuState.LOAD_GAME:
			_show_main_menu()



func _show_view_size_screen() -> void:
	current_state = MenuState.VIEW_SIZE
	pre_view_size = GameState.view_size
	
	_clear_menu_items()
	
	# Full screen background - RGB(0, 65, 65)
	var bg = ColorRect.new()
	bg.name = "ViewSizeBG"
	bg.color = COLOR_VIEW_BORDER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Viewport preview (black box)
	var preview = ColorRect.new()
	preview.name = "ViewportPreview"
	preview.color = Color.BLACK
	add_child(preview)
	
	# Instructions at bottom
	var text_y_start = 160 * scale_factor
	var instructions = [
		"Use arrows to size",
		"ENTER to accept",
		"ESC to cancel"
	]
	
	for i in range(instructions.size()):
		var label = Label.new()
		label.name = "ViewSizeInstr_%d" % i
		label.text = instructions[i]
		label.add_theme_font_size_override("font_size", int(11 * scale_factor))
		label.add_theme_color_override("font_color", COLOR_TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, text_y_start + i * 12 * scale_factor)
		label.size = Vector2(get_viewport().get_visible_rect().size.x, 15 * scale_factor)
		add_child(label)
	
	_update_view_size_preview()
	
	cursor_rect.visible = false


func _update_view_size_preview() -> void:
	var preview = get_node_or_null("ViewportPreview") as ColorRect
	if not preview:
		return
	
	# Get view dimensions in original coordinates
	var view_width = GameState.get_view_width()
	var view_height = GameState.get_view_height()
	
	# Game area is 160 pixels high
	var game_area_height = GameState.GAME_AREA_HEIGHT
	
	# Calculate centered position within the game area (top 160 pixels)
	var viewport_x = (ORIG_WIDTH - view_width) / 2.0
	var viewport_y = (game_area_height - view_height) / 2.0
	
	preview.position = Vector2(viewport_x * scale_factor, viewport_y * scale_factor)
	preview.size = Vector2(view_width * scale_factor, view_height * scale_factor)


func _show_save_game_screen() -> void:
	current_state = MenuState.SAVE_GAME
	
	# Load existing saves
	_load_save_slots()
	
	_refresh_save_screen()


func _refresh_save_screen() -> void:
	# Refresh the screen while maintaining input state
	_clear_menu_items()
	_draw_menu_background()
	
	# Draw header (C_SAVEGAMEPIC)
	if pics.has("C_SAVEGAMEPIC"):
		var header = TextureRect.new()
		header.name = "SaveGameHeader"
		header.texture = pics["C_SAVEGAMEPIC"]
		header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.stretch_mode = TextureRect.STRETCH_SCALE
		header.position = Vector2(84 * scale_factor, 0)
		header.size = Vector2(pics["C_SAVEGAMEPIC"].get_width() * scale_factor,
							   pics["C_SAVEGAMEPIC"].get_height() * scale_factor)
		add_child(header)
	
	# Draw save slots
	var slot_start_y = MENU_Y + 10
	for i in range(MAX_SAVE_SLOTS):
		# Draw border frame around slot
		var frame = ColorRect.new()
		frame.name = "SaveSlotFrame_%d" % i
		frame.color = COLOR_BORDER if i == save_slot_index else Color(0.3, 0.3, 0.3)
		frame.position = Vector2((MENU_X + 24) * scale_factor, (slot_start_y + i * 15 - 1) * scale_factor)
		frame.size = Vector2(140 * scale_factor, 12 * scale_factor)
		add_child(frame)
		
		# Inner background
		var inner_bg = ColorRect.new()
		inner_bg.name = "SaveSlotBG_%d" % i
		inner_bg.color = Color(0.1, 0.1, 0.1)
		inner_bg.position = Vector2((MENU_X + 25) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		inner_bg.size = Vector2(138 * scale_factor, 10 * scale_factor)
		add_child(inner_bg)
		
		var slot_label = Label.new()
		slot_label.name = "SaveSlot_%d" % i
		
		# If this is the slot being edited, show the input text
		if save_input_active and i == save_slot_index:
			if save_input_text.length() > 0:
				slot_label.text = save_input_text + "_"
			else:
				slot_label.text = "_"
		# Otherwise show saved name or "- empty -"
		elif i < save_slots.size() and save_slots[i].has("name"):
			slot_label.text = save_slots[i]["name"]
		else:
			slot_label.text = "- empty -"
		
		slot_label.add_theme_font_size_override("font_size", int(7 * scale_factor))
		
		if i == save_slot_index:
			slot_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			slot_label.add_theme_color_override("font_color", COLOR_TEXT)
		
		slot_label.position = Vector2((MENU_X + 28) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		add_child(slot_label)
	
	# Instructions at bottom
	if save_input_active:
		var instr = Label.new()
		instr.name = "SaveInstruction"
		instr.text = "ENTER to save, ESC to cancel"
		instr.add_theme_font_size_override("font_size", int(9 * scale_factor))
		instr.add_theme_color_override("font_color", COLOR_TEXT)
		instr.position = Vector2((MENU_X + 10) * scale_factor, (MENU_Y + 160) * scale_factor)
		add_child(instr)
	else:
		var instr = Label.new()
		instr.name = "SaveInstruction"
		instr.text = "ENTER to name save, ESC to exit"
		instr.add_theme_font_size_override("font_size", int(9 * scale_factor))
		instr.add_theme_color_override("font_color", COLOR_TEXT)
		instr.position = Vector2((MENU_X + 10) * scale_factor, (MENU_Y + 160) * scale_factor)
		add_child(instr)
	
	_update_cursor()


func _update_save_input_display() -> void:
	# Update only the input label without rebuilding entire screen
	var input_label = get_node_or_null("SaveInputLabel") as Label
	if input_label:
		input_label.text = "Name: " + save_input_text + "_"
		print("[Update] Updated input label to: ", input_label.text)
	else:
		print("[Update] SaveInputLabel not found! save_input_active = ", save_input_active)


func _load_save_slots() -> void:
	save_slots.clear()
	for i in range(MAX_SAVE_SLOTS):
		var save_path = "user://saves/save_%d.json" % i
		if FileAccess.file_exists(save_path):
			var file = FileAccess.open(save_path, FileAccess.READ)
			if file:
				var json_text = file.get_as_text()
				var save_data = JSON.parse_string(json_text)
				if save_data:
					save_slots.append(save_data)
				else:
					save_slots.append({})
				file.close()
			else:
				save_slots.append({})
		else:
			save_slots.append({})


func _save_game_to_slot(slot: int, save_name: String) -> void:
	# Create saves directory if it doesn't exist
	DirAccess.make_dir_recursive_absolute("user://saves/")
	
	# Prepare save data
	var save_data = {
		"name": save_name,
		"timestamp": Time.get_unix_time_from_system(),
		"game_state": GameState.saved_game_state
	}
	
	# Save to file
	var save_path = "user://saves/save_%d.json" % slot
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("Game saved to slot ", slot, " as '", save_name, "'")
		
		# Refresh save slots display
		_load_save_slots()
		save_input_active = false
		save_input_text = ""
		_show_save_game_screen()
	else:
		push_error("Failed to save game to slot ", slot)


func _show_load_game_screen() -> void:
	current_state = MenuState.LOAD_GAME
	
	# Load existing saves
	_load_save_slots()
	
	_refresh_load_screen()


func _refresh_load_screen() -> void:
	# Similar to save screen but for loading
	_clear_menu_items()
	_draw_menu_background()
	
	# Draw header (C_LOADGAMEPIC or reuse C_SAVEGAMEPIC)
	if pics.has("C_LOADGAMEPIC"):
		var header = TextureRect.new()
		header.name = "LoadGameHeader"
		header.texture = pics["C_LOADGAMEPIC"]
		header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.stretch_mode = TextureRect.STRETCH_SCALE
		header.position = Vector2(84 * scale_factor, 0)
		header.size = Vector2(pics["C_LOADGAMEPIC"].get_width() * scale_factor,
							   pics["C_LOADGAMEPIC"].get_height() * scale_factor)
		add_child(header)
	elif pics.has("C_SAVEGAMEPIC"):
		# Fallback to save game pic if load game pic not available
		var header = TextureRect.new()
		header.name = "LoadGameHeader"
		header.texture = pics["C_SAVEGAMEPIC"]
		header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.stretch_mode = TextureRect.STRETCH_SCALE
		header.position = Vector2(84 * scale_factor, 0)
		header.size = Vector2(pics["C_SAVEGAMEPIC"].get_width() * scale_factor,
							   pics["C_SAVEGAMEPIC"].get_height() * scale_factor)
		add_child(header)
	
	# Draw save slots
	var slot_start_y = MENU_Y + 10
	for i in range(MAX_SAVE_SLOTS):
		# Draw border frame around slot
		var frame = ColorRect.new()
		frame.name = "SaveSlotFrame_%d" % i
		frame.color = COLOR_BORDER if i == save_slot_index else Color(0.3, 0.3, 0.3)
		frame.position = Vector2((MENU_X + 24) * scale_factor, (slot_start_y + i * 15 - 1) * scale_factor)
		frame.size = Vector2(140 * scale_factor, 12 * scale_factor)
		add_child(frame)
		
		# Inner background
		var inner_bg = ColorRect.new()
		inner_bg.name = "SaveSlotBG_%d" % i
		inner_bg.color = Color(0.1, 0.1, 0.1)
		inner_bg.position = Vector2((MENU_X + 25) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		inner_bg.size = Vector2(138 * scale_factor, 10 * scale_factor)
		add_child(inner_bg)
		
		var slot_label = Label.new()
		slot_label.name = "SaveSlot_%d" % i
		
		# Show saved name or "- empty -"
		if i < save_slots.size() and save_slots[i].has("name"):
			slot_label.text = save_slots[i]["name"]
		else:
			slot_label.text = "- empty -"
		
		slot_label.add_theme_font_size_override("font_size", int(7 * scale_factor))
		
		if i == save_slot_index:
			slot_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			slot_label.add_theme_color_override("font_color", COLOR_TEXT)
		
		slot_label.position = Vector2((MENU_X + 28) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		add_child(slot_label)
	
	# Instructions at bottom
	var instr = Label.new()
	instr.name = "LoadInstruction"
	instr.text = "ENTER to load, ESC to exit"
	instr.add_theme_font_size_override("font_size", int(9 * scale_factor))
	instr.add_theme_color_override("font_color", COLOR_TEXT)
	instr.position = Vector2((MENU_X + 10) * scale_factor, (MENU_Y + 160) * scale_factor)
	add_child(instr)
	
	_update_cursor()


func _load_game_from_slot(slot: int) -> void:
	var save_path = "user://saves/save_%d.json" % slot
	if not FileAccess.file_exists(save_path):
		print("No save file in slot ", slot)
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file in slot ", slot)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var save_data = JSON.parse_string(json_text)
	if not save_data or not save_data.has("game_state"):
		push_error("Invalid save data in slot ", slot)
		return
	
	# Restore game state
	GameState.saved_game_state = save_data["game_state"]
	print("Loaded game from slot ", slot, ": ", save_data.get("name", "Unknown"))
	
	# Load the game scene which will restore state
	get_tree().change_scene_to_file("res://Wolf.tscn")


func _check_for_saved_games() -> bool:
	# Check if any save files exist
	for i in range(MAX_SAVE_SLOTS):
		var save_path = "user://saves/save_%d.json" % i
		if FileAccess.file_exists(save_path):
			print("[MainMenu] Found save file: ", save_path)
			return true
	print("[MainMenu] No save files found")
	return false


func _handle_up() -> void:
	match current_state:
		MenuState.MAIN:
			main_menu_index = (main_menu_index - 1 + main_menu_options.size()) % main_menu_options.size()
		MenuState.EPISODE_SELECT:
			episode_index = (episode_index - 1 + episode_options.size()) % episode_options.size()
		MenuState.DIFFICULTY_SELECT:
			difficulty_index = (difficulty_index - 1 + difficulty_options.size()) % difficulty_options.size()
		MenuState.MAP_SELECT:
			var episode_start = selected_episode * 10
			var maps_in_episode = mini(10, available_maps.size() - episode_start)
			if maps_in_episode > 0:
				map_index = (map_index - 1 + maps_in_episode) % maps_in_episode
		MenuState.VIEW_SIZE:
			GameState.increase_view_size()
			_update_view_size_preview()
		MenuState.SAVE_GAME:
			if not save_input_active:
				save_slot_index = (save_slot_index - 1 + MAX_SAVE_SLOTS) % MAX_SAVE_SLOTS
		MenuState.LOAD_GAME:
			save_slot_index = (save_slot_index - 1 + MAX_SAVE_SLOTS) % MAX_SAVE_SLOTS
	
	_update_cursor()
	_update_menu_highlights()


func _handle_down() -> void:
	match current_state:
		MenuState.MAIN:
			main_menu_index = (main_menu_index + 1) % main_menu_options.size()
		MenuState.EPISODE_SELECT:
			episode_index = (episode_index + 1) % episode_options.size()
		MenuState.DIFFICULTY_SELECT:
			difficulty_index = (difficulty_index + 1) % difficulty_options.size()
		MenuState.MAP_SELECT:
			var episode_start = selected_episode * 10
			var maps_in_episode = mini(10, available_maps.size() - episode_start)
			if maps_in_episode > 0:
				map_index = (map_index + 1) % maps_in_episode
		MenuState.VIEW_SIZE:
			GameState.decrease_view_size()
			_update_view_size_preview()
		MenuState.SAVE_GAME:
			if not save_input_active:
				save_slot_index = (save_slot_index + 1) % MAX_SAVE_SLOTS
		MenuState.LOAD_GAME:
			save_slot_index = (save_slot_index + 1) % MAX_SAVE_SLOTS
	
	_update_cursor()
	_update_menu_highlights()


func _handle_left() -> void:
	match current_state:
		MenuState.VIEW_SIZE:
			GameState.decrease_view_size()
			_update_view_size_preview()


func _handle_right() -> void:
	match current_state:
		MenuState.VIEW_SIZE:
			GameState.increase_view_size()
			_update_view_size_preview()


func _start_game() -> void:

	# Calculate actual map index
	var actual_map_index = selected_episode * 10 + map_index
	if actual_map_index < available_maps.size():
		GameState.selected_map_path = available_maps[actual_map_index].path
		GameState.current_map = actual_map_index
		print("Starting %s Episode %d, Level %d" % [GameState.selected_game, selected_episode + 1, map_index + 1])
	
	# Reload sounds for selected game
	SoundManager.reload_sounds()
	
	GameState.start_new_game()
	GameState.in_game = true
	get_tree().change_scene_to_file("res://Wolf.tscn")
