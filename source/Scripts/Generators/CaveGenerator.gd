extends Node

const AreaMap = preload("res://Entities/AreaMap.gd")
const Boss = preload("res://Entities/Battle/Boss.gd")
const EquipmentGenerator = preload("res://Scripts/Generators/EquipmentGenerator.gd")
const KeyItem = preload("res://Entities/KeyItem.gd")
const MapDestination = preload("res://Entities/MapDestination.gd")
const AreaType = preload("res://Scripts/Enums/AreaType.gd")
const SpotFinder = preload("res://Scripts/Maps/SpotFinder.gd")
const StatType = preload("res://Scripts/Enums/StatType.gd")
const TransitionDistanceChecker = preload("res://Scripts/TransitionDistanceChecker.gd")
const TreasureChest = preload("res://Entities/TreasureChest.gd")
const TwoDimensionalArray = preload("res://Scripts/TwoDimensionalArray.gd")

const _BOSS_DATA = {
	"River": {
		"type": "Neon Pincer",
		"health": 300,
		"strength": 20,
		"defense": 15,
		"turns": 1,
		"experience points": 170,
		
		"skill_probability": 30, # 40 = 40%
		"skills": {
			# These should add up to 100
			"chomp": 70, # 20%,
			"roar": 35
		},
		"drops": {
			"name": "Neon Shard",
			"description": "A neon-coloured shard of giant crab shell"
		}
	},
	"Lava": {
		"type": "StingTail",
		"health": 250,
		"strength": 30,
		"defense": 15,
		"turns": 1,
		"experience points": 170,
		
		"skill_probability": 30, # 40 = 40%
		"skills": {
			"roar": 20,
			"poison": 80
		},
		"drops": {
			"name": "Golden Stinger",
			"description": "A golden-coloured stinger tip, it glows with an inner light"
		}
	}
}

const _VARIANT_TILESETS = {
	"River": "auto:RiverCave",
	"Lava": "auto:LavaCave"
}

const _WATER_DECORATION_TILE_CHOICES = ["WaterRock1", "WaterRock2", "WaterRock3", "WaterRock4"]
const _GROUND_DECORATION_TILE_CHOICES = ["Pebbles1", "Pebbles2", "Pebbles3"]

# Number of "open" floor cells as a percentage of our area
const _FLOOR_TILES_PERCENTAGE = 50

const _PATHS_BUFFER_FROM_EDGE = 3
const _NUM_CHESTS = [0, 1]
const _WATER_DECORATION_TILES_PERCENT = 2 # 1 = 1%
const _GROUND_DECORATION_TILES_PERCENT = 1

const ENTITY_TILES = {} # variation => name => preload("...")

var map_width = Globals.SUBMAP_WIDTH_IN_TILES
var map_height = Globals.SUBMAP_HEIGHT_IN_TILES

# Mostly a SINGLE TILEMAP. You can't have an autotiled ground, and superimpose
# a non-autotiled water map on top. It shows the ground through, which
# is correctly not auto-tiled
var _ground_tilemap = null

# Called once per game
func generate(submap, transitions, variation_name):
	var tileset = _VARIANT_TILESETS[variation_name]
	var map = AreaMap.new("Cave", variation_name, tileset, map_width, map_height, submap.area_type)

	var tile_data = self._generate_cave(submap.area_type, transitions, variation_name)

	map.transitions = transitions
	map.treasure_chests = self._generate_treasure_chests(transitions)

	if submap.area_type == AreaType.AREA_TYPE.BOSS:
		# Brute-force: find the farthest land tile from the entrance. But, only if the
		# distance is within N tiles. Wandering the entire breadth of the dungeon is madness.
		
		# https://www.pivotaltracker.com/story/show/163078635
		# Also, make sure we're on a 7x7 square of land. 3x3 was okay, except in caves,
		# where you may end up on auto-tiles and look like you're in the water/lava.
		# See: https://trello.com/c/i3YUqZSW/187-bosses-can-still-spawn-on-lava
		
		# BUG: what if there's a chest there?
		
		var entrance_transition = transitions[0]
		var entrance = [entrance_transition.my_position.x, entrance_transition.my_position.y]
		
		# 7x7 is a lot to ask; if we didn't find one, redo with 5x5, which is well-tested and works
		var farthest = _find_clear_area(entrance, 3) # r3 = 7d
		if farthest == null:
			farthest = _find_clear_area(entrance ,2) # r2 = 5d
		
		map.bosses = self._generate_boss(variation_name, farthest)

	for data in tile_data:
		map.add_tile_data(data)

	return map

