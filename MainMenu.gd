extends Control

const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200
const MENU_X = 76
const MENU_Y = 55
const MENU_W = 178
const MENU_H = 136

const COLOR_BACKGROUND = Color(138.0/255.0, 0.0, 0.0)
const COLOR_BORDER = Color(110.0/255.0, 0.0, 0.0)
const COLOR_STRIPE = Color(0.0, 0.0, 0.0)
const COLOR_TEXT = Color(141.0/255.0, 141.0/255.0, 141.0/255.0)
const COLOR_HIGHLIGHT = Color(194.0/255.0, 194.0/255.0, 194.0/255.0)
const COLOR_DEACTIVE = Color(0.5, 0.5, 0.5)
const COLOR_VIEW_BORDER = Color(0.0, 65.0/255.0, 65.0/255.0)
const COLOR_RED = Color(113.0/255.0, 0.0/255.0, 0.0/255.0)
enum MenuState { MAIN, EPISODE_SELECT, DIFFICULTY_SELECT, GAME_SELECT, MAP_SELECT, VIEW_SIZE, SAVE_GAME, LOAD_GAME, SOUND, CONTROL, READ_THIS }
var current_state: MenuState = MenuState.MAIN
var main_menu_index: int = 0
var episode_index: int = 0
var difficulty_index: int = 1
var game_index: int = 0
var map_index: int = 0
var save_slot_index: int = 0
var sound_menu_index: int = 0
var control_menu_index: int = 0
var read_this_page: int = 0

const MAX_SAVE_SLOTS = 8
var save_slots: Array[Dictionary] = []
var save_input_text: String = ""
var save_input_active: bool = false
var available_games: Array[Dictionary] = []
var available_maps: Array[Dictionary] = []
var selected_episode: int = 0
var scale_factor: float = 1.0
var center_offset_x: float = 0.0
var center_offset_y: float = 0.0
var pre_view_size: int = 15
var entered_from_game: bool = false
var pics: Dictionary = {}
var background: TextureRect
var menu_window: ColorRect
var cursor_rect: TextureRect
var cursor_frame: int = 0
var cursor_timer: float = 0.0

var main_menu_options = [
	{"text": "New Game", "active": true},
	{"text": "Sound", "active": true},
	{"text": "Control", "active": true},
	{"text": "Load Game", "active": false},
	{"text": "Save Game", "active": false},
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
	if Engine.is_editor_hint():
		return
		
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	if not FontManager.font1 or not FontManager.font2:
		await FontManager.fonts_loaded
	var TestRunner = preload("res://tests/test_extraction.gd")
	TestRunner.run_all()
	_calculate_scale()
	_load_pics()
	_detect_games()
	_create_ui()
	if GameState.menu_from_game:
		entered_from_game = true
		if main_menu_options[0].text != "Resume Game":
			main_menu_options.insert(0, {"text": "Resume Game", "active": true})
			main_menu_options[5].active = true  # Save Game
			GameState.menu_from_game = false  # Reset flag
	_show_main_menu()

func _calculate_scale() -> void:
	var window_size = get_viewport().get_visible_rect().size
	# Scale to fit 320x200 into window, maintaining aspect ratio
	var scale_x = window_size.x / ORIG_WIDTH
	var scale_y = window_size.y / ORIG_HEIGHT
	scale_factor = min(scale_x, scale_y)
	var scaled_width = ORIG_WIDTH * scale_factor
	var scaled_height = ORIG_HEIGHT * scale_factor
	center_offset_x = (window_size.x - scaled_width) / 2.0
	center_offset_y = (window_size.y - scaled_height) / 2.0

func _get_pics_path() -> String:
	# Try runtime extracted first, fall back to pre-extracted
	var game_id = GameState.selected_game if GameState.selected_game != "" else "wolf3d"
	var user_path = "user://assets/%s/pics/" % game_id
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(user_path)):
		return user_path
	return "res://assets/vga/pics/"

func _load_pics() -> void:
	var path = _get_pics_path()
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
	var fallback_path = "res://assets/vga/pics/" + path.get_file()
	return load(fallback_path)

func _apply_font(label: Label, font_id: int) -> void:
	var font = FontManager.font1 if font_id == 1 else FontManager.font2
	if font:
		label.add_theme_font_override("font", font)
		var native_size = 10 if font_id == 1 else 13
		label.add_theme_font_size_override("font_size", native_size)
		var final_scale = scale_factor
		label.scale = Vector2(final_scale, final_scale)
	else:
		print("[MainMenu] WARNING: Font %d is null!" % font_id)

func _detect_games() -> void:
	available_games.clear()
	
	# Check for Wolf3D
	if DirAccess.open("user://assets/wolf3d/maps/json/") != null:
		available_games.append({
			"id": "wolf3d",
			"name": "WOLFENSTEIN 3D",
			"maps_path": "user://assets/wolf3d/maps/json/"
		})
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
	if available_games.size() >= 1:
		GameState.selected_game = available_games[0].id

func _create_ui() -> void:
	background = TextureRect.new()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

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
		header.position = Vector2(center_offset_x + 84 * scale_factor, center_offset_y + 0)
		header.size = Vector2(pics["C_OPTIONSPIC"].get_width() * scale_factor, 
								pics["C_OPTIONSPIC"].get_height() * scale_factor)
		add_child(header)
	
	# Draw menu items
	var menu_start_y = MENU_Y - 1
	for i in range(main_menu_options.size()):
		var item = main_menu_options[i]
		var label = Label.new()
		label.name = "MenuItem_%d" % i
		label.text = item.text
		_apply_font(label, 2)
		
		if not item.active:
			label.add_theme_color_override("font_color", COLOR_RED)
		elif i == main_menu_index:
			label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			label.add_theme_color_override("font_color", COLOR_TEXT)
		
		label.position = Vector2(center_offset_x + (MENU_X + 24) * scale_factor, center_offset_y + (menu_start_y + i * 12) * scale_factor)
		label.custom_minimum_size = Vector2(120 * scale_factor, 12 * scale_factor)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_item_gui_input.bind(i, "main"))
		add_child(label)
	
	if pics.has("C_MOUSELBACKPIC"):
		var footer = TextureRect.new()
		footer.name = "MenuFooter"
		footer.texture = pics["C_MOUSELBACKPIC"]
		footer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		footer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var footer_width = 100.0
		footer.position = Vector2(
		center_offset_x + (160 - (footer_width / 2.0)) * scale_factor,
		center_offset_y + 190 * scale_factor
	)
		footer.size = Vector2(footer_width * scale_factor, 10 * scale_factor)
		add_child(footer)
		cursor_rect.visible = true
		_update_cursor()


