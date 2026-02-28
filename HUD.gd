extends CanvasLayer

var pics_path: String:
	get: return GameState.get_pics_path()

const STATUS_BAR_Y = 160

const POS_LEVEL_X = 16
const POS_SCORE_X = 48
const POS_LIVES_X = 112
const POS_HEALTH_X = 168
const POS_AMMO_X = 216
const POS_FACE_X = 136
const POS_FACE_Y = 4
const POS_WEAPON_X = 256 
const POS_KEYS_X = 240
const POS_KEYS_Y = 4
const POS_NUMBER_Y = 16

var scale_factor: float = 2.0

var statusbar_texture: Texture2D
var digit_textures: Array[Texture2D] = []
var face_textures: Array[Texture2D] = []
var weapon_textures: Array[Texture2D] = []
var key_textures: Array[Texture2D] = []

var statusbar_rect: TextureRect
var face_rect: TextureRect
var weapon_rect: TextureRect
var gold_key_rect: TextureRect
var silver_key_rect: TextureRect
var number_container: Control

var level_digits: Array[TextureRect] = []
var score_digits: Array[TextureRect] = []
var lives_digits: Array[TextureRect] = []
var health_digits: Array[TextureRect] = []
var ammo_digits: Array[TextureRect] = []

const TICKS_PER_SECOND = 70.0
const FACETICS = 70
var face_time_accumulator: float = 0.0
var facecount: int = 0
var faceframe: int = 0
var got_gatling: bool = false

func _ready() -> void:
	print("WolfHUD: Loading authentic Wolf3D status bar...")
	
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	_load_assets()
	_create_ui()
	_connect_signals()
	_update_all()
	
	print("WolfHUD: Status bar ready!")

func _load_assets() -> void:
	statusbar_texture = _load_pic("083_STATUSBARPIC.png")
	
	digit_textures.append(_load_pic("095_N_BLANKPIC.png"))  # Blank
	for i in range(10):
		var pic = _load_pic("%03d_N_%dPIC.png" % [96 + i, i])
		digit_textures.append(pic)
		if pic == null:
			push_error("WolfHUD: Failed to load digit %d" % i)
	print("WolfHUD: Loaded %d digit textures" % digit_textures.size())
	
	for i in range(8):
		for j in ["A", "B", "C"]:
			var idx = 106 + (i * 3) + (["A", "B", "C"].find(j))
			face_textures.append(_load_pic("%03d_FACE%d%sPIC.png" % [idx, i + 1, j]))
	
	weapon_textures.append(_load_pic("088_KNIFEPIC.png"))
	weapon_textures.append(_load_pic("089_GUNPIC.png"))
	weapon_textures.append(_load_pic("090_MACHINEGUNPIC.png"))
	weapon_textures.append(_load_pic("091_GATLINGGUNPIC.png"))
	
	key_textures.append(_load_pic("092_NOKEYPIC.png"))
	key_textures.append(_load_pic("093_GOLDKEYPIC.png"))
	key_textures.append(_load_pic("094_SILVERKEYPIC.png"))

func _load_pic(filename: String) -> Texture2D:
	var path = pics_path + filename
	var texture = load(path) as Texture2D
	if texture:
		return texture
	var image = Image.load_from_file(path)
	if image:
		return ImageTexture.create_from_image(image)
	else:
		push_error("WolfHUD: Failed to load " + path)
		return null