func _find_clear_area(entrance, radius):
	var to_return = null
	var max_distance = 5 * 5
	var distance = 0
	
	for y in range(self.map_height):
		for x in range(self.map_width):
			if _is_area_clear_around(x, y, radius):
				var current_distance = sqrt(pow(x - entrance[0], 2) + pow(y - entrance[1], 2))
				if current_distance > distance and current_distance <= max_distance:
					# Offset by -1, -1 so that the feet of the boss are on the center.
					# In other cases, he may look like he's in lava.
					# See: https://trello.com/c/3MoEnZZS/200-hey-skellyman-stop-standing-in-lava
					to_return = [x - 1, y - 1]
					distance = current_distance
	
	return to_return

func _is_ground(x, y):
	return self._ground_tilemap.get_at(x, y) == "Ground"

func _generate_boss(variation_name, coordinates):
	# TODO: place boss
	var pixel_coordinates = [coordinates[0] * Globals.TILE_WIDTH, coordinates[1] * Globals.TILE_HEIGHT]

	var item_data = _BOSS_DATA[variation_name]["drops"]
	var key_item = KeyItem.new()
	key_item.initialize(item_data["name"], item_data["description"])

	var boss = Boss.new()
	boss.initialize(pixel_coordinates[0], pixel_coordinates[1], _BOSS_DATA[variation_name], key_item)
	return { boss.data.type: [boss] }

func _generate_cave(area_type, transitions, variation_name):
	var to_return = []

	self._ground_tilemap = TwoDimensionalArray.new(self.map_width, self.map_height)
	to_return.append(self._ground_tilemap)
	self._fill_with("Water", self._ground_tilemap)

	### Super glorious hack for monsters appearing on cave water/lava.
	# SpotFinder assumes map.tile_data[1] is the map with walls on it.
	# If it sees a non-null tile, it assumes it's solid, and keeps looking.
	# For the cave, because of autotiles, that's not true. Instead of adding a new
	# variable for this (which changes persistence etc. and is redundant), for
	# caves, we add a duplicate tilemap with the water tiles on it ... sad.
	### This is not going to end well.
	
	var solid_tiles_map = TwoDimensionalArray.new(self.map_width, self.map_height)
	to_return.append(solid_tiles_map)
	
	var decoration_tilemap = TwoDimensionalArray.new(self.map_width, self.map_height)
	to_return.append(decoration_tilemap)
	
	self._generate_tiles(transitions)
	
	for y in range(0, self.map_height):
		for x in range(0, self.map_width):
			var tile = self._ground_tilemap.get_at(x, y)
			if tile != "Ground":
				solid_tiles_map.set_at(x, y, tile)
	
	if variation_name != "Lava":
		self._generate_decoration_tiles(decoration_tilemap)

	return to_return

func _generate_tiles(transitions):
	
	var floors_to_create = floor(self.map_width * self.map_height * _FLOOR_TILES_PERCENTAGE / 100)
	
	var start = transitions[-1]
	var current_x = start.my_position.x
	var current_y = start.my_position.y
	var created_ground = []
	
	while floors_to_create > 0:
		if self._ground_tilemap.get_at(current_x, current_y) != "Ground":
			self._convert_to_dirt([current_x, current_y])
			created_ground.append([current_x, current_y])
			floors_to_create -= 9 # created a 3x3 block
			
		var new_coordinates = self._pick_random_adjacent_tile(current_x, current_y)
		current_x = new_coordinates[0]
		current_y = new_coordinates[1]
		
	# Generate a node close to entrances (5-10 tiles "in" from the entrance).
	# Then, connect entrance => new node => closest path node
	for transition in transitions:

		var entrance = [transition.my_position.x, transition.my_position.y]
		var destination = [transition.my_position.x, transition.my_position.y]
		var offset = Globals.randint(5, 10)

		if entrance[0] == 0:
			# left entrance
			destination[0] += offset
		elif entrance[0] == map_width - 1:
			# right entrance
			destination[0] -= offset
		elif entrance[1] == 0:
			# top entrance
			destination[1] += offset
		elif entrance[1] == map_height - 1:
			# bottom entrance
			destination[1] -= offset

		self._generate_path(entrance, destination)
		var closest_node = self._find_closest_cell_to(destination, created_ground)
		self._generate_path(destination, closest_node)

