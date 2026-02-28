extends CanvasLayer

var pics_path: String:
	get: return GameState.get_pics_path()

const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200
const STATUS_BAR_Y = 160

const CHAR_WIDTH = 16
const CHAR_SMALL = 8

const POS_LEVEL_X = 16
const POS_SCORE_X = 48
const POS_LIVES_X = 112
const POS_FACE_X = 136
const POS_HEALTH_X = 168
const POS_AMMO_X = 216
const POS_NUMBER_Y = 16

enum Phase { TIME_BONUS, KILL_RATIO, SECRET_RATIO, TREASURE_RATIO, DONE }
var current_phase: Phase = Phase.TIME_BONUS

var char_pics: Dictionary = {}
var hud_digit_textures: Array[Texture2D] = []
var face_textures: Array[Texture2D] = []
var weapon_textures: Array[Texture2D] = []
var bj_textures: Array[Texture2D] = []
var statusbar_texture: Texture2D

var scale_factor: float = 2.0
var bj_sprite: TextureRect
var statusbar_rect: TextureRect
var text_container: Control
var hud_score_digits: Array[TextureRect] = []
var hud_lives_digit: TextureRect
var hud_health_digits: Array[TextureRect] = []
var hud_ammo_digits: Array[TextureRect] = []
var hud_level_digits: Array[TextureRect] = []
var hud_face: TextureRect
var hud_weapon: TextureRect

var label_bonus: Node2D
var label_kill: Node2D
var label_secret: Node2D
var label_treasure: Node2D

var floor_num: int = 1
var final_time_taken: float = 0.0
var final_kill_ratio: int = 0
var final_secret_ratio: int = 0
var final_treasure_ratio: int = 0
var par_time_str: String = "01:30"
var time_bonus_total: int = 0

var display_bonus: int = 0
var display_kill: int = 0
var display_secret: int = 0
var display_treasure: int = 0

var bj_timer: float = 0.0
var bj_frame: int = 0
var count_timer: float = 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 100
	
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.y / float(ORIG_HEIGHT)
	
	_load_assets()
	_init_stats()
	_create_ui()
	
	SoundManager.play_sfx("LEVELDONESND")

func _load_assets() -> void:
	for i in range(10):
		char_pics[str(i)] = _load_pic("%03d_L_NUM%dPIC.png" % [42 + i, i])
	char_pics[":"] = _load_pic("041_L_COLONPIC.png")
	char_pics["%"] = _load_pic("052_L_PERCENTPIC.png")
	for i in range(26):
		var L = char("A".unicode_at(0) + i)
		char_pics[L] = _load_pic("%03d_L_%sPIC.png" % [53 + i, L])
	
	hud_digit_textures.append(_load_pic("095_N_BLANKPIC.png"))
	for i in range(10):
		hud_digit_textures.append(_load_pic("%03d_N_%dPIC.png" % [96 + i, i]))
	
	for i in range(3):
		face_textures.append(_load_pic("%03d_FACE1%sPIC.png" % [106 + i, ["A","B","C"][i]]))
	
	bj_textures.append(_load_pic("040_L_GUYPIC.png"))
	bj_textures.append(_load_pic("081_L_GUY2PIC.png"))
	if bj_textures.size() >= 2:
		print("LevelComplete: Loaded BJ textures: ", bj_textures[0].get_size(), " and ", bj_textures[1].get_size())
	
	statusbar_texture = _load_pic("083_STATUSBARPIC.png")
	
	weapon_textures.append(_load_pic("088_KNIFEPIC.png"))
	weapon_textures.append(_load_pic("089_GUNPIC.png"))
	weapon_textures.append(_load_pic("090_MACHINEGUNPIC.png"))
	weapon_textures.append(_load_pic("091_GATLINGGUNPIC.png"))

func _init_stats() -> void:
	floor_num = GameState.current_map + 1
	if GameState.level_stats:
		final_time_taken = GameState.level_stats.level_time
		final_kill_ratio = GameState.level_stats.get_kill_ratio()
		final_secret_ratio = GameState.level_stats.get_secret_ratio()
		final_treasure_ratio = GameState.level_stats.get_treasure_ratio()
	
	var par_times = [1.5, 2, 2, 3.5, 3, 3, 2.5, 2.5, 0, 0]
	var par_strs = ["01:30", "02:00", "02:00", "03:30", "03:00", "03:00", "02:30", "02:30", "??:??", "??:??"]
	var idx = GameState.current_map % 10
	var par_sec = par_times[idx] * 60.0
	par_time_str = par_strs[idx]
	
	if final_time_taken < par_sec and par_sec > 0:
		time_bonus_total = int(par_sec - final_time_taken) * 500

