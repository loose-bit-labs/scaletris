extends RigidBody3D

# TODO: refactor this into welcome.gd

@onready var welcome =  $"../.."
@onready var player = $AnimationPlayer

var shrinking = false
@onready var particles = $"../GPUParticles3D"

func _on_body_entered(_body):
	if shrinking:
		return
	shrinking = true
	player.play("right_on_hit")

func _on_left_box_body_entered(_body):
	if not shrinking:
		#print("left hit ", shrinking)
		player.play("left_on_hit")

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"right_on_hit": _start_particles()
		"particle_hack": _stop_particles()

func _start_particles():
	#print("start particles")
	particles.restart() 
	particles.emitting = true
	player.play("particle_hack")

func _stop_particles():
	#print("stop particles")
	welcome.reset()
	shrinking = false
	particles.emitting = false