func _find_closest_cell_to(point, candidates):
	var closest_cell = null
	var closest_distance = null
	
	for candidate in candidates:
		var x = candidate[0]
		var y = candidate[1]
		
		var distance = pow(point[0] - x, 2) + pow(point[1] - y, 2)
		if closest_distance == null or distance < closest_distance:
			closest_cell = [x, y]
			closest_distance = distance
		
	return closest_cell
	
func _generate_path(point1, point2):
	var from_x = point1[0]
	var from_y = point1[1]

	var to_x = point2[0]
	var to_y = point2[1]

	self._convert_to_dirt([from_x, from_y])

	while from_x != to_x or from_y != to_y:
		# If we're farther away on x-axis, move horizontally.
		if abs(from_x - to_x) > abs(from_y - to_y):
			from_x += sign(to_x - from_x)
		else:
			from_y += sign(to_y - from_y)

		self._convert_to_dirt([from_x, from_y])

func _generate_treasure_chests(transitions):
	var num_chests = Globals.randint(_NUM_CHESTS[0], _NUM_CHESTS[1])
	var chests = []
	var chests_coordinates = []
	var types = ["weapon", "armour"]
	var stats = {"weapon": StatType.StatType.Strength, "armour": StatType.StatType.Defense}
	
	# Sigh, refactoring. This map has no separate object/wall map. So pass
	# an empty map in here.
	var empty_map = TwoDimensionalArray.new(map_width, map_height)

	while num_chests > 0:
		var spot = SpotFinder.find_empty_spot(map_width, map_height,
			self._ground_tilemap, empty_map, chests_coordinates)
		
		# Look for a 5x5 clear area so the treasure chest doesn't look like it's on lava
		# after applying auto-tiles. See: https://trello.com/c/j693NyBd/199-treasure-chests-spawn-on-lava
		if _is_area_clear_around(spot[0], spot[1], 2) and TransitionDistanceChecker.is_distant_from_transitions(transitions, spot):
			var type = types[randi() % len(types)]
			var stat = stats[type]
			var item = EquipmentGenerator.generate(type, stat)
			var treasure = TreasureChest.new()
			treasure.initialize(spot[0], spot[1], item)
			chests.append(treasure)
			chests_coordinates.append(spot)
			num_chests -= 1

	return chests

func _pick_random_adjacent_tile(x, y):
	var to_return = []
	
	if x > _PATHS_BUFFER_FROM_EDGE:
		to_return.append([x - 1, y])
	if x < map_width - _PATHS_BUFFER_FROM_EDGE - 1:
		to_return.append([x + 1, y])
	if y > _PATHS_BUFFER_FROM_EDGE:
		to_return.append([x, y - 1])
	if y < map_height - _PATHS_BUFFER_FROM_EDGE - 1:
		to_return.append([x, y + 1])
		
	return to_return[randi() % len(to_return)]

func _generate_decoration_tiles(decoration_tilemap):
	self._decorate_water(decoration_tilemap)
	self._decorate_ground(decoration_tilemap)

