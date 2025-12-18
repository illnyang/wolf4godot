# MainMenu.gd
# Wolf3D-style main menu with game and map selection
extends Control

const PICS_PATH = "res://assets/vga/pics/"

# Menu states
enum MenuState { TITLE, MAIN, GAME_SELECT, MAP_SELECT }
var current_state: MenuState = MenuState.TITLE

# Selection indices
var main_menu_index: int = 0
var game_index: int = 0
var map_index: int = 0

# Available games and maps
var available_games: Array[Dictionary] = []
var available_maps: Array[Dictionary] = []

# UI elements
var cursor_texture1: Texture2D
var cursor_texture2: Texture2D
var cursor_frame: int = 0
var cursor_timer: float = 0.0

# UI nodes
var menu_container: VBoxContainer
var list_container: VBoxContainer
var cursor_rect: TextureRect
var title_label: Label
var header_label: Label

# Main menu options
var main_menu_options = ["NEW GAME", "SELECT GAME", "QUIT"]

func _ready() -> void:
	# Wait for extraction
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	_load_assets()
	_detect_games()
	_create_ui()
	_show_title()

func _load_assets() -> void:
	cursor_texture1 = load(PICS_PATH + "008_C_CURSOR1PIC.png")
	cursor_texture2 = load(PICS_PATH + "009_C_CURSOR2PIC.png")

func _detect_games() -> void:
	available_games.clear()
	
	# Check for Wolf3D
	var wolf3d_maps = DirAccess.open("user://assets/wolf3d/maps/json/")
	if wolf3d_maps != null:
		available_games.append({
			"id": "wolf3d",
			"name": "WOLFENSTEIN 3D",
			"maps_path": "user://assets/wolf3d/maps/json/"
		})
	
	# Check for SOD
	var sod_maps = DirAccess.open("user://assets/sod/maps/json/")
	if sod_maps != null:
		available_games.append({
			"id": "sod",
			"name": "SPEAR OF DESTINY",
			"maps_path": "user://assets/sod/maps/json/"
		})
	
	# Check for Blake Stone
	var blake_maps = DirAccess.open("user://assets/blake_stone/maps/json/")
	if blake_maps != null:
		available_games.append({
			"id": "blake_stone",
			"name": "BLAKE STONE",
			"maps_path": "user://assets/blake_stone/maps/json/"
		})
	
	print("MainMenu: Found %d games" % available_games.size())
	
	# If only one game is available, auto-select it
	if available_games.size() == 1:
		GameState.selected_game = available_games[0].id

func _scan_maps(maps_path: String) -> void:
	available_maps.clear()
	
	var dir = DirAccess.open(maps_path)
	if dir == null:
		push_error("MainMenu: Cannot open maps directory: " + maps_path)
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
	
	# Sort maps by filename
	available_maps.sort_custom(func(a, b): return a.filename < b.filename)
	print("MainMenu: Found %d maps" % available_maps.size())

func _extract_map_name(filename: String) -> String:
	var name = filename.replace(".json", "")
	var underscore_pos = name.find("_")
	if underscore_pos >= 0 and underscore_pos < 3:
		name = name.substr(underscore_pos + 1)
	return name

func _create_ui() -> void:
	# Dark blue background
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	title_label = Label.new()
	title_label.text = "WOLFENSTEIN 3D"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 50)
	title_label.size = Vector2(get_viewport().get_visible_rect().size.x, 60)
	add_child(title_label)
	
	# Header for lists
	header_label = Label.new()
	header_label.add_theme_font_size_override("font_size", 36)
	header_label.add_theme_color_override("font_color", Color.YELLOW)
	header_label.position = Vector2(100, 120)
	header_label.visible = false
	add_child(header_label)
	
	# Menu container
	menu_container = VBoxContainer.new()
	menu_container.position = Vector2(200, 200)
	menu_container.add_theme_constant_override("separation", 20)
	add_child(menu_container)
	
	# List container for games/maps
	list_container = VBoxContainer.new()
	list_container.position = Vector2(100, 170)
	list_container.add_theme_constant_override("separation", 8)
	list_container.visible = false
	add_child(list_container)
	
	# Cursor
	cursor_rect = TextureRect.new()
	cursor_rect.texture = cursor_texture1
	cursor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cursor_rect.stretch_mode = TextureRect.STRETCH_SCALE
	cursor_rect.custom_minimum_size = Vector2(32, 32)
	add_child(cursor_rect)

func _show_title() -> void:
	current_state = MenuState.TITLE
	title_label.text = "WOLFENSTEIN 3D"
	title_label.visible = true
	header_label.visible = false
	menu_container.visible = false
	list_container.visible = false
	cursor_rect.visible = false

func _show_main_menu() -> void:
	current_state = MenuState.MAIN
	main_menu_index = 0
	
	# Clear and rebuild menu
	for child in menu_container.get_children():
		child.queue_free()
	
	for option in main_menu_options:
		var label = Label.new()
		label.text = option
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color.WHITE)
		menu_container.add_child(label)
	
	title_label.visible = true
	header_label.visible = false
	menu_container.visible = true
	list_container.visible = false
	cursor_rect.visible = true
	_update_cursor()

func _show_game_select() -> void:
	current_state = MenuState.GAME_SELECT
	game_index = 0
	
	# Clear and rebuild
	for child in list_container.get_children():
		child.queue_free()
	
	header_label.text = "SELECT GAME"
	header_label.visible = true
	
	for game in available_games:
		var label = Label.new()
		label.text = game.name
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color.WHITE)
		list_container.add_child(label)
	
	title_label.visible = false
	menu_container.visible = false
	list_container.visible = true
	cursor_rect.visible = true
	_update_cursor()
	_highlight_selection()

