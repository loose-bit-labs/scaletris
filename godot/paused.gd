extends CSGBox3D

const welcome_scene = "res://welcome.tscn"

@onready var arena =  $"../.."
@onready var mutedBox = $LabelMuted/MutedBox
@onready var unmutedBox = $LabelMuted/UnmutedBox

var full

func _input(event):
	if _is_go(event):
		toggle()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("mute"):
		if arena.toggle_mute():
			mutedBox.show()
			unmutedBox.hide()
		else:
			mutedBox.hide()
			unmutedBox.show()
	if event.is_action_pressed("fullscreen"):
		if DisplayServer.WINDOW_MODE_FULLSCREEN == DisplayServer.window_get_mode():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("quit"):
		#TODO: prompt
		get_tree().quit()
	if event.is_action_pressed("home"):
		#TODO: prompt
		unpause()
		get_tree().change_scene_to_file(welcome_scene)

func _is_go(event):
	for key in ["pause", "ui_cancel", "help"]:
		if event.is_action_pressed(key):
			return true
	if is_visible_in_tree():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
			return true
	return false

func pause():
	get_tree().paused = true
	show()

func unpause():
	get_tree().paused = false
	hide()

func toggle():
	if get_tree().paused:
		unpause()
	else:
		pause()
