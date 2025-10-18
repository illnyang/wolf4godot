extends Control
var phase = 0

func _ready():
	# EXTRACT ASSETS FIRST
	print("Checking assets...")
	await $AssetExtractor.extraction_finished
	print("Assets ready!")
	
	# NOW show the menu
	$StartScreen.visible = true
	$MainMenu.visible = false
	$MusicPlayer.play()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if phase == 0:
			$StartScreen.visible = false
			$MainMenu.visible = true
			phase += 1
		elif phase == 1:
			start_game()

func start_game():
	$MusicPlayer.stop()
	get_tree().change_scene_to_file("res://Wolf.tscn")