func _show_episode_select() -> void:
	current_state = MenuState.EPISODE_SELECT
	episode_index = 0
	
	_clear_menu_items()
	
	# Custom background for episode screen (no black stripes)
	var bg = ColorRect.new()
	bg.name = "EpisodeBG"
	bg.color = COLOR_BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Inner darker panel with 3D beveled frame (original Wolf3D style)
	var panel_x = 20
	var panel_y = 35
	var panel_w = 280
	var panel_h = 145
	
	# First draw the highlight (bright) behind the panel
	var highlight_right = ColorRect.new()
	highlight_right.name = "PanelHighlightRight"
	highlight_right.color = Color(170.0/255.0, 0.0, 0.0) 
	highlight_right.position = Vector2(center_offset_x + (panel_x + panel_w - 2) * scale_factor, center_offset_y + panel_y * scale_factor)
	highlight_right.size = Vector2(2 * scale_factor, panel_h * scale_factor)
	add_child(highlight_right)
	
	var highlight_bottom = ColorRect.new()
	highlight_bottom.name = "PanelHighlightBottom"
	highlight_bottom.color = Color(170.0/255.0, 0.0, 0.0)
	highlight_bottom.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + (panel_y + panel_h - 2) * scale_factor)
	highlight_bottom.size = Vector2(panel_w * scale_factor, 2 * scale_factor)
	add_child(highlight_bottom)
	
	# Inner panel (darker red)
	var panel = ColorRect.new()
	panel.name = "EpisodePanel"
	panel.color = Color(89.0/255.0, 0.0, 0.0) 
	panel.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + panel_y * scale_factor)
	panel.size = Vector2(panel_w * scale_factor, panel_h * scale_factor)
	add_child(panel)
	
	# Dark shadow on top and left edges
	var shadow_top = ColorRect.new()
	shadow_top.name = "PanelShadowTop"
	shadow_top.color = Color(60.0/255.0, 0.0, 0.0) 
	shadow_top.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + panel_y * scale_factor)
	shadow_top.size = Vector2(panel_w * scale_factor, 2 * scale_factor)
	add_child(shadow_top)
	
	var shadow_left = ColorRect.new()
	shadow_left.name = "PanelShadowLeft"
	shadow_left.color = Color(60.0/255.0, 0.0, 0.0)
	shadow_left.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + panel_y * scale_factor)
	shadow_left.size = Vector2(2 * scale_factor, panel_h * scale_factor)
	add_child(shadow_left)
	
	# Episode selection header
	var header = Label.new()
	header.name = "EpisodeHeader"
	header.text = "Which episode to play?"
	if FontManager.font2:
		header.add_theme_font_override("font", FontManager.font2)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) 
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var header_scale = scale_factor * 1.2
	header.scale = Vector2(header_scale, header_scale)
	header.position = Vector2(center_offset_x, center_offset_y + 14 * scale_factor)
	header.size = Vector2((320 * scale_factor) / header_scale, 20 * scale_factor)
	add_child(header)
	
	var ep_start_y = 38
	var ep_spacing = 22
	
	for i in range(episode_options.size()):
		var ep = episode_options[i]
		var lines = ep.text.split("\n")
		var episode_title = lines[0] if lines.size() > 0 else "Episode"
		var episode_subtitle = lines[1] if lines.size() > 1 else ""
		var ep_y = ep_start_y + i * ep_spacing
		
		if pics.has(ep.pic):
			var pic_rect = TextureRect.new()
			pic_rect.name = "EpisodePic_%d" % i
			pic_rect.texture = pics[ep.pic]
			pic_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic_rect.stretch_mode = TextureRect.STRETCH_SCALE
			pic_rect.position = Vector2(center_offset_x + 48 * scale_factor, center_offset_y + ep_y * scale_factor)
			pic_rect.size = Vector2(pics[ep.pic].get_width() * scale_factor,
										pics[ep.pic].get_height() * scale_factor)
			add_child(pic_rect)
		
		var text_color = COLOR_HIGHLIGHT if i == episode_index else COLOR_TEXT
		
		var title_label = Label.new()
		var reduced_scale = scale_factor * 0.92
		title_label.name = "EpisodeTitle_%d" % i
		title_label.text = episode_title
		_apply_font(title_label, 2)
		title_label.scale = Vector2(reduced_scale, reduced_scale)
		title_label.add_theme_color_override("font_color", text_color)
		title_label.position = Vector2(center_offset_x + 100 * scale_factor, center_offset_y + ep_y * scale_factor)
		title_label.custom_minimum_size = Vector2(180 * scale_factor, 12 * scale_factor)
		title_label.mouse_filter = Control.MOUSE_FILTER_STOP
		title_label.gui_input.connect(_on_item_gui_input.bind(i, "episode"))
		add_child(title_label)
		
		if episode_subtitle != "":
			var subtitle_label = Label.new()
			subtitle_label.name = "EpisodeSubtitle_%d" % i
			subtitle_label.text = episode_subtitle
			_apply_font(subtitle_label, 2)
			subtitle_label.scale = Vector2(reduced_scale, reduced_scale)
			subtitle_label.add_theme_color_override("font_color", text_color)
			subtitle_label.position = Vector2(center_offset_x + 100 * scale_factor, center_offset_y + (ep_y + 10) * scale_factor)
			add_child(subtitle_label)
	
	if pics.has("C_MOUSELBACKPIC"):
		var footer = TextureRect.new()
		footer.name = "EpisodeFooter"
		footer.texture = pics["C_MOUSELBACKPIC"]
		footer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		footer.stretch_mode = TextureRect.STRETCH_SCALE
		footer.position = Vector2(center_offset_x + 112 * scale_factor, center_offset_y + 184 * scale_factor)
		footer.size = Vector2(pics["C_MOUSELBACKPIC"].get_width() * scale_factor,
								pics["C_MOUSELBACKPIC"].get_height() * scale_factor)
		add_child(footer)
	
	_update_cursor()

