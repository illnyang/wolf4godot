extends AnimatedSprite2D
signal weapon_changed(weapon_name)

@export var sprite_texture_folder: String = "user://assets/wolf3d/sprites/"
@export var weapon_scale: float = 10.0 
@export var current_weapon: String = "knife" 

var unlocked_weapons: Array = ["knife", "pistol"]
const WEAPON_MAP = {
	"knife": 414,      
	"pistol": 419,     
	"machinegun": 424, 
	"chaingun": 429    
}

const ENUM_MAP = {
	"knife": GameState.Weapon.KNIFE,
	"pistol": GameState.Weapon.PISTOL,
	"machinegun": GameState.Weapon.MACHINEGUN,
	"chaingun": GameState.Weapon.CHAINGUN
}

const REV_ENUM_MAP = {
	GameState.Weapon.KNIFE: "knife",
	GameState.Weapon.PISTOL: "pistol",
	GameState.Weapon.MACHINEGUN: "machinegun",
	GameState.Weapon.CHAINGUN: "chaingun"
}

const INPUT_MAP = {
	"1": "knife",
	"2": "pistol",
	"3": "machinegun",
	"4": "chaingun"
}

func _ready() -> void:
	load_external_weapon_animations()
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	if GameState.has_signal("weapon_changed"):
		GameState.weapon_changed.connect(_on_gamestate_weapon_changed)
	_sync_to_gamestate()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		var key_text = OS.get_keycode_string(event.keycode)
		
		var weapon_key = ""
		if key_text == "1" or key_text == "Kp 1": weapon_key = "1"
		elif key_text == "2" or key_text == "Kp 2": weapon_key = "2"
		elif key_text == "3" or key_text == "Kp 3": weapon_key = "3"
		elif key_text == "4" or key_text == "Kp 4": weapon_key = "4"
		
		if INPUT_MAP.has(weapon_key):
			var weapon_to_switch = INPUT_MAP[weapon_key]
			if weapon_to_switch in unlocked_weapons:
				switch_weapon(weapon_to_switch)
			else:
				print("Broń locked: ", weapon_to_switch)

func _on_gamestate_weapon_changed(_new_weapon_enum) -> void:
	_sync_to_gamestate()

func _sync_to_gamestate() -> void:
	var weapon_enum = GameState.weapon
	if REV_ENUM_MAP.has(weapon_enum):
		var weapon_name = REV_ENUM_MAP[weapon_enum]
		if not weapon_name in unlocked_weapons:
			unlocked_weapons.append(weapon_name)
			
		if current_weapon != weapon_name:
			switch_weapon(weapon_name, true)

func load_external_weapon_animations():
	self.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	self.scale = Vector2(weapon_scale, weapon_scale)
	self.centered = true

	var sf = SpriteFrames.new()
	print("--- Starting Weapon Sprite Load ---")

	for w_name in WEAPON_MAP.keys():
		var start_id = WEAPON_MAP[w_name]
		var shoot_anim = w_name + "_shoot"
		var idle_anim = w_name + "_idle"
		
		sf.add_animation(shoot_anim)
		sf.add_animation(idle_anim)
		sf.set_animation_loop(shoot_anim, false)
		sf.set_animation_speed(shoot_anim, 15.0) 
		sf.set_animation_loop(idle_anim, true)
		sf.set_animation_speed(idle_anim, 1.0)
		
		for i in range(5):
			var current_id = start_id + i
			var file_path = sprite_texture_folder + "SPR_STAT_" + str(current_id) + ".png"
			
			if FileAccess.file_exists(file_path):
				var tex = _load_external_texture(file_path)
				if tex:
					sf.add_frame(shoot_anim, tex)
					if i == 0:
						sf.add_frame(idle_anim, tex)
			else:
				push_warning("WeaponManager Error: MISSING FILE at " + file_path)

	self.sprite_frames = sf
	print("--- Weapon Sprite Load Complete ---")

func _load_external_texture(path: String) -> ImageTexture:
	var img = Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null

func switch_weapon(weapon_name: String, from_sync: bool = false):
	if current_weapon == weapon_name and not from_sync:
		return

	if WEAPON_MAP.has(weapon_name):
		self.stop() 
		current_weapon = weapon_name
		if not from_sync:
			GameState.weapon = ENUM_MAP[weapon_name]
			if GameState.has_signal("weapon_changed"):
				GameState.weapon_changed.emit(GameState.weapon)
		
		play_idle(current_weapon)
		weapon_changed.emit(weapon_name)
		print("Weapon visual switched to: ", weapon_name)

func on_weapon_picked_up(weapon_name: String):
	if WEAPON_MAP.has(weapon_name):
		if not weapon_name in unlocked_weapons:
			unlocked_weapons.append(weapon_name)
		switch_weapon(weapon_name)

func play_shoot(weapon_prefix: String = current_weapon):
	self.stop()
	if self.sprite_frames.has_animation(weapon_prefix + "_shoot"):
		self.play(weapon_prefix + "_shoot")

func play_idle(weapon_prefix: String = current_weapon):
	if is_playing() and animation.ends_with("_shoot"):
		return
		
	var anim_name = weapon_prefix + "_idle"
	if self.sprite_frames.has_animation(anim_name):
		self.play(anim_name)

func _on_animation_finished() -> void:
	if animation.ends_with("_shoot"):
		play_idle(current_weapon)
