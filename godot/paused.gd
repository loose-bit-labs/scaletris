extends CSGBox3D

@onready var arena =  $"../.."
@onready var mutedBox = $LabelMuted/MutedBox
@onready var unmutedBox = $LabelMuted/UnmutedBox

func _input(event):
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		toggle()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("mute"):
		if arena.toggle_mute():
			mutedBox.show()
			unmutedBox.hide()
		else:
			mutedBox.hide()
			unmutedBox.show()

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
