extends CanvasLayer

var damage_flash: ColorRect
var death_overlay: ColorRect

var is_dying: bool = false
var death_sequence_time: float = 0.0
const DEATH_DURATION: float = 2.5  

var player_camera: Camera3D = null
var original_rotation: float = 0.0
var target_rotation: float = 0.0
var pan_complete: bool = false

func _ready() -> void:
	damage_flash = ColorRect.new()
	damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)  
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(damage_flash)
	
	death_overlay = ColorRect.new()
	death_overlay.color = Color(1.0, 0.0, 0.0, 0.0) 
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(death_overlay)
	
	GameState.damage_taken.connect(_on_damage_taken)
	GameState.player_died.connect(_on_player_died)

func _on_damage_taken(_amount: int) -> void:
	if not is_dying:
		flash_damage()

func flash_damage() -> void:
	var tween = create_tween()
	damage_flash.color.a = 0.4
	tween.tween_property(damage_flash, "color:a", 0.0, 0.15)

func _on_player_died() -> void:
	if is_dying:
		return
	
	is_dying = true
	death_sequence_time = 0.0
	pan_complete = false
	
	SoundManager.play_player_death()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_camera = player.get_node_or_null("Camera3D")
		if player_camera:
			original_rotation = player_camera.global_rotation.y
			
			# Calculate rotation to face killer
			var attacker = GameState.last_attacker
			if attacker and is_instance_valid(attacker):
				var dir_to_killer = attacker.global_position - player.global_position
				dir_to_killer.y = 0
				if dir_to_killer.length() > 0.1:
					target_rotation = atan2(-dir_to_killer.x, -dir_to_killer.z)
				else:
					target_rotation = original_rotation
			else:
				target_rotation = original_rotation
	
	_freeze_all_actors()

func _freeze_all_actors() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)

func _process(delta: float) -> void:
	if not is_dying:
		return
	
	death_sequence_time += delta
	var progress = death_sequence_time / DEATH_DURATION
	
	# Phase 1 (0-60%): Camera pan to killer
	if progress < 0.6 and player_camera and not pan_complete:
		var pan_progress = progress / 0.6
		pan_progress = ease(pan_progress, 0.5)  

		var rot_diff = target_rotation - original_rotation
		while rot_diff > PI:
			rot_diff -= TAU
		while rot_diff < -PI:
			rot_diff += TAU
		
		player_camera.global_rotation.y = original_rotation + rot_diff * pan_progress
	elif progress >= 0.6:
		pan_complete = true
	
	# Phase 2 (40-100%): Red overlay fade in
	if progress > 0.4:
		var red_progress = (progress - 0.4) / 0.6
		red_progress = min(red_progress, 1.0)
		death_overlay.color.a = red_progress * 0.8
	
	# Death sequence complete - restart level or show game over
	if progress >= 1.0:
		is_dying = false
		death_overlay.color.a = 0.0
		
		if GameState.lives >= 0:
			GameState.reset_for_respawn()
			get_tree().reload_current_scene()
		else:
			_show_game_over()

func _show_game_over() -> void:
	death_overlay.color.a = 0.0
	
	var game_over_script = preload("res://GameOver.gd")
	var game_over = CanvasLayer.new()
	game_over.set_script(game_over_script)
	get_tree().root.add_child(game_over)
