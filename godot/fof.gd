extends Node

# Friend of Foe?
# this class takes care of
# 1. managing textures
# 2. defining friend or foe
# 3. results of match / mismatch

const GAME_CLASSIC = "res://data/classic.json"
const GAME_QUEST = "res://data/quest.json"

@export var WORLD_FILE = GAME_QUEST

const NAME = "name"
const MATERIAL = "material"
const IMAGE = "image"
const MATERIAL_COPY = "material_copy"
const TYPE = "type"
const FOF = "fof"
const BESTIARY = "bestiary"
const CHANCE = "chance"
const LEVEL = "level"
const LEVELS = "levels"
const PICKER = "picker"
const MUSIC = "music"
const BOSS = "boss"
const FRIENDS = "friends"
const FOES = "foes"
const SCALE = "scale"
const MINIMUM = "minimum"
const MAXIMUM = "maximum"
const GAME = "game"
const BONUS = "bonus"
const ITEM = "item"
const COUNT = "count"
const GAP = "gap"
const BONUS_LEVEL = "bonusLevel"
const LOOT = "loot"
const BLOCK = "Block"
const ENTITY = "entity"
const REQUIRED = "required"
const TILES = "tiles"
const VALUE = "value"
const SIZES = "sizes"
const LIVES = "lives"
const TIMER = "timer"
const INFO = "info"
const SPEED = "speed"
const EXPLANATION = "explanation"
const DEATH_BONUS = "death_bonus"
const LEVEL_OVERRIDE = "level_override"
const GLOW = "glow"

const TILE_DEFAULT = "classic"
const IMAGE_ROOT = "res://images/"
const IMAGE_EXTENSION = ".png"
const BG_ROOT = "res://images/bg/"
const DEFAULT_BONUS_TIMER = 90

var DEFAULT_GAME_SETTINGS = {
	"tiles": TILE_DEFAULT,
	"explanation": "",
	"glow": false,
	"level_override": false,
	"death_bonus": false,
	"lives": 0,
	"life": "",
	"bonus": "",
	"info": ""
}

var DEFAULT_BONUS_SETTINGS = {
	"count": 5,
	"required": 3,
	"chance": 0.2,
	"gap":3.3 # usefulGapRange is from 4.24 to 0.64, 7 is no gap
}
#################################################################################################

var world
var bestiary
var loaded = ""
var muted = false

#################################################################################################

func _init():
	load_world()

##########################################################

func load_world(filename:String = WORLD_FILE, callback:Callable = func():return):
	if loaded == filename:
		callback.call()
		return
	world = _unspace(JSON.parse_string(FileAccess.open(filename, FileAccess.READ).get_as_text()))
	if GAME in world:
		for key in DEFAULT_GAME_SETTINGS:
			if not key in world.game:
				world.game[key] = DEFAULT_GAME_SETTINGS[key]
				print("SET WORLD.", key, " to ", DEFAULT_GAME_SETTINGS[key])
	else:
		world[GAME] = DEFAULT_GAME_SETTINGS.duplicate()
	if BESTIARY in world:
		bestiary = _load_bestiary(world[BESTIARY])
	else:
		print("WARN: starting with an empty bestiary")
		bestiary = {}
		world[BESTIARY] = bestiary
	world[LEVELS] = _load_levels(world[LEVELS])
	loaded = filename
	callback.call()

func game_name():
	var l = Fof.loaded
	var a = l.rfind("/") + 1
	var b = l.rfind(".")
	return l.substr(a, b - a)

func _get_tiles():
	return TILE_DEFAULT if not GAME in world or not TILES in world.game else world.game.tiles

func _load_bestiary(b):
	var lookup = {}
	var tiles = _get_tiles()
	for type in b:
		var entities = b[type]
		for name_ in entities:
			_load_beastie(name_, type, lookup, b, entities[name_])
			if true:
				continue
			var image_resource = IMAGE_ROOT + tiles + "/" + name_ + IMAGE_EXTENSION
			var entity = entities[name_]
			entity[NAME] = name_
			entity[IMAGE] = load(image_resource)
			entity[TYPE] = type
			entity[MATERIAL] = image_to_material(entity[IMAGE], type)
			entity[MATERIAL_COPY] = image_to_material(entity[IMAGE])
			lookup[name_] = entity # TODO: check collisions
			if not LEVEL in entity:
				entity.level = 0
	return lookup

func _load_beastie(name_:String, type:String = FOES, lookup:Dictionary = {}, b:Dictionary = {}, entity:Dictionary = {}):
	var image_resource = IMAGE_ROOT + _get_tiles() + "/" + name_ + IMAGE_EXTENSION
	if not ResourceLoader.exists(image_resource):
		print("ERROR: missing resource for ", image_resource )
		return
	entity[NAME] = name_
	entity[IMAGE] = load(image_resource)
	entity[TYPE] = type
	entity[MATERIAL] = image_to_material(entity[IMAGE], type)
	entity[MATERIAL_COPY] = image_to_material(entity[IMAGE])
	if not LEVEL in entity:
		entity.level = 0
	lookup[name_] = entity
	if not type in b:
		b[type] = {}
	b[type][name_] = entity

