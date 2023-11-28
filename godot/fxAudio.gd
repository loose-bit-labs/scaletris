extends AudioStreamPlayer3D

const DEFAULT_VOLUME = -22.22
const CLIP = "clip"
const VOLUME = "volume"

const BELL1 = "bell1"
const BELL2 = "bell2"
const BELL3 = "bell3"
const TONK = "tonk"
const CLASH = "clash"
const CLASH2 = "clash2"
const OUCH = "ouch"
const MISMATCH = "mismatch"

@export var muted = false

@onready var fx = {
	BELL1: {CLIP:load("res://audio/fx/COWBELL1.WAV"), },
	BELL2: {CLIP:load("res://audio/fx/1378_COWBELL2.mp3"), VOLUME:3.3}, 
	BELL3: {CLIP:load("res://audio/fx/79154_COWBELL.mp3")},
	TONK:  {CLIP:load("res://audio/fx/tonk.mp3")},
	CLASH: {CLIP:load("res://audio/fx/clash.mp3")},
	CLASH2: {CLIP:load("res://audio/fx/clash2.mp3"),VOLUME:13.31},
	OUCH: {CLIP:load("res://audio/fx/ouch.mp3"), VOLUME:13.31 },
	MISMATCH: {CLIP:load("res://audio/fx/253174__suntemple__retro-you-lose-sfx.mp3"), VOLUME:13.31 },
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func play_tonk():
	play_fx(TONK)

func play_fx(fx_name):
	if muted: 
		return
	var f = fx[fx_name]
	self.stream = f[CLIP]
	volume_db = DEFAULT_VOLUME if not VOLUME in f else f[VOLUME]
	self.play()