# Adds random rocks into the river
func _decorate_water(decoration_tilemap):
	var num_left = floor(_WATER_DECORATION_TILES_PERCENT * self.map_width * self.map_height / 100)
	
	while num_left > 0:
		var x = Globals.randint(_PATHS_BUFFER_FROM_EDGE, map_width - _PATHS_BUFFER_FROM_EDGE - 1)
		var y = Globals.randint(_PATHS_BUFFER_FROM_EDGE, map_height - _PATHS_BUFFER_FROM_EDGE - 1)
		
		# Add the rock to a center of a 3x3 square of water. This plays nicely with autotiles.
		if (self._is_clear_around(self._ground_tilemap, x, y, "Water") and
			self._is_clear_around(decoration_tilemap, x, y, null)):
				var tile = _WATER_DECORATION_TILE_CHOICES[randi() % len(_WATER_DECORATION_TILE_CHOICES)]
				decoration_tilemap.set_at(x, y, tile)
				num_left -= 1

# Adds random rocks into the river
func _decorate_ground(decoration_tilemap):
	var num_left = floor(_GROUND_DECORATION_TILES_PERCENT * self.map_width * self.map_height / 100)
	
	while num_left > 0:
		var x = Globals.randint(_PATHS_BUFFER_FROM_EDGE, map_width - _PATHS_BUFFER_FROM_EDGE - 1)
		var y = Globals.randint(_PATHS_BUFFER_FROM_EDGE, map_height - _PATHS_BUFFER_FROM_EDGE - 1)
		
		# Add the rock to a center of a 3x3 square of ground. This plays nicely with autotiles.
		if (self._is_clear_around(self._ground_tilemap, x, y, "Ground") and
			self._is_clear_around(decoration_tilemap, x, y, null)):
				
				var tile = _GROUND_DECORATION_TILE_CHOICES[randi() % len(_GROUND_DECORATION_TILE_CHOICES)]
				decoration_tilemap.set_at(x, y, tile)
				num_left -= 1

func _is_clear_around(tilemap, x, y, empty_tile_definition):
	return (tilemap.get_at(x, y) == empty_tile_definition and tilemap.get_at(x, y - 1) == empty_tile_definition and
		tilemap.get_at(x + 1, y - 1) == empty_tile_definition and tilemap.get_at(x + 1, y) == empty_tile_definition and
		tilemap.get_at(x + 1, y + 1) == empty_tile_definition and tilemap.get_at(x, y + 1) == empty_tile_definition and
		tilemap.get_at(x - 1, y + 1) == empty_tile_definition and tilemap.get_at(x - 1, y) == empty_tile_definition and
		tilemap.get_at(x - 1, y - 1) == empty_tile_definition)

# Checking a 3x3 area for bosses isn't enough, because autotiles shrink that to 1x1.
# Turns out, even 5x5 may not be enough; so go with 7x7, with the chance of breaking
# if we can't find a suitably-sized area in some maps.
func _is_area_clear_around(center_x, center_y, radius):
	# range is exclusive so add +1 to end value
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if not _is_ground(x, y):
				return false
				
	return true
	
############# TODO: DRY
# Almost common with OverworldGenerator
func _fill_with(tile_name, map_array):
	for y in range(0, map_height):
		for x in range(0, map_width):
			map_array.set_at(x, y, tile_name)

# Creates a 3x3 dirt square. Technically, we only need a 2x2 for auto-tiling.
# But, if we use a 2x2, we get disembodied-looking islands that we can walk on.
# Also, creating a 3x3 from (0, 0) to (2, 2) doesn't work; we have to create it
# centered around the specified tile. That works.
func _convert_to_dirt(position):
	var x = position[0]
	var y = position[1]
	
	self._convert_to([x, y])
	# 2x2
	self._convert_to([x - 1, y])
	self._convert_to([x, y - 1])
	self._convert_to([x - 1, y - 1])
	# 3x3
	self._convert_to([x + 1, y - 1])
	self._convert_to([x + 1, y])
	self._convert_to([x + 1, y + 1])
	self._convert_to([x, y + 1])
	self._convert_to([x - 1, y + 1])
	

func _convert_to(position, type = "Ground"):
	# Draws dirt at the specified position. Also clears trees for
	# one tile in all directions surrounding the dirt (kind of like
	# drawing with a 3x3 grass brush around the dirt).
	var x = position[0]
	var y = position[1]

	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		self._ground_tilemap.set_at(x, y, type)
