extends CSGBox3D

var interactable = false

func _input(event):
	if interactable and (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		print("changing...")
		self.hide()
		get_tree().change_scene_to_file("res://welcome.tscn")
		print("changed")

func _on_visibility_changed():
	if is_visible():
		await get_tree().create_timer(3.3).timeout 
		interactable = true
		#print("you can go on")
		get_tree().paused = false
