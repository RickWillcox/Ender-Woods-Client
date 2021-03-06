extends KinematicBody2D

enum State {
	ATTACKING, NORMAL
}

var g = ServerInterface
var speed : float = 7000.0
var state : int = State.NORMAL
var blend_position = Vector2.ZERO
var player_id : int
var velocity = Vector2.ZERO
var experience : int setget set_experience
var current_health : float setget set_current_health

var max_hp : int = 30
var current_hp : int = 30

var player_quests : PlayerQuests = PlayerQuests.new()

var player_stats : Dictionary = {
		"level" : 0
	}


onready var joystick = get_node_or_null("../../GUI/Joystick")
onready var player_stats_panel = get_node_or_null("../../GUI/PlayerStats")
onready var login_screen_panel = get_node_or_null("../../GUI/LoginScreen")
onready var character_base = $CharacterBase

func _ready():
	$HealthBar.max_value = max_hp
	$HealthBar.value = current_hp
	if NakamaConnection.session != null:
		get_node("PlayerName").text = NakamaConnection.session.username
	else:
		Logger.error("Player Name has not been set")
	PacketHandler.connect("own_player_take_damage", self, "take_damage")
	PacketHandler.connect("own_player_dead", self, "_on_death")
	Server.connect("set_player_quests", self, "set_quests")
	# Connect to NPC signal / TODO change the way this works, does this even need to exist? Do I need to exist?
#	get_parent().get_node("NPCs/NPC").connect("change_quest_state", self, "set_quests")

		
func set_experience(_experience):
	# TODO: update stat node here
	experience = _experience

func set_current_health(_current_health):
	# TODO: Deal with player death
	current_health = _current_health


func _physics_process(delta):
	if joystick == null:
		Logger.error("joystick has not been loaded")
		Logger.error("Player _physics_process has been haulted")
		return
	
	match state:
		State.NORMAL:
			if Input.is_action_just_pressed("melee_attack"):
				character_base.travel("slash_1")
				enter_state(State.ATTACKING)
				Server.melee_attack(blend_position)
			else:
				var input_vector = get_input_vector()
				if input_vector == Vector2.ZERO:
					character_base.travel("idle")
				elif input_vector.length() < 0.99:
					character_base.travel("walk")
				else:
					character_base.travel("run")
				velocity = input_vector * speed * delta
		State.ATTACKING:
			velocity = Vector2.ZERO
	velocity = move_and_slide(velocity)
	if velocity.length_squared() > 0:
		blend_position = velocity
		character_base.blend_position = blend_position
	define_player_state()

func enter_state(new_state):
	state = new_state

func get_input_vector() -> Vector2:
	var input_vector : Vector2 = Vector2()
	if joystick != null:
		# assume its normalized
		input_vector = joystick.currentForce
	
	var do_normalize = false
	if Input.is_action_pressed("ui_left"):
		input_vector.x = -1
		do_normalize = true
	elif Input.is_action_pressed("ui_right"):
		input_vector.x = 1
		do_normalize = true
	
	if Input.is_action_pressed("ui_up"):
		input_vector.y = -1
		do_normalize = true
	elif Input.is_action_pressed("ui_down"):
		input_vector.y = 1
		do_normalize = true
	
	if do_normalize:
		return input_vector.normalized()
	return input_vector

func take_damage(_attacker : int, damage : int):
	Logger.info("Self took %d damage" % damage)
	$HealthBar.value -= damage


func define_player_state():
	var player_state = {g.PLAYER_TIMESTAMP: Server.client_clock, g.PLAYER_POSITION: get_global_position(), g.PLAYER_ANIMATION_VECTOR: blend_position}
	Server.send_player_state(player_state)


func get_character_base():
	return $CharacterBase


func _on_CharacterBase_animation_finished(animation_name):
	if state == State.ATTACKING:
		enter_state(State.NORMAL)


func _on_death(respawn_point):
	position = respawn_point

func set_quests(updated_quests):
	#this checks if the quest state is the same or we get an infinite loop of death
	if not updated_quests.hash() == player_quests.get_player_quests().hash():
		player_quests.set_player_quests(player_quests.get_player_quests(), updated_quests)
		Server.send_player_quest_update_to_world_sever(updated_quests)
		NpcLogic.update_npc_quests_based_on_player_quest_state(player_stats, get_node("/root/SceneHandler/Map/YSort/Player"))
	else:
		print("same quest state")
	
func get_quests():
	return player_quests.get_player_quests()