func _show_map_select() -> void:
	current_state = MenuState.MAP_SELECT
	map_index = 0
	
	# Scan maps for selected game
	var maps_path = "user://assets/%s/maps/json/" % GameState.selected_game
	_scan_maps(maps_path)
	
	# Clear and rebuild
	for child in list_container.get_children():
		child.queue_free()
	
	var game_name = _get_game_display_name(GameState.selected_game)
	header_label.text = game_name + " - SELECT MAP"
	header_label.visible = true
	
	# Show max 15 maps at a time
	var maps_to_show = min(available_maps.size(), 15)
	for i in range(maps_to_show):
		var label = Label.new()
		label.text = available_maps[i].name
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color.WHITE)
		list_container.add_child(label)
	
	title_label.visible = false
	menu_container.visible = false
	list_container.visible = true
	cursor_rect.visible = true
	_update_cursor()
	_highlight_selection()

func _update_cursor() -> void:
	cursor_rect.texture = cursor_texture1 if cursor_frame == 0 else cursor_texture2
	
	var target_y: float = 0
	var target_x: float = 0
	
	match current_state:
		MenuState.MAIN:
			target_x = menu_container.position.x - 40
			target_y = menu_container.position.y + main_menu_index * 52 + 4
		MenuState.GAME_SELECT:
			target_x = list_container.position.x - 40
			target_y = list_container.position.y + game_index * 36 + 4
		MenuState.MAP_SELECT:
			target_x = list_container.position.x - 40
			target_y = list_container.position.y + map_index * 28 + 4
	
	cursor_rect.position = Vector2(target_x, target_y)

func _highlight_selection() -> void:
	var children = list_container.get_children()
	var selected_idx = game_index if current_state == MenuState.GAME_SELECT else map_index
	
	for i in range(children.size()):
		var label = children[i] as Label
		if i == selected_idx:
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.add_theme_color_override("font_color", Color.WHITE)

func _process(delta: float) -> void:
	cursor_timer += delta
	if cursor_timer > 0.3:
		cursor_timer = 0.0
		cursor_frame = 1 - cursor_frame
		if cursor_rect.visible:
			cursor_rect.texture = cursor_texture1 if cursor_frame == 0 else cursor_texture2

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_handle_accept()
	elif event.is_action_pressed("ui_cancel"):
		_handle_cancel()
	elif event.is_action_pressed("ui_up"):
		_handle_up()
	elif event.is_action_pressed("ui_down"):
		_handle_down()

func _handle_accept() -> void:
	match current_state:
		MenuState.TITLE:
			_show_main_menu()
		MenuState.MAIN:
			match main_menu_index:
				0:  # NEW GAME
					if available_games.size() == 1:
						GameState.selected_game = available_games[0].id
						_show_map_select()
					elif available_games.size() > 1:
						_show_game_select()
					else:
						print("No games available!")
				1:  # SELECT GAME
					if available_games.size() > 0:
						_show_game_select()
				2:  # QUIT
					get_tree().quit()
		MenuState.GAME_SELECT:
			if game_index < available_games.size():
				GameState.selected_game = available_games[game_index].id
				_show_map_select()
		MenuState.MAP_SELECT:
			_start_game(map_index)

func _handle_cancel() -> void:
	match current_state:
		MenuState.MAIN:
			_show_title()
		MenuState.GAME_SELECT:
			_show_main_menu()
		MenuState.MAP_SELECT:
			if available_games.size() > 1:
				_show_game_select()
			else:
				_show_main_menu()

func _handle_up() -> void:
	match current_state:
		MenuState.MAIN:
			main_menu_index = (main_menu_index - 1 + main_menu_options.size()) % main_menu_options.size()
			_update_cursor()
		MenuState.GAME_SELECT:
			game_index = (game_index - 1 + available_games.size()) % available_games.size()
			_update_cursor()
			_highlight_selection()
		MenuState.MAP_SELECT:
			map_index = (map_index - 1 + available_maps.size()) % available_maps.size()
			_update_cursor()
			_highlight_selection()

func _handle_down() -> void:
	match current_state:
		MenuState.MAIN:
			main_menu_index = (main_menu_index + 1) % main_menu_options.size()
			_update_cursor()
		MenuState.GAME_SELECT:
			game_index = (game_index + 1) % available_games.size()
			_update_cursor()
			_highlight_selection()
		MenuState.MAP_SELECT:
			map_index = (map_index + 1) % available_maps.size()
			_update_cursor()
			_highlight_selection()

func _start_game(idx: int) -> void:
	if idx < available_maps.size():
		GameState.selected_map_path = available_maps[idx].path
		GameState.current_map = idx
		print("MainMenu: Starting %s with map: %s" % [GameState.selected_game, GameState.selected_map_path])
	
	# Reload sounds for selected game
	SoundManager.reload_sounds()
	
	GameState.start_new_game()
	get_tree().change_scene_to_file("res://Wolf.tscn")

func _get_game_display_name(game_id: String) -> String:
	match game_id:
		"wolf3d": return "WOLFENSTEIN 3D"
		"sod": return "SPEAR OF DESTINY"
		"blake_stone": return "BLAKE STONE"
		_: return game_id.to_upper()
