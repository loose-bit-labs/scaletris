extends AudioStreamPlayer3D

var clips = [
	"res://audio/music/whip-110235.mp3"
]
var index : int = 33

func _ready():
	pass
	#_play_next()

func  _process(_delta):
	# TODO: these two bits of info are enough to fade in / out on track start...
	#print("ap: ", self.get_playback_position(), " vs ", self.stream.get_length())
	pass

func _play_next():
	if index >= clips.size():
		index = 0
		clips.shuffle()
	self.stream = load( clips[index])
	index = index + 1 
	play()

func _on_finished():
	#_play_next()
	play()
