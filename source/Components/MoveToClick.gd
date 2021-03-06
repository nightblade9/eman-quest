###
# Moves the parent to the specified target (mouse-click).
# On Android, moves to the touched location.
###
extends Node2D

const Footsteps = preload("res://assets/audio/sfx/footstep.ogg")

const MINIMUM_MOVE_DISTANCE = 5

signal facing_new_direction # we're facing a new direction as a result of clicking
signal reached_destination # stop moving please and thanks

export var speed = 0

var destination = null # Vector2

var _audio_player

func _ready():
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = Footsteps
	add_child(_audio_player)
	Globals.connect("clicked_on_map", self, "_clicked_on_map")

func _physics_process(delta):
	# Called every frame. Delta is time since last frame.
	if self.get_parent().can_move:
		self._move_parent_to_clicked_destintion()
		
func stop_footsteps_audio():
	_audio_player.stop()
	# cancel destination so we don't try to move again next frame + play audio
	# Comes into play if you click past a chest, get "stuck" on it, and open it
	self.cancel_destination()

func _clicked_on_map(position):
	if self.get_parent().can_move:
		self.destination = position
		
		var new_facing = ""
		var direction = self.destination - self.get_parent().position
		var magnitude = direction.abs()
		
		if magnitude.x > magnitude.y: # more horizontal than vertical
			if direction.x < 0:
				new_facing = "Left"
			else:
				new_facing = "Right"
		else:
			if direction.y < 0:
				new_facing = "Up"
			else:
				new_facing = "Down"
		
		# Even if you didn't change directions, restart animation.
		# You may have moved down, then reached, now move down again
		self.emit_signal("facing_new_direction", new_facing)

func cancel_destination():
	self.destination = null

func _move_parent_to_clicked_destintion():
	var destination = self.destination
	var position = self.get_parent().position
	
	if destination != null:
		var velocity = (destination - position).normalized() * self.speed
		if (destination - position).length() > MINIMUM_MOVE_DISTANCE:
			self.get_parent().move_and_slide(velocity)
			if not _audio_player.playing:
				_audio_player.play()
		# 3) typically,  you click, you reach, we emit here, done.
		# BUT, if the user is just click-holding, they should still move.
		# SO, make sure Globals.mouse_down is false before stopping.
		elif Globals.mouse_down:
			self.destination = get_global_mouse_position()
		elif not Globals.mouse_down:
			self.emit_signal("reached_destination")
			_audio_player.stop()