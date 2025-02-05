extends Node2D

const DEAL_CD = 0.15

func deal_cards(player1, player1_cards, others):
	var i = 0
	for colval in player1_cards:
		player1.get_card_from(global_position, colval, true, DEAL_CD * i)
		i += 1
	
		for o in others:
			o.get_card_from(global_position, "", false, DEAL_CD * i)
			i += 1