# TODO: load the "name" of level for the fx
func _load_levels(levels):
	var loaded_levels = []
	var count = levels.size()
	for index in range(count):
		var level = levels[index]
		_level_slackness(level)
		level[PICKER] = _entity_probability(level.chance)
		level[IMAGE] = load_background(level[NAME]) 
		level[MATERIAL] = image_to_material(level[IMAGE], LEVELS)
		level[MUSIC] = load("res://audio/music/"+level[MUSIC])
		loaded_levels.append(level)
		if BONUS in level and  (index == count - 1 or not BONUS_LEVEL in levels[1+index]):
			var bonus = level.duplicate()
			bonus[BONUS_LEVEL] = {"timer":DEFAULT_BONUS_TIMER}
			bonus[SPEED] = 2 * level.speed
			loaded_levels.append(bonus)
	return loaded_levels

func _level_slackness(level):
	if not CHANCE in level:
		# TODO: make sure is bonus level!
		level.chance = {}
	var has_a_chance = {}
	for entity_name in level.chance:
		var weight = level.chance[entity_name]
		if 0 < weight:
			has_a_chance[entity_name] = weight
	level.chance = has_a_chance
	if BONUS in level:
		for field in DEFAULT_BONUS_SETTINGS:
			if not field in level.bonus:
				level.bonus[field] = DEFAULT_BONUS_SETTINGS[field]
		if not level.bonus.item in bestiary:
			#print("SLACK: load bonus ", level.bonus.item)
			_load_beastie(level.bonus.item, LOOT, bestiary)
			bestiary[level.bonus.item][VALUE] = 10
	for name_ in level.chance:
		if not name_ in bestiary:
			#print("SLACK: load beastie ", name_)
			_load_beastie(name_, FOES, bestiary)

func clamp_level_index(level_index:int = 0):
	return clamp(level_index, 0, world[LEVELS].size() - 1)

func get_level(level_index:int = 0):
	return world[LEVELS][clamp_level_index(level_index)]

func get_scale(level_index:int = 0):
	for src in [get_level(level_index), world[GAME]]:
		if SCALE in src:
			return src[SCALE]
	return {}

func can_earn_bonus(level):
	return BONUS in level

func get_bonus(level_index:int = 0):
	var level = get_level(level_index)
	return null if not can_earn_bonus(level) else level[BONUS]

func get_gap(level_index:int = 0):
	var bonus = get_bonus(level_index)
	return 7 if (!bonus or not GAP in bonus) else bonus[GAP]

func game_lives():
	return world.game.lives

func game_level_override():
	return world.game.level_override

func game_glow():
	return world.game.glow

func game_tiles():
	return world.game.tiles

func game_bonus():
	return world.game.bonus
	
func game_info():
	return world.game.info

func game_explanation():
	return world.game.explanation

func game_life():
	return world.game.life

func is_bonus_level(level):
	return Fof.BONUS_LEVEL in level

func game_has_death_bonus():
	return DEATH_BONUS in Fof.world.game and Fof.world.game.death_bonus

func has_death_bonus(level):
	return can_earn_bonus(level) and not is_bonus_level(level) and game_has_death_bonus()

func entity_for_level(level_index:int, block_map = {}, i_can_has_bonus:bool = true, matched = {}, sweeter:float = 0):
	if i_can_has_bonus:
		var bonus = bonus_item_for_level(level_index, block_map, sweeter)
		if bonus:
			return bonus
	var thou_shalt_not = _forbidden_entities(block_map, matched)
	var chance = get_level(level_index)[CHANCE]
	var picker = _entity_probability(chance, thou_shalt_not)
	if !picker.size():
		return null
	var r = randf()
	var entity_name = null
	for entry in picker:
		if entry[1] >= r:
			entity_name = entry[0]
			break
	if !entity_name:
		entity_name = picker[picker.size()-1][0]
	var entity = entity_by_name(entity_name, level_index)
	if !entity:
		print("ERROR: entity_for_level for ", entity_name, " from ", picker )
	return entity

func bonus_item_for_level(level_index:int, block_map = {}, sweeter:float = 0):
	var bonus = get_bonus(level_index)
	if not bonus:
		return null
	var bonus_count = 0 if not BONUS in block_map else block_map[BONUS].size()
	var bonus_max = 5 if not COUNT in bonus else bonus[COUNT]
	if bonus_count >= bonus_max:
		return null
	var bonus_chance = bonus.chance - bonus_count * .01 + sweeter
	var r = randf()
	print("BBBBBONUS! ", bonus_chance, " < ", r, " BC ", bonus.chance, " - ", bonus_count)
	if r < bonus_chance:
		var bonus_item = entity_by_name(bonus.item, level_index).duplicate()
		bonus_item.type = BONUS # anything can be used as a bonus item...
		return bonus_item