func _show_difficulty_select() -> void:
	current_state = MenuState.DIFFICULTY_SELECT
	difficulty_index = 2  # Default to "Bring 'em on!"
	_clear_menu_items()
	
	# Solid background
	var bg = ColorRect.new()
	bg.name = "DifficultyBG"
	bg.color = COLOR_BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Sunken panel for difficulty selection
	var panel_x = 40
	var panel_y = 65
	var panel_w = 240
	var panel_h = 110
	var text_base_x = 100  # X offset for difficulty text labels
	
	# Shadow/Highlight for sunken look
	var hr = ColorRect.new()
	hr.color = Color(170.0/255.0, 0.0, 0.0) # Highlight right
	hr.position = Vector2(center_offset_x + (panel_x + panel_w - 2) * scale_factor, center_offset_y + panel_y * scale_factor)
	hr.size = Vector2(2 * scale_factor, panel_h * scale_factor)
	add_child(hr)
	
	var hb = ColorRect.new()
	hb.color = Color(170.0/255.0, 0.0, 0.0) # Highlight bottom
	hb.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + (panel_y + panel_h - 2) * scale_factor)
	hb.size = Vector2(panel_w * scale_factor, 2 * scale_factor)
	add_child(hb)
	
	var panel = ColorRect.new()
	panel.color = Color(89.0/255.0, 0.0, 0.0) # Inner panel
	panel.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + panel_y * scale_factor)
	panel.size = Vector2(panel_w * scale_factor, panel_h * scale_factor)
	add_child(panel)
	
	var st = ColorRect.new()
	st.color = Color(60.0/255.0, 0.0, 0.0) # Shadow top
	st.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + panel_y * scale_factor)
	st.size = Vector2(panel_w * scale_factor, 2 * scale_factor)
	add_child(st)
	
	var sl = ColorRect.new()
	sl.color = Color(60.0/255.0, 0.0, 0.0) # Shadow left
	sl.position = Vector2(center_offset_x + panel_x * scale_factor, center_offset_y + panel_y * scale_factor)
	sl.size = Vector2(2 * scale_factor, panel_h * scale_factor)
	add_child(sl)

	# Header
	var header = Label.new()
	header.name = "DifficultyHeader"
	header.text = "How tough are you?"
	_apply_font(header, 2)
	header.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	var header_scale = scale_factor * 1.2
	header.scale = Vector2(header_scale, header_scale)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(center_offset_x, center_offset_y + 35 * scale_factor)
	header.size = Vector2((320 * scale_factor) / header_scale, 20 * scale_factor)
	add_child(header)
	
	var face_rect = TextureRect.new()
	face_rect.name = "DynamicDifficultyFace"
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(face_rect)
	
	var item_start_y = 80
	var item_spacing = 20
	
	for i in range(difficulty_options.size()):
		var diff = difficulty_options[i]
		var label = Label.new()
		label.name = "DiffLabel_%d" % i
		label.text = diff.text
		_apply_font(label, 1)
		label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == difficulty_index else COLOR_TEXT)
		label.position = Vector2(center_offset_x + text_base_x * scale_factor, center_offset_y + (80 + i * 26) * scale_factor)
		add_child(label)
	
	if pics.has("C_MOUSELBACKPIC"):
		var footer = TextureRect.new()
		footer.texture = pics["C_MOUSELBACKPIC"]
		footer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		footer.stretch_mode = TextureRect.STRETCH_SCALE
		footer.position = Vector2(center_offset_x + 112 * scale_factor, center_offset_y + 184 * scale_factor)
		footer.size = Vector2(pics["C_MOUSELBACKPIC"].get_width() * scale_factor, pics["C_MOUSELBACKPIC"].get_height() * scale_factor)
		add_child(footer)
	
	_update_difficulty_face() 
	_update_cursor()

func _update_difficulty_face() -> void:
	var face_rect = get_node_or_null("DynamicDifficultyFace") as TextureRect
	if face_rect and difficulty_index < difficulty_options.size():
		var pic_key = difficulty_options[difficulty_index].pic
		if pics.has(pic_key):
			var tex = pics[pic_key]
			face_rect.texture = tex
			var scaled_w = tex.get_width() * scale_factor
			var scaled_h = tex.get_height() * scale_factor
			face_rect.size = Vector2(scaled_w, scaled_h)
			face_rect.position = Vector2(center_offset_x + 235 * scale_factor, center_offset_y + 105 * scale_factor)

