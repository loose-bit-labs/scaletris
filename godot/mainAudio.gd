extends AudioStreamPlayer3D

@export var muted = false

func _on_finished():
	if !muted:
		play()

func set_mute(muted_:bool):
	muted = muted_
	if muted:
		stop()
	else:
		play()