func _create_ui() -> void:
	var win_w = get_viewport().get_visible_rect().size.x
	var win_h = get_viewport().get_visible_rect().size.y
	
	var bg = ColorRect.new()
	bg.color = Color(0.0, 65.0/255.0, 65.0/255.0, 1.0)
	bg.size = Vector2(win_w, 160 * scale_factor)
	add_child(bg)
	
	bj_sprite = TextureRect.new()
	bj_sprite.texture = bj_textures[0]
	bj_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bj_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	bj_sprite.position = Vector2(0, 16 * scale_factor)
	bj_sprite.size = Vector2(bj_textures[0].get_width() * scale_factor, bj_textures[0].get_height() * scale_factor)
	add_child(bj_sprite)
	
	text_container = Control.new()
	add_child(text_container)
	
	_write(14, 2, "FLOOR")
	_write(14, 4, "COMPLETED")
	_write(26, 2, str(floor_num))
	_write(14, 7, "BONUS")
	_write(16, 10, "TIME")
	var m = int(final_time_taken) / 60
	var s = int(final_time_taken) % 60
	_write(26, 10, "%02d:%02d" % [m, s])
	_write(16, 12, "PAR")
	_write(26, 12, par_time_str)
	_write(9, 14, "KILL RATIO")
	_write(5, 16, "SECRET RATIO")
	_write(1, 18, "TREASURE RATIO")
	
	label_bonus = _create_align_group(36, 7)
	label_kill = _create_align_group(37, 14)
	label_secret = _create_align_group(37, 16)
	label_treasure = _create_align_group(37, 18)
	
	statusbar_rect = TextureRect.new()
	statusbar_rect.texture = statusbar_texture
	statusbar_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	statusbar_rect.stretch_mode = TextureRect.STRETCH_SCALE
	statusbar_rect.size = Vector2(win_w, 40 * scale_factor)
	statusbar_rect.position = Vector2(0, 160 * scale_factor)
	add_child(statusbar_rect)
	
	hud_score_digits = _create_hud_digits(POS_SCORE_X, 6)
	hud_level_digits = _create_hud_digits(POS_LEVEL_X, 2)
	hud_lives_digit = _create_hud_digits(POS_LIVES_X, 1)[0]
	hud_health_digits = _create_hud_digits(POS_HEALTH_X, 3)
	hud_ammo_digits = _create_hud_digits(POS_AMMO_X, 2)
	
	hud_face = TextureRect.new()
	hud_face.texture = face_textures[0]
	hud_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud_face.stretch_mode = TextureRect.STRETCH_SCALE
	hud_face.position = Vector2(POS_FACE_X * scale_factor, 4 * scale_factor)
	hud_face.size = Vector2(24 * scale_factor, 32 * scale_factor)
	statusbar_rect.add_child(hud_face)
	
	hud_weapon = TextureRect.new()
	hud_weapon.texture = weapon_textures[clampi(GameState.weapon, 0, 3)]
	hud_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud_weapon.stretch_mode = TextureRect.STRETCH_SCALE
	hud_weapon.position = Vector2(256 * scale_factor, 4 * scale_factor)
	hud_weapon.size = Vector2(48 * scale_factor, 24 * scale_factor)
	statusbar_rect.add_child(hud_weapon)
	
	_update_summary()
	_update_hud()

func _create_hud_digits(gx: int, count: int) -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	for i in range(count):
		var tr = TextureRect.new()
		tr.texture = hud_digit_textures[0] # Blank
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2((gx + i * 8) * scale_factor, POS_NUMBER_Y * scale_factor)
		tr.size = Vector2(8 * scale_factor, 16 * scale_factor)
		statusbar_rect.add_child(tr)
		result.append(tr)
	return result

func _create_align_group(gx: int, gy: int) -> Node2D:
	var node = Node2D.new()
	node.position = Vector2(gx * 8 * scale_factor, gy * 8 * scale_factor)
	text_container.add_child(node)
	return node

func _update_summary() -> void:
	_set_aligned_text(label_bonus, str(display_bonus))
	_set_aligned_text(label_kill, str(display_kill) + "%")
	_set_aligned_text(label_secret, str(display_secret) + "%")
	_set_aligned_text(label_treasure, str(display_treasure) + "%")

func _set_aligned_text(container: Node2D, text: String) -> void:
	for child in container.get_children():
		child.queue_free()
	
	var length = 0
	for ch in text:
		length += 8 if ch == ":" else 16
	
	var cx = -length * scale_factor
	for ch in text.to_upper():
		if ch == " ":
			cx += 16 * scale_factor
		else:
			var tex = char_pics.get(ch)
			if tex:
				var tr = TextureRect.new()
				tr.texture = tex
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.position = Vector2(cx, 0)
				tr.size = Vector2(tex.get_width() * scale_factor, tex.get_height() * scale_factor)
				container.add_child(tr)
			cx += (8 if ch == ":" else 16) * scale_factor

