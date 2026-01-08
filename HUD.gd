# Original C code logic from WL_AGENT.C
extends CanvasLayer

const PICS_PATH = "res://assets/vga/pics/"

# Original Wolf3D status bar positions (320x200 VGA resolution)
# These are character/tile positions, each tile is 8x8 pixels in original
const STATUS_BAR_Y = 160  # Y position where status bar starts (bottom of 200-pixel screen)

# Position mappings from original C code (in 8-pixel units for LatchNumber)
# Converted to pixel positions within status bar
const POS_LEVEL_X = 16    # Level number
const POS_SCORE_X = 48    # Score 
const POS_LIVES_X = 112   # Lives
const POS_HEALTH_X = 168  # Health
const POS_AMMO_X = 216    # Ammo
const POS_FACE_X = 136    # BJ face
const POS_FACE_Y = 4
const POS_WEAPON_X = 256  # Weapon icon
const POS_KEYS_X = 240    # Keys
const POS_KEYS_Y = 4
const POS_NUMBER_Y = 16   # Y offset for numbers within status bar

# Scale factor for rendering (original was 320x200, we'll scale up)
var scale_factor: float = 2.0

# Loaded textures
var statusbar_texture: Texture2D
var digit_textures: Array[Texture2D] = []  # 0-9 plus blank
var face_textures: Array[Texture2D] = []   # 24 faces (8 health levels x 3 variations)
var weapon_textures: Array[Texture2D] = [] # 4 weapons
var key_textures: Array[Texture2D] = []    # no key, gold, silver

# UI Nodes
var statusbar_rect: TextureRect
var face_rect: TextureRect
var weapon_rect: TextureRect
var gold_key_rect: TextureRect
var silver_key_rect: TextureRect
var number_container: Control  # Container for digit sprites

# Number display nodes - arrays of TextureRects for each stat
var level_digits: Array[TextureRect] = []
var score_digits: Array[TextureRect] = []
var lives_digits: Array[TextureRect] = []
var health_digits: Array[TextureRect] = []
var ammo_digits: Array[TextureRect] = []

# Face animation (from original: faceframe changes randomly every ~70 tics)
const FACETICS = 70
var facecount: int = 0
var faceframe: int = 0  # 0, 1, or 2 for face variation (A, B, C)
var got_gatling: bool = false  # Special gatling pickup face

func _ready() -> void:
	print("WolfHUD: Loading authentic Wolf3D status bar...")
	
	# Wait for assets if needed
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	_load_assets()
	_create_ui()
	_connect_signals()
	_update_all()
	
	print("WolfHUD: Status bar ready!")

func _load_assets() -> void:
	# Load status bar background
	statusbar_texture = _load_pic("083_STATUSBARPIC.png")
	
	# Load digit textures (blank = index 0, then 0-9 = index 1-10)
	digit_textures.append(_load_pic("095_N_BLANKPIC.png"))  # Blank
	for i in range(10):
		digit_textures.append(_load_pic("%03d_N_%dPIC.png" % [96 + i, i]))
	
	# Load face textures (8 health levels x 3 variations = 24 faces)
	# FACE1A=106, FACE1B=107, FACE1C=108, FACE2A=109... FACE8A=127
	for i in range(8):
		for j in ["A", "B", "C"]:
			var idx = 106 + (i * 3) + (["A", "B", "C"].find(j))
			face_textures.append(_load_pic("%03d_FACE%d%sPIC.png" % [idx, i + 1, j]))
	
	# Load weapon textures
	weapon_textures.append(_load_pic("088_KNIFEPIC.png"))
	weapon_textures.append(_load_pic("089_GUNPIC.png"))
	weapon_textures.append(_load_pic("090_MACHINEGUNPIC.png"))
	weapon_textures.append(_load_pic("091_GATLINGGUNPIC.png"))
	
	# Load key textures
	key_textures.append(_load_pic("092_NOKEYPIC.png"))
	key_textures.append(_load_pic("093_GOLDKEYPIC.png"))
	key_textures.append(_load_pic("094_SILVERKEYPIC.png"))

