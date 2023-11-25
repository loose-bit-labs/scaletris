extends CSGBox3D

const welcome_scene = "res://welcome.tscn"

@onready var arena =  $"../.."
@onready var mutedBox = $LabelMuted/MutedBox
@onready var unmutedBox = $LabelMuted/UnmutedBox

func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("help"):
		toggle()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("mute"):
		if arena.toggle_mute():
			mutedBox.show()
			unmutedBox.hide()
		else:
			mutedBox.hide()
			unmutedBox.show()
	if event.is_action_pressed("quit"):
		#TODO: prompt
		get_tree().quit()
	if event.is_action_pressed("home"):
		#TODO: prompt
		unpause()
		get_tree().change_scene_to_file(welcome_scene)

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
