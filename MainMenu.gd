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
const COLOR_BACKGROUND = Color(138.0/255.0, 0.0, 0.0)  # Index 138 Red
const COLOR_BORDER = Color(110.0/255.0, 0.0, 0.0)      # Darker red for borders
const COLOR_STRIPE = Color(0.0, 0.0, 0.0)             # Black stripes
const COLOR_TEXT = Color(0.9, 0.9, 0.9)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.0)  # Yellow
const COLOR_DEACTIVE = Color(0.5, 0.5, 0.5)
const COLOR_VIEW_BORDER = Color(0.0, 65.0/255.0, 65.0/255.0)  # Authentic teal/cyan

# Menu states
enum MenuState { TITLE, MAIN, EPISODE_SELECT, DIFFICULTY_SELECT, GAME_SELECT, MAP_SELECT, VIEW_SIZE }
var current_state: MenuState = MenuState.TITLE

# Selection indices
var main_menu_index: int = 0
var episode_index: int = 0
var difficulty_index: int = 1  # Default to "Bring 'em on!"
var game_index: int = 0
var map_index: int = 0

# Available games and maps
var available_games: Array[Dictionary] = []
var available_maps: Array[Dictionary] = []
var selected_episode: int = 0

# Scale factor for 320x200 -> current resolution
var scale_factor: float = 1.0

# Store view size before entering Change View screen
var pre_view_size: int = 15

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
	{"text": "Load Game", "active": true},
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
	_show_title()
	
	# Play title music
	MusicManager.play_title_music()


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


func _show_title() -> void:
	current_state = MenuState.TITLE
	
	# Clear children except background and cursor
	_clear_menu_items()
	
	# Show title pic
	if pics.has("TITLEPIC"):
		background.texture = pics["TITLEPIC"]
		background.visible = true
	
	cursor_rect.visible = false
	
	# Add "Press any key" text
	var press_label = Label.new()
	press_label.name = "PressLabel"
	press_label.text = "PRESS A KEY"
	press_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	press_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.position = Vector2(0, 180 * scale_factor)
	press_label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(press_label)


func _show_main_menu() -> void:
	current_state = MenuState.MAIN
	main_menu_index = 0
	
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
	window.color = Color(89/255.0, 0.0, 0.0, 0.95)  # Very dark red/black for window background
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


func _process(delta: float) -> void:
	# Animate cursor
	cursor_timer += delta
	if cursor_timer > 0.15:
		cursor_timer = 0.0
		cursor_frame = 1 - cursor_frame
		if cursor_rect.visible:
			cursor_rect.texture = pics.get("C_CURSOR1PIC") if cursor_frame == 0 else pics.get("C_CURSOR2PIC")


func _input(event: InputEvent) -> void:
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
		MenuState.TITLE:
			_show_main_menu()
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


func _handle_main_menu_select() -> void:
	if not main_menu_options[main_menu_index].active:
		return
	
	match main_menu_index:
		0:  # New Game
			if available_games.size() > 0:
				GameState.selected_game = available_games[0].id
				_show_episode_select()
		1:  # Sound - placeholder
			pass
		2:  # Control - placeholder
			pass
		3:  # Load Game - placeholder
			pass
		4:  # Save Game - disabled
			pass
		5:  # Change View
			_show_view_size_screen()
		6:  # Read This! - placeholder
			pass
		7:  # View Scores - placeholder
			pass
		8:  # Back to Demo
			_show_title()
		9:  # Quit
			get_tree().quit()


func _handle_cancel() -> void:
	match current_state:
		MenuState.MAIN:
			_show_title()
		MenuState.EPISODE_SELECT:
			_show_main_menu()
		MenuState.DIFFICULTY_SELECT:
			_show_episode_select()
		MenuState.MAP_SELECT:
			_show_difficulty_select()
		MenuState.VIEW_SIZE:
			GameState.set_view_size(pre_view_size)
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
	
	_update_cursor()
	_update_menu_highlights()


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
	get_tree().change_scene_to_file("res://Wolf.tscn")
