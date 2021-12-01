extends KinematicBody2D

var state = "Idle"

func move_player(new_position, animation_vector):
	if state != "Attack":
		$CharacterBase.blend_position = animation_vector
		if new_position == position:
			$CharacterBase.travel("idle")
			state = "Idle"
		else:
			state = "Walk"
			$CharacterBase.travel("walk")
			position = new_position

func perform_attack():
	state = "Attack"
	$CharacterBase.travel("slash_1")

func _on_CharacterBase_animation_finished(animation_name):
	if "slash_1" in animation_name:
		state = "Idle"

func get_character_base():
	return $CharacterBase