func _show_map_select() -> void:
	current_state = MenuState.MAP_SELECT
	map_index = 0
	var start_map = selected_episode * 10
	var maps_path = "user://assets/%s/maps/json/" % GameState.selected_game
	_scan_maps(maps_path)
	_clear_menu_items()
	_draw_menu_background()
	
	var header = Label.new()
	header.name = "MapHeader"
	header.text = "Select Level - Episode %d" % (selected_episode + 1)
	_apply_font(header, 2)
	header.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 30 * scale_factor)
	header.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(header)
	
	var episode_maps = []
	for i in range(start_map, mini(start_map + 10, available_maps.size())):
		episode_maps.append(available_maps[i])
	
	for i in range(episode_maps.size()):
		var label = Label.new()
		label.name = "MapLabel_%d" % i
		label.text = episode_maps[i].name
		_apply_font(label, 1)
		label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == map_index else COLOR_TEXT)
		label.position = Vector2(130 * scale_factor, (50 + i * 14) * scale_factor)
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
	background.texture = null
	background.visible = false
	
	var bg = ColorRect.new()
	bg.name = "MenuBG"
	bg.color = COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var stripe = ColorRect.new()
	stripe.name = "MainStripe"
	stripe.color = COLOR_STRIPE
	stripe.position = Vector2(center_offset_x, center_offset_y + 10 * scale_factor)
	stripe.size = Vector2(320 * scale_factor, 24 * scale_factor)
	add_child(stripe)
	
	var window = ColorRect.new()
	window.name = "MenuWindow"
	window.color = Color(89/255.0, 0.0, 0.0, 0.95)
	window.position = Vector2(center_offset_x + (MENU_X - 8) * scale_factor, center_offset_y + (MENU_Y - 3) * scale_factor)
	window.size = Vector2(MENU_W * scale_factor, MENU_H * scale_factor)
	add_child(window)
	
	var border = ColorRect.new()
	border.name = "WindowBorder"
	border.color = COLOR_BORDER
	border.position = Vector2(center_offset_x + (MENU_X - 10) * scale_factor, center_offset_y + (MENU_Y - 5) * scale_factor)
	border.size = Vector2((MENU_W + 4) * scale_factor, (MENU_H + 4) * scale_factor)
	add_child(border)
	
	move_child(border, get_child_count() - 2)

func _clear_menu_items() -> void:
	for child in get_children():
		if child != background and child != cursor_rect:
			child.queue_free()

func _update_cursor() -> void:
	if current_state == MenuState.VIEW_SIZE:
		cursor_rect.visible = false
		return
	
	cursor_rect.texture = pics.get("C_CURSOR1PIC") if cursor_frame == 0 else pics.get("C_CURSOR2PIC")
	cursor_rect.visible = true
	
	if cursor_rect.texture:
		cursor_rect.size = Vector2(cursor_rect.texture.get_width() * scale_factor,
									cursor_rect.texture.get_height() * scale_factor)
	
	var target_y: float = 0
	var target_x: float = 0
	
	match current_state:
		MenuState.MAIN:
			target_x = center_offset_x + (MENU_X) * scale_factor
			target_y = center_offset_y + (MENU_Y + main_menu_index * 12) * scale_factor
		MenuState.EPISODE_SELECT:
			target_x = center_offset_x + 22 * scale_factor 
			target_y = center_offset_y + (42 + episode_index * 24) * scale_factor 
		MenuState.DIFFICULTY_SELECT:
			target_x = center_offset_x + 65 * scale_factor
			target_y = center_offset_y + (80 + difficulty_index * 26) * scale_factor
		MenuState.MAP_SELECT:
			target_x = center_offset_x + 68 * scale_factor
			target_y = center_offset_y + (52 + map_index * 14) * scale_factor
		MenuState.SAVE_GAME:
			if not save_input_active:
				target_x = center_offset_x + (MENU_X) * scale_factor
				target_y = center_offset_y + (MENU_Y + 10 + save_slot_index * 15) * scale_factor
			else:
				cursor_rect.visible = false
				return
		MenuState.LOAD_GAME:
			target_x = center_offset_x + (MENU_X) * scale_factor
			target_y = center_offset_y + (MENU_Y + 10 + save_slot_index * 15) * scale_factor
			
	cursor_rect.position = Vector2(target_x, target_y)
	move_child(cursor_rect, get_child_count() - 1)

func _update_menu_highlights() -> void:
	match current_state:
		MenuState.MAIN:
			for i in range(main_menu_options.size()):
				var label = get_node_or_null("MenuItem_%d" % i) as Label
				if label:
					if not main_menu_options[i].active:
						label.add_theme_color_override("font_color", COLOR_RED)
					elif i == main_menu_index:
						label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
					else:
						label.add_theme_color_override("font_color", COLOR_TEXT)
		MenuState.EPISODE_SELECT:
			for i in range(episode_options.size()):
				var color = COLOR_HIGHLIGHT if i == episode_index else COLOR_TEXT
				var title_label = get_node_or_null("EpisodeTitle_%d" % i) as Label
				var subtitle_label = get_node_or_null("EpisodeSubtitle_%d" % i) as Label
				if title_label: title_label.add_theme_color_override("font_color", color)
				if subtitle_label: subtitle_label.add_theme_color_override("font_color", color)
		MenuState.DIFFICULTY_SELECT:
			_update_difficulty_face()
			for i in range(difficulty_options.size()):
				var label = get_node_or_null("DiffLabel_%d" % i) as Label
				if label: label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == difficulty_index else COLOR_TEXT)
		MenuState.MAP_SELECT:
			var visible_count = get_children().filter(func(c): return c.name.begins_with("MapLabel_")).size()
			for i in range(visible_count):
				var label = get_node_or_null("MapLabel_%d" % i) as Label
				if label: label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == map_index else COLOR_TEXT)
		MenuState.SAVE_GAME, MenuState.LOAD_GAME:
			for i in range(MAX_SAVE_SLOTS):
				var label = get_node_or_null("SaveSlot_%d" % i) as Label
				if label: label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == save_slot_index else COLOR_TEXT)

func _process(delta: float) -> void:
	cursor_timer += delta
	if cursor_timer > 0.15:
		cursor_timer = 0.0
		cursor_frame = 1 - cursor_frame
		if cursor_rect.visible:
			cursor_rect.texture = pics.get("C_CURSOR1PIC") if cursor_frame == 0 else pics.get("C_CURSOR2PIC")

