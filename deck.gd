extends Node2D

func deal_cards(player1, player1_cards, others):
	for colval in player1_cards:
		player1.get_card_from(global_position, colval)
	
	for o in others:
		o.get_card_from(global_position, "", false)
		o.get_card_from(global_position, "", false)