func _load_pic(filename: String) -> Texture2D:
	var path = PICS_PATH + filename
	# For res:// paths, try using load() first (works with imported resources)
	var texture = load(path) as Texture2D
	if texture:
		return texture
	# Fallback to loading image directly
	var image = Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	else:
		push_error("WolfHUD: Failed to load " + path)
		return null

func _create_ui() -> void:
	# Calculate scale based on window size
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / 320.0
	
	# Create status bar background
	statusbar_rect = TextureRect.new()
	statusbar_rect.texture = statusbar_texture
	statusbar_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	statusbar_rect.stretch_mode = TextureRect.STRETCH_SCALE
	statusbar_rect.custom_minimum_size = Vector2(320 * scale_factor, 40 * scale_factor)
	statusbar_rect.position = Vector2(0, window_size.y - 40 * scale_factor)
	add_child(statusbar_rect)
	
	# Container for all number/icon overlays (child of status bar for relative positioning)
	number_container = Control.new()
	statusbar_rect.add_child(number_container)
	
	# Create digit TextureRects for each stat
	level_digits = _create_digit_group(2)   # 2 digits
	score_digits = _create_digit_group(6)   # 6 digits
	lives_digits = _create_digit_group(1)   # 1 digit
	health_digits = _create_digit_group(3)  # 3 digits
	ammo_digits = _create_digit_group(2)    # 2 digits
	
	# Position digit groups
	_position_digits(level_digits, POS_LEVEL_X)
	_position_digits(score_digits, POS_SCORE_X)
	_position_digits(lives_digits, POS_LIVES_X)
	_position_digits(health_digits, POS_HEALTH_X)
	_position_digits(ammo_digits, POS_AMMO_X)
	
	# Create face display
	face_rect = TextureRect.new()
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_rect.stretch_mode = TextureRect.STRETCH_SCALE
	face_rect.position = Vector2(POS_FACE_X * scale_factor, POS_FACE_Y * scale_factor)
	face_rect.custom_minimum_size = Vector2(24 * scale_factor, 32 * scale_factor)
	number_container.add_child(face_rect)
	
	# Create weapon display
	weapon_rect = TextureRect.new()
	weapon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	weapon_rect.position = Vector2(POS_WEAPON_X * scale_factor, POS_FACE_Y * scale_factor)
	weapon_rect.custom_minimum_size = Vector2(24 * scale_factor, 32 * scale_factor)
	number_container.add_child(weapon_rect)
	
	# Create key displays
	gold_key_rect = TextureRect.new()
	gold_key_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gold_key_rect.stretch_mode = TextureRect.STRETCH_SCALE
	gold_key_rect.position = Vector2(POS_KEYS_X * scale_factor, POS_KEYS_Y * scale_factor)
	gold_key_rect.custom_minimum_size = Vector2(8 * scale_factor, 16 * scale_factor)
	number_container.add_child(gold_key_rect)
	
	silver_key_rect = TextureRect.new()
	silver_key_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	silver_key_rect.stretch_mode = TextureRect.STRETCH_SCALE
	silver_key_rect.position = Vector2((POS_KEYS_X + 8) * scale_factor, POS_KEYS_Y * scale_factor)
	silver_key_rect.custom_minimum_size = Vector2(8 * scale_factor, 16 * scale_factor)
	number_container.add_child(silver_key_rect)

func _create_digit_group(count: int) -> Array[TextureRect]:
	var digits: Array[TextureRect] = []
	for i in range(count):
		var digit = TextureRect.new()
		digit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		digit.stretch_mode = TextureRect.STRETCH_SCALE
		digit.custom_minimum_size = Vector2(8 * scale_factor, 16 * scale_factor)
		number_container.add_child(digit)
		digits.append(digit)
	return digits

func _position_digits(digits: Array[TextureRect], start_x: float) -> void:
	for i in range(digits.size()):
		digits[i].position = Vector2((start_x + i * 8) * scale_factor, POS_NUMBER_Y * scale_factor)