func _input(event: InputEvent) -> void:
	if current_state == MenuState.SAVE_GAME and save_input_active:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_BACKSPACE:
				if save_input_text.length() > 0:
					save_input_text = save_input_text.substr(0, save_input_text.length() - 1)
					_refresh_save_screen()
				get_viewport().set_input_as_handled()
				return
			elif event.unicode >= 32 and event.unicode < 127:
				if save_input_text.length() < 24:
					save_input_text += char(event.unicode)
					_refresh_save_screen()
				get_viewport().set_input_as_handled()
				return
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
	elif event is InputEventScreenTouch and event.pressed:
		# Also check for touches in screens that only have "Press any key"
		if current_state == MenuState.MAIN and not cursor_rect.visible:
			_handle_accept()

func _on_item_gui_input(event: InputEvent, index: int, type: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		match type:
			"main":
				main_menu_index = index
				_update_menu_highlights()
				_update_cursor()
				_handle_accept()
			"episode":
				episode_index = index
				_update_menu_highlights()
				_update_cursor()
				_handle_accept()
			"difficulty":
				difficulty_index = index
				_update_menu_highlights()
				_update_cursor()
				_handle_accept()
			"map":
				map_index = index
				_update_menu_highlights()
				_update_cursor()
				_handle_accept()
			"save":
				save_slot_index = index
				_update_menu_highlights()
				_update_cursor()
				# If not already active, trigger click to start name input
				if not save_input_active:
					_handle_accept()
			"load":
				save_slot_index = index
				_update_menu_highlights()
				_update_cursor()
				_handle_accept()

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
			_show_main_menu()
		MenuState.SAVE_GAME:
			if save_input_active:
				if save_input_text.length() > 0:
					_save_game_to_slot(save_slot_index, save_input_text)
			else:
				save_input_active = true
				if save_slot_index < save_slots.size() and save_slots[save_slot_index].has("name"):
					save_input_text = save_slots[save_slot_index].get("name", "")
				else:
					save_input_text = ""
				_show_save_game_screen()
		MenuState.LOAD_GAME:
			if save_slot_index < save_slots.size() and save_slots[save_slot_index].has("name"):
				_load_game_from_slot(save_slot_index)
		MenuState.SOUND:
			# Toggle sound settings
			if sound_menu_index == 0:
				GameState.sound_enabled = not GameState.sound_enabled
			elif sound_menu_index == 1:
				GameState.music_enabled = not GameState.music_enabled
				if not GameState.music_enabled:
					MusicManager.stop()
				else:
					MusicManager.play_track("WONDERIN")
			_show_sound_menu()  # Refresh display
		MenuState.CONTROL:
			# Toggle control settings
			if control_menu_index == 1:
				GameState.always_run = not GameState.always_run
			elif control_menu_index == 2:
				GameState.mouse_look = not GameState.mouse_look
			_show_control_menu()  # Refresh display
		MenuState.READ_THIS:
			# Any key/enter goes to next page or exits
			read_this_page += 1
			if read_this_page >= 2:  # Total pages
				_show_main_menu()
			else:
				_show_read_this()  # Show next page

func _handle_main_menu_select() -> void:
	if not main_menu_options[main_menu_index].active:
		return
	var offset = 0
	if entered_from_game and main_menu_options[0].text == "Resume Game":
		offset = 1
		if main_menu_index == 0:
			get_tree().change_scene_to_file("res://Wolf.tscn")
			return
	match main_menu_index - offset:
		0: 
			if available_games.size() > 0:
				GameState.selected_game = available_games[0].id
				GameState.clear_saved_state()
				_show_episode_select()
		1:  # Sound
			_show_sound_menu()
		2:  # Control
			_show_control_menu()
		3:  # Load Game
			_show_load_game_screen()
		4:  # Save Game
			if entered_from_game:
				_show_save_game_screen()
		5:  # Change View
			_show_view_size_screen()
		6:  # Read This!
			_show_read_this()
		7:  # View Scores
			_show_high_scores()
		8:  # Back to Demo - return to title loop
			GameState.skip_to_title_loop = true
			MusicManager.play_track("NAZI_NOR")
			get_tree().change_scene_to_file("res://TitleScreen.tscn")
		9:  # Quit
			get_tree().quit()

func _handle_cancel() -> void:
	match current_state:
		MenuState.MAIN:
			if entered_from_game: get_tree().change_scene_to_file("res://Wolf.tscn")
			else: get_tree().change_scene_to_file("res://TitleScreen.tscn")
		MenuState.EPISODE_SELECT: _show_main_menu()
		MenuState.DIFFICULTY_SELECT: _show_episode_select()
		MenuState.MAP_SELECT: _show_difficulty_select()
		MenuState.VIEW_SIZE:
			GameState.set_view_size(pre_view_size)
			_show_main_menu()
		MenuState.SAVE_GAME:
			if save_input_active:
				save_input_active = false
				save_input_text = ""
				_refresh_save_screen()
			else:
				# Exit save screen - return to main menu
				_show_main_menu()
		MenuState.LOAD_GAME:
			_show_main_menu()
		MenuState.SOUND:
			_show_main_menu()
		MenuState.CONTROL:
			_show_main_menu()
		MenuState.READ_THIS:
			_show_main_menu()

func _show_high_scores() -> void:
	_clear_menu_items()
	var bg = ColorRect.new()
	bg.color = COLOR_VIEW_BORDER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if pics.has("HIGHSCORESPIC"):
		var board = TextureRect.new()
		board.texture = pics["HIGHSCORESPIC"]
		board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		board.stretch_mode = TextureRect.STRETCH_SCALE
		var board_w = pics["HIGHSCORESPIC"].get_width() * scale_factor
		var board_h = pics["HIGHSCORESPIC"].get_height() * scale_factor
		var window_size = get_viewport().get_visible_rect().size
		board.position = Vector2((window_size.x - board_w) / 2, (window_size.y - board_h) / 2)
		board.size = Vector2(board_w, board_h)
		add_child(board)
	var label = Label.new()
	label.text = "PRESS ANY KEY"
	_apply_font(label, 1)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 180 * scale_factor)
	label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(label)
	current_state = MenuState.MAIN
	cursor_rect.visible = false


