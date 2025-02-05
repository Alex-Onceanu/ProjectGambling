extends Node2D

const MAX_NB_CARDS = 2
@onready var GAP_SIZE = 75 * $Card_1.scale.x
@onready var nb_cards = 0

func get_card_from(from : Vector2, colval : String, frontface = true, cd = -1.0):
	if nb_cards >= MAX_NB_CARDS:
		# on peut pas avoir 3 cartes au poker
		return
		
	nb_cards += 1
	var new_card = get_node("Card_" + str(nb_cards))
	new_card.global_position = from
	
	if frontface:
		new_card.set_card_type(colval)
		new_card.flip_frontface()
	else:
		new_card.flip_backface()
		
	new_card.visible = true
	var left_or_right = (nb_cards - 1) * 2 - 1
	new_card.go_to(global_position + Vector2(left_or_right * GAP_SIZE / 2, 0.0), 0.25, cd)
	
	
func send_card_to(which : int, target : Vector2):
	if which <= 0 or which > nb_cards:
		return
	get_node("Card_" + str(which)).go_to(target)
