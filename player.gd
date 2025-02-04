extends Node2D

const MAX_NB_CARDS = 2
@onready var nb_cards = 0

func get_card_from(from : Vector2, colval : String):
	if nb_cards >= MAX_NB_CARDS:
		# on peut pas avoir 3 cartes au poker
		return
		
	nb_cards += 1
	var new_card = get_node("Card_" + str(nb_cards))
	
	new_card.global_position = from
	new_card.set_card_type(colval)
	new_card.flip_frontface()
	new_card.visible = true
	new_card.go_to(global_position + Vector2((nb_cards - 1) * 36, 0.0))
	
func send_card_to(which : int, target : Vector2):
	if which <= 0 or which > nb_cards:
		return
	get_node("Card_" + str(which)).go_to(target)