func _show_sound_menu() -> void:
	current_state = MenuState.SOUND
	sound_menu_index = 0
	
	_clear_menu_items()
	_draw_menu_background()
	
	# Header
	var header = Label.new()
	header.name = "SoundHeader"
	header.text = "Sound Options"
	_apply_font(header, 2)
	header.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, center_offset_y + 30 * scale_factor)
	header.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(header)
	
	# Sound FX toggle
	var sfx_label = Label.new()
	sfx_label.name = "SFXLabel"
	sfx_label.text = "Sound FX:  %s" % ("ON" if GameState.sound_enabled else "OFF")
	_apply_font(sfx_label, 2)
	sfx_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if sound_menu_index == 0 else COLOR_TEXT)
	sfx_label.position = Vector2(center_offset_x + 80 * scale_factor, center_offset_y + 70 * scale_factor)
	sfx_label.custom_minimum_size = Vector2(160 * scale_factor, 14 * scale_factor)
	add_child(sfx_label)
	
	# Music toggle
	var music_label = Label.new()
	music_label.name = "MusicLabel"
	music_label.text = "Music:     %s" % ("ON" if GameState.music_enabled else "OFF")
	_apply_font(music_label, 2)
	music_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if sound_menu_index == 1 else COLOR_TEXT)
	music_label.position = Vector2(center_offset_x + 80 * scale_factor, center_offset_y + 90 * scale_factor)
	music_label.custom_minimum_size = Vector2(160 * scale_factor, 14 * scale_factor)
	add_child(music_label)
	
	# Instructions
	var instr_label = Label.new()
	instr_label.text = "Use UP/DOWN to select, ENTER to toggle, ESC to exit"
	_apply_font(instr_label, 1)
	instr_label.add_theme_color_override("font_color", COLOR_DEACTIVE)
	instr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr_label.position = Vector2(0, center_offset_y + 150 * scale_factor)
	instr_label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(instr_label)
	
	_update_cursor()


func _show_control_menu() -> void:
	current_state = MenuState.CONTROL
	control_menu_index = 0
	
	_clear_menu_items()
	_draw_menu_background()
	
	# Header
	var header = Label.new()
	header.name = "ControlHeader"
	header.text = "Control Options"
	_apply_font(header, 2)
	header.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, center_offset_y + 30 * scale_factor)
	header.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(header)
	
	# Mouse Sensitivity
	var sens_label = Label.new()
	sens_label.name = "SensLabel"
	sens_label.text = "Mouse Sensitivity: %d" % GameState.mouse_sensitivity
	_apply_font(sens_label, 2)
	sens_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if control_menu_index == 0 else COLOR_TEXT)
	sens_label.position = Vector2(center_offset_x + 60 * scale_factor, center_offset_y + 70 * scale_factor)
	sens_label.custom_minimum_size = Vector2(200 * scale_factor, 14 * scale_factor)
	add_child(sens_label)
	
	# Always Run
	var run_label = Label.new()
	run_label.name = "RunLabel"
	run_label.text = "Always Run:        %s" % ("ON" if GameState.always_run else "OFF")
	_apply_font(run_label, 2)
	run_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if control_menu_index == 1 else COLOR_TEXT)
	run_label.position = Vector2(center_offset_x + 60 * scale_factor, center_offset_y + 90 * scale_factor)
	run_label.custom_minimum_size = Vector2(200 * scale_factor, 14 * scale_factor)
	add_child(run_label)
	
	# Mouse Look
	var mouse_label = Label.new()
	mouse_label.name = "MouseLabel"
	mouse_label.text = "Mouse Look:        %s" % ("ON" if GameState.mouse_look else "OFF")
	_apply_font(mouse_label, 2)
	mouse_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if control_menu_index == 2 else COLOR_TEXT)
	mouse_label.position = Vector2(center_offset_x + 60 * scale_factor, center_offset_y + 110 * scale_factor)
	mouse_label.custom_minimum_size = Vector2(200 * scale_factor, 14 * scale_factor)
	add_child(mouse_label)
	
	# Instructions
	var instr_label = Label.new()
	instr_label.text = "UP/DOWN=select, LEFT/RIGHT=adjust, ENTER=toggle, ESC=exit"
	_apply_font(instr_label, 1)
	instr_label.add_theme_color_override("font_color", COLOR_DEACTIVE)
	instr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr_label.position = Vector2(0, center_offset_y + 150 * scale_factor)
	instr_label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(instr_label)
	
	_update_cursor()


func _show_read_this() -> void:
	current_state = MenuState.READ_THIS
	read_this_page = 0
	
	_clear_menu_items()
	
	var bg = ColorRect.new()
	bg.name = "ReadThisBG"
	bg.color = Color(0.0, 0.0, 0.4)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var help_pages = [
		"WOLFENSTEIN 3D CONTROLS\n\n" +
		"ARROW KEYS - Move forward/back, turn left/right\n" +
		"CTRL - Fire weapon\n" +
		"SPACE - Open doors / Activate\n" +
		"SHIFT - Run\n" +
		"1-4 - Select weapon\n" +
		"ESC - Menu\n\n" +
		"MOUSE: Move to turn, Click to fire",
		
		"TIPS FOR SURVIVAL\n\n" +
		"* Search for secret push walls\n" +
		"* Collect treasures for bonus points\n" +
		"* Save your game often!\n" +
		"* Listen for enemy sounds\n" +
		"* Conserve ammo when possible\n\n" +
		"Good luck, soldier!"
	]
	
	var content = Label.new()
	content.name = "ReadThisContent"
	content.text = help_pages[read_this_page]
	_apply_font(content, 2)
	content.add_theme_color_override("font_color", COLOR_TEXT)
	content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.position = Vector2(center_offset_x + 40 * scale_factor, center_offset_y + 30 * scale_factor)
	content.size = Vector2(240 * scale_factor, 140 * scale_factor)
	add_child(content)
	
	# Page indicator
	var page_label = Label.new()
	page_label.name = "PageLabel"
	page_label.text = "Page %d of %d - Use LEFT/RIGHT, ESC to exit" % [read_this_page + 1, help_pages.size()]
	_apply_font(page_label, 1)
	page_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.position = Vector2(0, center_offset_y + 180 * scale_factor)
	page_label.size = Vector2(get_viewport().get_visible_rect().size.x, 20 * scale_factor)
	add_child(page_label)
	
	cursor_rect.visible = false