func _update_hud() -> void:
	_latch_hud(hud_score_digits, 6, GameState.score)
	_latch_hud(hud_level_digits, 2, GameState.current_map + 1)
	_latch_hud([hud_lives_digit], 1, max(GameState.lives, 0))
	_latch_hud(hud_health_digits, 3, GameState.health)
	_latch_hud(hud_ammo_digits, 2, GameState.ammo)

func _latch_hud(digits: Array[TextureRect], width: int, number: int) -> void:
	var s = str(number)
	var l = s.length()
	var idx = 0
	while idx < width - l:
		digits[idx].texture = hud_digit_textures[0]
		idx += 1
	var si = 0
	while idx < width:
		var v = s[si].unicode_at(0) - 48
		digits[idx].texture = hud_digit_textures[v + 1]
		idx += 1
		si += 1

func _process(delta: float) -> void:
	bj_timer += delta
	if bj_timer >= 0.5:
		bj_timer = 0.0
		bj_frame = (bj_frame + 1) % bj_textures.size()
		bj_sprite.texture = bj_textures[bj_frame]
	
	if current_phase == Phase.DONE: return
	
	count_timer += delta
	if count_timer < 0.02: return
	count_timer = 0.0
	
	match current_phase:
		Phase.TIME_BONUS:
			if display_bonus < time_bonus_total:
				display_bonus = min(display_bonus + 500, time_bonus_total)
				if display_bonus % 1000 == 0: SoundManager.play_sfx("ENDBONUS1SND")
				_update_summary()
			else:
				SoundManager.play_sfx("ENDBONUS2SND")
				current_phase = Phase.KILL_RATIO
		Phase.KILL_RATIO:
			if display_kill < final_kill_ratio:
				display_kill += 1
				if display_kill % 10 == 0: SoundManager.play_sfx("ENDBONUS1SND")
				_update_summary()
			else:
				_phase_complete(final_kill_ratio, Phase.SECRET_RATIO)
		Phase.SECRET_RATIO:
			if display_secret < final_secret_ratio:
				display_secret += 1
				if display_secret % 10 == 0: SoundManager.play_sfx("ENDBONUS1SND")
				_update_summary()
			else:
				_phase_complete(final_secret_ratio, Phase.TREASURE_RATIO)
		Phase.TREASURE_RATIO:
			if display_treasure < final_treasure_ratio:
				display_treasure += 1
				if display_treasure % 10 == 0: SoundManager.play_sfx("ENDBONUS1SND")
				_update_summary()
			else:
				_phase_complete(final_treasure_ratio, Phase.DONE)
				_finish()

func _phase_complete(ratio: int, next: Phase) -> void:
	if ratio == 100: SoundManager.play_sfx("PERCENT100SND")
	elif ratio == 0: SoundManager.play_sfx("NOITEMSND")
	else: SoundManager.play_sfx("ENDBONUS2SND")
	current_phase = next

func _finish() -> void:
	var total = time_bonus_total
	if final_kill_ratio == 100: total += 10000
	if final_secret_ratio == 100: total += 10000
	if final_treasure_ratio == 100: total += 10000
	GameState.give_points(total)
	_update_hud()

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		if current_phase != Phase.DONE:
			_skip()
		else:
			_proceed()

func _skip() -> void:
	display_bonus = time_bonus_total
	display_kill = final_kill_ratio
	display_secret = final_secret_ratio
	display_treasure = final_treasure_ratio
	_update_summary()
	_finish()

func _proceed() -> void:
	GameState.current_map += 1
	var next = _get_next_path()
	if next != "":
		GameState.selected_map_path = next
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://main.tscn")
	queue_free()

func _get_next_path() -> String:
	var p = "user://assets/%s/maps/json/" % GameState.selected_game
	var d = DirAccess.open(p)
	if not d: return ""
	var fs: Array[String] = []
	d.list_dir_begin()
	var f = d.get_next()
	while f != "":
		if f.ends_with(".json"): fs.append(f)
		f = d.get_next()
	d.list_dir_end()
	fs.sort()
	if GameState.current_map < fs.size(): return p + fs[GameState.current_map]
	return ""

func _write(gx: int, gy: int, text: String) -> void:
	var px = gx * 8 * scale_factor
	var py = gy * 8 * scale_factor
	var cx = px
	for ch in text.to_upper():
		if ch == " ": cx += 16 * scale_factor
		else:
			var tex = char_pics.get(ch)
			if tex:
				var tr = TextureRect.new()
				tr.texture = tex
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.position = Vector2(cx, py)
				tr.size = Vector2(tex.get_width() * scale_factor, tex.get_height() * scale_factor)
				text_container.add_child(tr)
			cx += (8 if ch == ":" else 16) * scale_factor

func _load_pic(f: String) -> Texture2D:
	var p = pics_path + f
	var i = Image.load_from_file(p)
	if i: return ImageTexture.create_from_image(i)
	push_error("LevelComplete: Failed to load " + p)
	return null
