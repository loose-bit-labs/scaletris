extends Node

# Friend of Foe?
# this class takes care of
# 1. managing textures
# 2. defining friend or foe
# 3. results of match / mismatch

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

#################################################################################################

const IMAGE_ROOT = "res://images/mr-tiles/"
const IMAGE_EXTENSION = ".png"

const BG_ROOT = "res://images/bg/"

@export var WORLD_FILE = "res://data/world.json"
var world
var bestiary

#################################################################################################

func _init():
	_load_world()

##########################################################

func _load_world():
	world = _unspace(JSON.parse_string(FileAccess.open(WORLD_FILE, FileAccess.READ).get_as_text()))
	bestiary = _load_bestiary(world[BESTIARY])
	_load_levels(world[LEVELS])

func _load_bestiary(b):
	var lookup = {}
	for type in b:
		var entities = b[type]
		for name_ in entities:
			var entity = entities[name_]
			var image_resource = IMAGE_ROOT + name_ + IMAGE_EXTENSION
			entity[NAME] = name_
			entity[IMAGE] = load(image_resource)
			entity[TYPE] = type
			entity[MATERIAL] = _image_to_material(entity[IMAGE], type)
			entity[MATERIAL_COPY] = _image_to_material(entity[IMAGE])
			lookup[name_] = entity # TODO: check collisions
	return lookup

# TODO: load the "name" of level for the fx
func _load_levels(levels):
	for level in levels:
		var chance = level[CHANCE]
		level[PICKER] = _entity_probability(chance)
		level[IMAGE] = load(BG_ROOT+level[NAME]+IMAGE_EXTENSION)
		level[MATERIAL] = _image_to_material(level[IMAGE], LEVELS)
		level[MUSIC] = load("res://audio/music/"+level[MUSIC])

func clamp_level_index(level_index:int = 0):
	return clamp(level_index, 0, world[LEVELS].size() - 1)

func get_level(level_index:int = 0):
	return world[LEVELS][clamp_level_index(level_index)]

func get_scale(level_index:int = 0):
	for src in [get_level(level_index), world[GAME]]:
		if SCALE in src:
			return src[SCALE]
	return {}

func get_bonus(level_index:int = 0):
	var level = get_level(level_index)
	return null if not BONUS in level else level[BONUS]

func get_gap(level_index:int = 0):
	var bonus = get_bonus(level_index)
	return 0 if (!bonus or not GAP in bonus) else bonus[GAP]

func entity_for_level(level_index:int, block_map = {}):
	var bonus = _bonus_item_for_level(level_index, block_map)
	if bonus:
		return bonus
	var thou_shalt_not = _forbidden_entities(block_map)
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

func _bonus_item_for_level(level_index:int, block_map = {}):
	var bonus = get_bonus(level_index)
	if bonus:
		var bonus_count = 0 if not BONUS in block_map else block_map[BONUS].size()
		var bonus_max = 5 if not COUNT in bonus else bonus[COUNT]
		if bonus_count >= bonus_max:
			return null
		var bonus_chance = .1 if not CHANCE in bonus else bonus[CHANCE] - bonus_count * .01
		var r = randf()
		if r < bonus_chance:
			var bonus_item = entity_by_name(bonus.item).duplicate()
			bonus_item.type = BONUS
			return bonus_item
	return null

func entity_by_name(entity_name:String, level_index:int = -1):
	if not entity_name in bestiary:
		print("ERROR: no beasty matches ", entity_name)
		return null
	var entity = bestiary[entity_name]
	if world.game.level_override and level_index >= 0:
		entity.level = level_index + 3
	return entity

##########################################################

func _forbidden_entities(block_map:Dictionary):
	var no_go = {}
	for entity_name in block_map:
		if block_map[entity_name].size() >= 2:
			no_go[entity_name] = true
	return no_go

func _image_resource_to_material(image_resource:String, type:String=""):
	return _image_to_material(load(image_resource), type)

func _image_to_material(image, type:String=""):
	var material = StandardMaterial3D.new()
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