func _connect_signals() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.ammo_changed.connect(_on_ammo_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.keys_changed.connect(_on_keys_changed)
	GameState.weapon_changed.connect(_on_weapon_changed)

func _update_all() -> void:
	_draw_level(GameState.current_map + 1)
	_draw_score(GameState.score)
	_draw_lives(GameState.lives)
	_draw_health(GameState.health)
	_draw_ammo(GameState.ammo)
	_draw_face()
	_draw_weapon()
	_draw_keys()

# ===== Original Wolf3D LatchNumber implementation =====
# Right justifies and pads with blanks
func _latch_number(digits: Array[TextureRect], width: int, number: int) -> void:
	var str_num = str(number)
	var length = str_num.length()
	
	# Pad with blanks from left
	var digit_idx = 0
	while digit_idx < width - length:
		if digit_idx < digits.size():
			digits[digit_idx].texture = digit_textures[0]  # Blank
		digit_idx += 1
	
	# Draw digits
	var str_idx = 0
	if length > width:
		str_idx = length - width  # Skip leading digits if number too large
	
	while str_idx < length and digit_idx < digits.size():
		var digit_char = str_num[str_idx]
		var digit_value = digit_char.to_int()  # Convert "3" -> 3
		digits[digit_idx].texture = digit_textures[digit_value + 1]  # +1 because index 0 is blank
		digit_idx += 1
		str_idx += 1

# ===== Draw Functions (matching original C) =====

func _draw_level(level: int) -> void:
	_latch_number(level_digits, 2, level)

func _draw_score(score: int) -> void:
	_latch_number(score_digits, 6, score)

func _draw_lives(lives: int) -> void:
	_latch_number(lives_digits, 1, lives)

func _draw_health(health: int) -> void:
	_latch_number(health_digits, 3, health)

func _draw_ammo(ammo: int) -> void:
	_latch_number(ammo_digits, 2, ammo)

# ===== Face System (from original WL_AGENT.C) =====
# Formula: FACE1APIC + 3*((100-health)/16) + faceframe
func _draw_face() -> void:
	if face_textures.is_empty():
		return
	
	var health = GameState.health
	
	if health <= 0:
		# Dead face (FACE8A = index 21)
		face_rect.texture = face_textures[21]
	elif got_gatling:
		# Special gatling pickup face - use happy face with wide eyes
		face_rect.texture = face_textures[0]  # FACE1A
	else:
		# Calculate face index based on health
		# Original: 3 * ((100 - health) / 16) + faceframe
		var health_level = clampi((100 - health) / 16, 0, 7)
		var face_idx = (health_level * 3) + faceframe
		face_idx = clampi(face_idx, 0, face_textures.size() - 1)
		face_rect.texture = face_textures[face_idx]

# Update face animation (called from _process)
func _update_face() -> void:
	facecount += 1
	
	if facecount > randi() % 70:  # Original used US_RndT() >> 6
		faceframe = randi() % 3
		if faceframe == 3:
			faceframe = 1
		facecount = 0
		_draw_face()

func _draw_weapon() -> void:
	if weapon_textures.is_empty():
		return
	
	var weapon_idx = GameState.weapon as int
	weapon_idx = clampi(weapon_idx, 0, weapon_textures.size() - 1)
	weapon_rect.texture = weapon_textures[weapon_idx]

func _draw_keys() -> void:
	if key_textures.is_empty():
		return
	
	# Gold key = bit 0, Silver key = bit 1
	if GameState.has_key(0):
		gold_key_rect.texture = key_textures[1]  # Gold
	else:
		gold_key_rect.texture = key_textures[0]  # No key
	
	if GameState.has_key(1):
		silver_key_rect.texture = key_textures[2]  # Silver
	else:
		silver_key_rect.texture = key_textures[0]  # No key

# ===== Signal Handlers =====

func _on_health_changed(new_health: int) -> void:
	_draw_health(new_health)
	got_gatling = false
	_draw_face()

func _on_ammo_changed(new_ammo: int) -> void:
	_draw_ammo(new_ammo)

func _on_lives_changed(new_lives: int) -> void:
	_draw_lives(new_lives)

func _on_score_changed(new_score: int) -> void:
	_draw_score(new_score)

func _on_keys_changed(new_keys: int) -> void:
	_draw_keys()

func _on_weapon_changed(new_weapon: GameState.Weapon) -> void:
	_draw_weapon()

# ===== Process for face animation =====

func _process(_delta: float) -> void:
	_update_face()
