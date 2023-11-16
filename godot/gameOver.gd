extends CSGBox3D

var interactable = false

func _input(event):
	if interactable and (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		get_tree().change_scene_to_file("res://welcome.tscn")
		self.hide()

func _on_visibility_changed():
	if is_visible():
		await get_tree().create_timer(2.0).timeout 
		interactable = true