func _show_view_size_screen() -> void:
	current_state = MenuState.VIEW_SIZE
	pre_view_size = GameState.view_size
	_clear_menu_items()
	var bg = ColorRect.new()
	bg.name = "ViewSizeBG"
	bg.color = COLOR_VIEW_BORDER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var preview = ColorRect.new()
	preview.name = "ViewportPreview"
	preview.color = Color.BLACK
	add_child(preview)
	var instructions = ["Use arrows to size", "ENTER to accept", "ESC to cancel"]
	for i in range(instructions.size()):
		var label = Label.new()
		label.name = "ViewSizeInstr_%d" % i
		label.text = instructions[i]
		if FontManager.font1: label.add_theme_font_override("font", FontManager.font1)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", COLOR_TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(center_offset_x, center_offset_y + (160 + i * 12) * scale_factor)
		label.size = Vector2(320, 15)
		label.scale = Vector2(scale_factor, scale_factor)
		add_child(label)
	_update_view_size_preview()
	cursor_rect.visible = false

func _update_view_size_preview() -> void:
	var preview = get_node_or_null("ViewportPreview") as ColorRect
	if not preview: return
	var view_width = GameState.get_view_width()
	var view_height = GameState.get_view_height()
	var game_area_height = GameState.GAME_AREA_HEIGHT
	var viewport_x = (ORIG_WIDTH - view_width) / 2.0
	var viewport_y = (game_area_height - view_height) / 2.0
	preview.position = Vector2(center_offset_x + viewport_x * scale_factor, center_offset_y + viewport_y * scale_factor)
	preview.size = Vector2(view_width * scale_factor, view_height * scale_factor)

func _show_save_game_screen() -> void:
	current_state = MenuState.SAVE_GAME
	_load_save_slots()
	_refresh_save_screen()

