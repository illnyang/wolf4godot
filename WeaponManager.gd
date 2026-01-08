extends AnimatedSprite2D

@export var sprite_texture_folder: String = "user://assets/wolf3d/sprites/"
@export var weapon_scale: float = 10.0 # Make it 10x bigger

# Mapping the start ID for each weapon (5 frames each)
const WEAPON_MAP = {
	"knife": 414,      
	"pistol": 419,     
	"machinegun": 424, 
	"chaingun": 429    
}

func load_external_weapon_animations():
	# --- SCALING & FILTERING ---
	# 1. Apply Nearest Neighbor filtering for sharp pixels
	self.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# 2. Set the 10x scale
	self.scale = Vector2(weapon_scale, weapon_scale)
	
	# 3. Basic Positioning
	self.centered = true
	# ---------------------------

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

func play_shoot(weapon_prefix: String):
	self.stop()
	if self.sprite_frames.has_animation(weapon_prefix + "_shoot"):
		self.play(weapon_prefix + "_shoot")

func play_idle(weapon_prefix: String):
	if self.sprite_frames.has_animation(weapon_prefix + "_idle"):
		self.play(weapon_prefix + "_idle")
