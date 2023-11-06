extends Node3D

@onready var collision : CollisionShape3D = $RigidBody3D/CollisionShape3D
@onready var body : RigidBody3D = $RigidBody3D
@onready var box : CSGBox3D = $RigidBody3D/CollisionShape3D/Box
var shape : BoxShape3D = null

var size = 1
#var current_scale : float = .8 #1.
var index = -1

const SCALE_MINIMUM = .8
const SCALE_MAXIMUM = 2

# Called when the node enters the scene tree for the first time.
func _ready():
	# don't share the collision shape!
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(.5,.5,.5)
	shape = collision.shape

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func configure(position_:Vector3, spin:Vector3, gravity:float, material:StandardMaterial3D):
	position = position_
	body.angular_velocity = spin
	body.gravity_scale = gravity
	box.set_material(material) 

func update_size(size_change:int, max_size:int):
	set_size(clamp(size + size_change, 0, max_size), max_size)
	
func set_size(size_:int, max_size:int):
	size = size_
	var scale_ = SCALE_MINIMUM + (SCALE_MAXIMUM - SCALE_MINIMUM) / max_size * size
	#print("size: ", size, " of ", max_size, " -> ", scale )
	body.mass = scale_
	# the box that collides
	shape.size.x = .5 * scale_
	shape.size.y = .5 * scale_
	# the box you see
	box.scale.x = scale_
	box.scale.y = scale_

func move(force):
	body.apply_central_force(force)