func entity_by_name(entity_name:String, level_index:int = -1):
	if not entity_name in bestiary:
		print("ERROR: no beasty matches ", entity_name)
		return null
	var entity = bestiary[entity_name].duplicate()
	if (world.game.level_override or !entity.level) and level_index >= 0:
		var level = get_level(level_index)
		if level and SIZES in level:
			entity.level = level.sizes - 1
		else:
			entity.level = level_index + 2
	return entity

##########################################################

func _forbidden_entities(block_map:Dictionary, matched = {}):
	var no_go = matched
	for entity_name in block_map:
		var size = block_map[entity_name].size()
		if size >= 2:
			no_go[entity_name] = true
			if size > 2:
				print("BUG: ", size, " x ", entity_name)
	return no_go

func load_background(bg_name):
	return load(BG_ROOT+bg_name+IMAGE_EXTENSION)

func load_background_material(bg_name):
	return image_to_material(load_background(bg_name))

func _image_resource_to_material(image_resource:String, type:String=""):
	return image_to_material(load(image_resource), type)

func image_to_material(image, type:String=""):
	if false:
		var txt = ImageTexture.create_from_image(image.get_image())
		print("hi, ", txt)
		var img = image.get_image()
		img.decompress()
		# = txt
		#img.unlock()
		for x in range(0,image.get_width()):
			img.set_pixel(x,0,Color.BLACK)
			img.set_pixel(x,1,Color.BLACK)
			img.set_pixel(x,2,Color.BLACK)
		#img.lock()
		#img.compress(5)
	var material = StandardMaterial3D.new()
	material.uv1_scale.x = -1
	material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO, image)
	if world.game.glow:
		var c = 33
		var o = 0
		var i = .01
		var a = .01
		match type:
			FRIENDS: glow(material, Color(o,c,o,a), i)
			FOES:    glow(material, Color(c,o,o,a), i)
			LOOT:    glow(material, Color(c,c,o,a), i) 
	return material

func glow(material:StandardMaterial3D, color:Color, intensity:float):
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = intensity
	material.emission_intensity = intensity
	return material

func camera_mouse(context:Node3D, camera:Camera3D, exclude = [], rayLength:float=1000):
	var space_state = context.get_world_3d().direct_space_state
	var mousepos = context.get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mousepos)
	var end = origin + camera.project_ray_normal(mousepos) * rayLength
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.exclude = exclude

	var result = space_state.intersect_ray(query)
	if !result or not "collider" in result: 
		return null
	return result.collider

# rather than have 10 keys with the same value in the json,
# you can just separate them with spaces: {"a b c":1} -> {a:1,b:1,c:1}
func _unspace(node, path="/"):
	var debug = false
	if debug :
		var ww = "idk"
		if node is Dictionary:
			ww = "dict"
		if node is Array:
			ww = "array"
		print("HI ", path, "! I see you are a ", ww)
	if node is Dictionary:
		var nu = {}
		for k in node:
			var v = _unspace(node[k], path + "/" +k )
			if k.contains(" "):
				if debug:
					print("OH! ", path, "! You also have spaces in '", k, "'! let's split that up!!!")
				for subk in k.strip_edges(true, true).split(" "):
					if(debug):
						print(">>, ", path, " SAVE ", subk, " with ", v )
					nu[subk] = v
			else:
				nu[k] = v
		node = nu
	if node is Array:
		for i in range(0,node.size()):
			#print("hi there, butthole! ", i, " is ", node[i])
			node[i] = _unspace(node[i], path + "[" + str(i) + "]")
	return node

##########################################################

# input: map from entity_name to weight
# return: sorted array where each element is an array containing
#         the entity_name and scaled probability in increasing 
#         cumulative likeliness
#         eg:  {bat:1,squirrel:1} -> [ [bat,.5], [squirrel,.1]]
#         eg:  {bat:2,squirrel:1} -> [ [squirrel,.33], [bat, 1]]
#         then a number from [0:1] should iteratively pick based
#         on the distribution
func _entity_probability(chance:Dictionary, forbidden:Dictionary={}):
	var probably = []
	var sum = 0
	for entity_name in chance:
		if entity_name in forbidden:
			continue
		var weight = chance[entity_name]
		probably.append([entity_name,weight])
		sum = sum + weight
	if 0 == sum:
		return {}
	probably = probably.map(func(e): return _ep_weak_sauce(e,sum))
	probably.sort_custom(func(a,b): return a[1]<b[1])
	var so_far = 0
	for p in probably:
		var v = p[1]
		p[1] += so_far
		so_far += v
	return probably

func _ep_weak_sauce(e,sum):
	e[1] /= sum
	return e