func _create_ui() -> void:
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / 320.0
	
	statusbar_rect = TextureRect.new()
	statusbar_rect.texture = statusbar_texture
	statusbar_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	statusbar_rect.stretch_mode = TextureRect.STRETCH_SCALE
	statusbar_rect.custom_minimum_size = Vector2(320 * scale_factor, 40 * scale_factor)
	statusbar_rect.position = Vector2(0, window_size.y - 40 * scale_factor)
	add_child(statusbar_rect)
	
	number_container = Control.new()
	statusbar_rect.add_child(number_container)
	
	level_digits = _create_digit_group(2)
	score_digits = _create_digit_group(6)
	lives_digits = _create_digit_group(1)
	health_digits = _create_digit_group(3)
	ammo_digits = _create_digit_group(2)
	
	_position_digits(level_digits, POS_LEVEL_X)
	_position_digits(score_digits, POS_SCORE_X)
	_position_digits(lives_digits, POS_LIVES_X)
	_position_digits(health_digits, POS_HEALTH_X)
	_position_digits(ammo_digits, POS_AMMO_X)
	
	face_rect = TextureRect.new()
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_rect.stretch_mode = TextureRect.STRETCH_SCALE
	face_rect.position = Vector2(POS_FACE_X * scale_factor, POS_FACE_Y * scale_factor)
	face_rect.custom_minimum_size = Vector2(24 * scale_factor, 32 * scale_factor)
	number_container.add_child(face_rect)
	
	weapon_rect = TextureRect.new()
	weapon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_rect.stretch_mode = TextureRect.STRETCH_SCALE
	weapon_rect.position = Vector2(POS_WEAPON_X * scale_factor, POS_FACE_Y * scale_factor)
	weapon_rect.custom_minimum_size = Vector2(24 * scale_factor, 32 * scale_factor)
	number_container.add_child(weapon_rect)
	
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
	GameState.player_died.connect(_on_player_died)

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
func _latch_number(digits: Array[TextureRect], width: int, number: int) -> void:
	if digit_textures.size() < 11:
		push_error("WolfHUD: Not enough digit textures loaded: %d" % digit_textures.size())
		return
	
	var str_num = str(number)
	var length = str_num.length()
	
	var digit_idx = 0
	while digit_idx < width - length:
		if digit_idx < digits.size():
			digits[digit_idx].texture = digit_textures[0]
		digit_idx += 1
	
	var str_idx = 0
	if length > width:
		str_idx = length - width
	
	while str_idx < length and digit_idx < digits.size():
		var digit_char = str_num[str_idx]
		var digit_value = digit_char.unicode_at(0) - 48
		if digit_value >= 0 and digit_value <= 9:
			digits[digit_idx].texture = digit_textures[digit_value + 1]
		else:
			digits[digit_idx].texture = digit_textures[0]
		digit_idx += 1
		str_idx += 1

# ===== Draw Functions (matching original C) =====

func _draw_level(level: int) -> void:
	_latch_number(level_digits, 2, level)

func _draw_score(score: int) -> void:
	_latch_number(score_digits, 6, score)

func _draw_lives(lives: int) -> void:
	_latch_number(lives_digits, 1, max(lives, 0))

func _draw_health(health: int) -> void:
	_latch_number(health_digits, 3, health)

func _draw_ammo(ammo: int) -> void:
	_latch_number(ammo_digits, 2, ammo)

# ===== Face System (from original WL_AGENT.C) =====
func _draw_face() -> void:
	if face_textures.is_empty():
		return
	
	var health = GameState.health
	
	if health <= 0:
		face_rect.texture = face_textures[21]
	elif got_gatling:
		face_rect.texture = face_textures[0]  # FACE1A
	else:
		var health_level = clampi((100 - health) / 16, 0, 7)
		var face_idx = (health_level * 3) + faceframe
		face_idx = clampi(face_idx, 0, face_textures.size() - 1)
		face_rect.texture = face_textures[face_idx]

func _update_face(delta: float) -> void:
	face_time_accumulator += delta
	
	var ticks_to_add = int(face_time_accumulator * TICKS_PER_SECOND)
	if ticks_to_add > 0:
		facecount += ticks_to_add
		face_time_accumulator -= float(ticks_to_add) / TICKS_PER_SECOND
	
	if facecount > randi() % FACETICS:
		faceframe = randi() % 3
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
	
	if GameState.has_key(0):
		gold_key_rect.texture = key_textures[1]
	else:
		gold_key_rect.texture = key_textures[0]
	
	if GameState.has_key(1):
		silver_key_rect.texture = key_textures[2]
	else:
		silver_key_rect.texture = key_textures[0]

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

func _on_player_died() -> void:
	_draw_face()

func _process(delta: float) -> void:
	_update_face(delta)
