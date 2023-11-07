extends AudioStreamPlayer3D

@onready var  tonk = load("res://audio/fx/tonk.mp3")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func play_tonk():
	self.stream = tonk
	self.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