func _refresh_save_screen() -> void:
	_clear_menu_items()
	_draw_menu_background()
	if pics.has("C_SAVEGAMEPIC"):
		var header = TextureRect.new()
		header.name = "SaveGameHeader"
		header.texture = pics["C_SAVEGAMEPIC"]
		header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.stretch_mode = TextureRect.STRETCH_SCALE
		header.position = Vector2(84 * scale_factor, 0)
		header.size = Vector2(pics["C_SAVEGAMEPIC"].get_width() * scale_factor, pics["C_SAVEGAMEPIC"].get_height() * scale_factor)
		add_child(header)
	var slot_start_y = MENU_Y + 10
	for i in range(MAX_SAVE_SLOTS):
		var frame = ColorRect.new()
		frame.color = COLOR_BORDER if i == save_slot_index else Color(0.3, 0.3, 0.3)
		frame.position = Vector2((MENU_X + 24) * scale_factor, (slot_start_y + i * 15 - 1) * scale_factor)
		frame.size = Vector2(140 * scale_factor, 12 * scale_factor)
		add_child(frame)
		var inner_bg = ColorRect.new()
		inner_bg.color = Color(0.1, 0.1, 0.1)
		inner_bg.position = Vector2((MENU_X + 25) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		inner_bg.size = Vector2(138 * scale_factor, 10 * scale_factor)
		add_child(inner_bg)
		var slot_label = Label.new()
		slot_label.name = "SaveSlot_%d" % i
		if save_input_active and i == save_slot_index: slot_label.text = (save_input_text + "_")
		elif i < save_slots.size() and save_slots[i].has("name"): slot_label.text = save_slots[i]["name"]
		else: slot_label.text = "- empty -"
		slot_label.add_theme_font_size_override("font_size", int(7 * scale_factor))
		slot_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == save_slot_index else COLOR_TEXT)
		slot_label.position = Vector2((MENU_X + 28) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		slot_label.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_label.gui_input.connect(_on_item_gui_input.bind(i, "save"))
		add_child(slot_label)
	var instr = Label.new()
	instr.text = "ENTER to save, ESC to cancel" if save_input_active else "ENTER to name save, ESC to exit"
	instr.add_theme_font_size_override("font_size", int(9 * scale_factor))
	instr.add_theme_color_override("font_color", COLOR_TEXT)
	instr.position = Vector2((MENU_X + 10) * scale_factor, (MENU_Y + 160) * scale_factor)
	add_child(instr)
	_update_cursor()

func _load_save_slots() -> void:
	save_slots.clear()
	for i in range(MAX_SAVE_SLOTS):
		var save_path = "user://saves/save_%d.json" % i
		if FileAccess.file_exists(save_path):
			var file = FileAccess.open(save_path, FileAccess.READ)
			if file:
				var save_data = JSON.parse_string(file.get_as_text())
				save_slots.append(save_data if save_data else {})
				file.close()
			else: save_slots.append({})
		else: save_slots.append({})

func _save_game_to_slot(slot: int, save_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves/")
	var save_data = {"name": save_name, "timestamp": Time.get_unix_time_from_system(), "game_state": GameState.saved_game_state}
	var file = FileAccess.open("user://saves/save_%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		_load_save_slots()
		save_input_active = false
		save_input_text = ""
		_show_save_game_screen()

func _show_load_game_screen() -> void:
	current_state = MenuState.LOAD_GAME
	_load_save_slots()
	_refresh_load_screen()

func _refresh_load_screen() -> void:
	_clear_menu_items()
	_draw_menu_background()
	var header_tex = pics.get("C_LOADGAMEPIC") if pics.has("C_LOADGAMEPIC") else pics.get("C_SAVEGAMEPIC")
	if header_tex:
		var header = TextureRect.new()
		header.texture = header_tex
		header.position = Vector2(84 * scale_factor, 0)
		header.size = Vector2(header_tex.get_width() * scale_factor, header_tex.get_height() * scale_factor)
		add_child(header)
	var slot_start_y = MENU_Y + 10
	for i in range(MAX_SAVE_SLOTS):
		var frame = ColorRect.new()
		frame.color = COLOR_BORDER if i == save_slot_index else Color(0.3, 0.3, 0.3)
		frame.position = Vector2((MENU_X + 24) * scale_factor, (slot_start_y + i * 15 - 1) * scale_factor)
		frame.size = Vector2(140 * scale_factor, 12 * scale_factor)
		add_child(frame)
		var slot_label = Label.new()
		slot_label.name = "SaveSlot_%d" % i
		slot_label.text = save_slots[i]["name"] if i < save_slots.size() and save_slots[i].has("name") else "- empty -"
		slot_label.add_theme_font_size_override("font_size", int(7 * scale_factor))
		slot_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT if i == save_slot_index else COLOR_TEXT)
		slot_label.position = Vector2((MENU_X + 28) * scale_factor, (slot_start_y + i * 15) * scale_factor)
		slot_label.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_label.gui_input.connect(_on_item_gui_input.bind(i, "save"))
		add_child(slot_label)
	_update_cursor()

func _load_game_from_slot(slot: int) -> void:
	var save_path = "user://saves/save_%d.json" % slot
	if not FileAccess.file_exists(save_path): return
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var save_data = JSON.parse_string(file.get_as_text())
		file.close()
		if save_data and save_data.has("game_state"):
			GameState.saved_game_state = save_data["game_state"]
			get_tree().change_scene_to_file("res://Wolf.tscn")

func _check_for_saved_games() -> bool:
	for i in range(MAX_SAVE_SLOTS):
		if FileAccess.file_exists("user://saves/save_%d.json" % i): return true
	return false

func _handle_up() -> void:
	match current_state:
		MenuState.MAIN: main_menu_index = (main_menu_index - 1 + main_menu_options.size()) % main_menu_options.size()
		MenuState.EPISODE_SELECT: episode_index = (episode_index - 1 + episode_options.size()) % episode_options.size()
		MenuState.DIFFICULTY_SELECT: difficulty_index = (difficulty_index - 1 + difficulty_options.size()) % difficulty_options.size()
		MenuState.MAP_SELECT:
			var episode_start = selected_episode * 10
			var maps_in_episode = mini(10, available_maps.size() - episode_start)
			if maps_in_episode > 0: map_index = (map_index - 1 + maps_in_episode) % maps_in_episode
		MenuState.VIEW_SIZE:
			GameState.increase_view_size()
			_update_view_size_preview()
		MenuState.SAVE_GAME:
			if not save_input_active:
				save_slot_index = (save_slot_index - 1 + MAX_SAVE_SLOTS) % MAX_SAVE_SLOTS
		MenuState.LOAD_GAME:
			save_slot_index = (save_slot_index - 1 + MAX_SAVE_SLOTS) % MAX_SAVE_SLOTS
		MenuState.SOUND:
			sound_menu_index = (sound_menu_index - 1 + 2) % 2
			_show_sound_menu()
		MenuState.CONTROL:
			control_menu_index = (control_menu_index - 1 + 3) % 3
			_show_control_menu()
	
	_update_cursor()
	_update_menu_highlights()

func _handle_down() -> void:
	match current_state:
		MenuState.MAIN: main_menu_index = (main_menu_index + 1) % main_menu_options.size()
		MenuState.EPISODE_SELECT: episode_index = (episode_index + 1) % episode_options.size()
		MenuState.DIFFICULTY_SELECT: difficulty_index = (difficulty_index + 1) % difficulty_options.size()
		MenuState.MAP_SELECT:
			var episode_start = selected_episode * 10
			var maps_in_episode = mini(10, available_maps.size() - episode_start)
			if maps_in_episode > 0: map_index = (map_index + 1) % maps_in_episode
		MenuState.VIEW_SIZE:
			GameState.decrease_view_size()
			_update_view_size_preview()
		MenuState.SAVE_GAME:
			if not save_input_active:
				save_slot_index = (save_slot_index + 1) % MAX_SAVE_SLOTS
		MenuState.LOAD_GAME:
			save_slot_index = (save_slot_index + 1) % MAX_SAVE_SLOTS
		MenuState.SOUND:
			sound_menu_index = (sound_menu_index + 1) % 2
			_show_sound_menu()
		MenuState.CONTROL:
			control_menu_index = (control_menu_index + 1) % 3
			_show_control_menu()
	
	_update_cursor()
	_update_menu_highlights()

func _handle_left() -> void:
	match current_state:
		MenuState.VIEW_SIZE:
			GameState.decrease_view_size()
			_update_view_size_preview()
		MenuState.CONTROL:
			if control_menu_index == 0:  # Mouse sensitivity
				GameState.mouse_sensitivity = max(1, GameState.mouse_sensitivity - 1)
				_show_control_menu()
		MenuState.READ_THIS:
			read_this_page = max(0, read_this_page - 1)
			_show_read_this()


func _handle_right() -> void:
	match current_state:
		MenuState.VIEW_SIZE:
			GameState.increase_view_size()
			_update_view_size_preview()
		MenuState.CONTROL:
			if control_menu_index == 0:  # Mouse sensitivity
				GameState.mouse_sensitivity = min(10, GameState.mouse_sensitivity + 1)
				_show_control_menu()
		MenuState.READ_THIS:
			read_this_page = min(1, read_this_page + 1)
			_show_read_this()

func _start_game() -> void:
	var actual_map_index = selected_episode * 10 + map_index
	if actual_map_index < available_maps.size():
		GameState.selected_map_path = available_maps[actual_map_index].path
		GameState.current_map = actual_map_index
	SoundManager.reload_sounds()
	GameState.start_new_game()
	GameState.in_game = true
	get_tree().change_scene_to_file("res://Wolf.tscn")
