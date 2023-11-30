extends CSGBox3D

const welcome_scene = "res://welcome.tscn"

@onready var arena =  $"../.."
@onready var mutedBox = $LabelMuted/MutedBox
@onready var unmutedBox = $LabelMuted/UnmutedBox
@onready var quitting = $Quitting
@onready var others = [$NormalExplanation, $BonusExplanation, $LevelledExplanation]
@onready var was_visible = [$NormalExplanation, $BonusExplanation, $LevelledExplanation]

var full
var quit_count = 0

func _input(event):
	if event.is_action_pressed("quit"):
		_quit()
	if _is_go(event):
		_no_quit()
		toggle()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("mute"):
		_no_quit()
		if Fof.toggle_mute():
			mutedBox.show()
			unmutedBox.hide()
		else:
			mutedBox.hide()
			unmutedBox.show()
	if event.is_action_pressed("fullscreen"):
		_no_quit()
		if DisplayServer.WINDOW_MODE_FULLSCREEN == DisplayServer.window_get_mode():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	if event.is_action_pressed("home"):
		_no_quit()
		#TODO: prompt
		unpause()
		get_tree().change_scene_to_file(welcome_scene)

func _quit():
	quit_count = quit_count + 1
	if 1 == quit_count:
		quitting.show()
		var i = 0
		for other in others:
			was_visible[i] = other.is_visible_in_tree()
			if was_visible[i]:
				print(other, " was visible")
			i = i + 1
			other.hide()
		pause()
	else:
		if 2 == quit_count:
			get_tree().quit()
	return

func _no_quit():
	quitting.hide()
	# FIXME: this logic is bugged.. there is a hack around in main._on_paused_visibility_changed
	if 1 == quit_count:
		var i = 0
		for other in others:
			if was_visible[i]:
				other.show()
			i = i + 1
	quit_count = 0

func _is_go(event):
	for key in ["pause", "ui_cancel", "help"]:
		if event.is_action_pressed(key):
			return true
	if is_visible_in_tree():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or event.is_action_pressed("space"):
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
