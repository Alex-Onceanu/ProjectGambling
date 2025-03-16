extends Node2D

const DEAL_CD = 0.15

func deal_cards(player1, player1_cards, others):
	var i = 0
	for colval in player1_cards:
		player1.get_card_from(global_position, colval, false, DEAL_CD * i)
		i += 1
	
		for o in others:
			o.get_card_from(global_position, "", false, DEAL_CD * i)
			i += 1
	player1.get_node("Card_1").reveal(DEAL_CD * i)
	i += 1
	player1.get_node("Card_2").reveal(DEAL_CD * i)

func get_global_pos():
	return global_position
	
