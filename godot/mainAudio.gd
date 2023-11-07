extends AudioStreamPlayer3D

var clips = [
	"res://audio/music/song-tmp6kstc4yb.mp3", 
	"res://audio/music/song-tmpdpnknm55.mp3", 
	"res://audio/music/song-tmpf2sju_yo.mp3", 
	"res://audio/music/song-tmph_t2f50p.mp3", 
	"res://audio/music/song-tmpl9u3pz_7.mp3", 
	"res://audio/music/song-tmpoy_ch7d7.mp3"
]
var index : int = 33

func _ready():
	_play_next()

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
	_play_next()
