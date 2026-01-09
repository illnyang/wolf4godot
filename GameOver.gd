# GameOver.gd
# Wolf3D Game Over Screen with score display
extends CanvasLayer

var score_label: Label
var message_label: Label
var instruction_label: Label

func _ready() -> void:
	# Create dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.1, 0, 0, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	# Create container for text
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 30)
	add_child(container)
	
	# GAME OVER text
	message_label = Label.new()
	message_label.text = "GAME OVER"
	message_label.add_theme_font_size_override("font_size", 64)
	message_label.add_theme_color_override("font_color", Color.RED)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(message_label)
	
	# Score display
	score_label = Label.new()
	score_label.text = "FINAL SCORE: %d" % GameState.score
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color.YELLOW)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(score_label)
	
	# Level reached
	var level_label = Label.new()
	level_label.text = "Level Reached: %d" % (GameState.current_map + 1)
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(level_label)
	
	# Instruction
	instruction_label = Label.new()
	instruction_label.text = "Press any key to continue..."
	instruction_label.add_theme_font_size_override("font_size", 18)
	instruction_label.add_theme_color_override("font_color", Color.GRAY)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(instruction_label)
	
	# Center the container
	container.position = get_viewport().get_visible_rect().size / 2
	container.position.x -= 200
	container.position.y -= 100
	
	# Play game over sound
	SoundManager.play_sound(SoundManager.SoundID.GAMEOVERSND)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			# Reset game state and go to main menu
			GameState.start_new_game()
			get_tree().change_scene_to_file("res://main.tscn")
			queue_free()
