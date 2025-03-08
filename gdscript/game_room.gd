extends Node2D

var user_id
var url
var tryagain_node
var tryagain_url
var nb_players
var my_player_offset
var round
var money_left
var total_bet
var current_blind
var who_is_playing
var your_bet
var other_players
var every_name

const CD = 0.15

@onready var can_activate_btns = true
@onready var board_cards = []
@onready var in_game = false
@onready var user_name = "debug"

func true_i_of_i(i: int) -> int:
	return 1 + posmod(i - my_player_offset, nb_players)

# met les joueurs sur un polygone régulier à nb_players faces
# cf racines nb_players-ièmes de l'unité (merci à Martial)
func compute_player_pos(player_i):
	const pi = 3.1416
	var theta = 2.0 * pi * player_i / nb_players
	theta += pi / 2		# pour que le joueur 0 soit en bas
	const module = 240.0
	return Vector2(1.4 * module * cos(theta), 0.9 * module * sin(theta)) + $Players.global_position

func rearrange_players(names, anim = false):
	nb_players = len(names)
	my_player_offset = names.find(user_name)
	if my_player_offset == -1:
		print("Me suis pas trouvé moi-même parmi les joueurs ??")
		pass
	
	var true_i
	for i in range(nb_players):
		true_i = true_i_of_i(i)
		get_node("Players/Player" + str(true_i) + "/name_label").text = names[i]
		if not anim:
			get_node("Players/Player" + str(true_i)).global_position = compute_player_pos(true_i - 1)
			get_node("Players/Player" + str(true_i)).visible = true

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_register_completed(result, response_code, headers, body):
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	
	if len(ans) > 3 or len(ans) <= 0:
		$EnterCode/Name.text = ""
		$EnterCode/Name.placeholder_text = "Le serveur est inacessible mdr cheh"
		tryagain_node = $Requests/Register
		tryagain_url = str(url) + "/register/user?name=" + user_name
		$Requests/TryAgain.start()
		return
		
	user_id = int(ans)
	print("ID : ", ans)
	$EnterCode/Name.placeholder_text = "Partie trouvée !"
	$Requests/Ready.request(str(url) + "/ready/")

func _on_ready_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/Name.placeholder_text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Ready
		tryagain_url = str(url) + "/ready/"
		$Requests/TryAgain.start()
	
	elif ans.begins_with("go!"):
		$EnterCode/Name.placeholder_text = "Go go go go !!"
		every_name = ans.substr(3).split(",", false)
		nb_players = len(every_name)
		rearrange_players(every_name)
		$Requests/Cards.request(url + "/cards?id=" + str(user_id))

func start_game(cards):
	var other_players = []
	for i in range(2, nb_players + 1):
		other_players.append(get_node("Players/Player" + str(i)))
		
	$EnterCode.visible = false
	$UI.visible = true
	$Table.visible = true
	$Deck.visible = true
	$Money.visible = true
	in_game = true
	$Deck.deal_cards($Players/Player1, [cards[0], cards[1]], other_players)
	$Requests/UpdateTimer.start()

func _on_cards_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/Name.placeholder_text = "On attend que la partie se lance..."
		$EnterCode/Name.text = ""
		$EnterCode/Name.editable = false
		tryagain_node = $Requests/Cards
		tryagain_url = url + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
	if ans == "invalid" or len(ans) > 20:
		$EnterCode/Name.placeholder_text = "No way ?? Un bug rare sauvage apparait : ID invalide"
		$EnterCode/Name.text = ""
		print("Error : ", ans)
		tryagain_node = $Requests/Cards
		tryagain_url = str(url) + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
		
	var cards = ans.split(",")
	
	if len(cards) <= 1 or len(cards) > 7:
		print("Erreur : on reçoit trop/pas de cartes là")
		pass
	
	if in_game:
		var old_nb_cards = len(board_cards)
		var new_nb_cards = len(cards)
		if new_nb_cards - 2 != old_nb_cards:
			for c in range(2 + old_nb_cards, new_nb_cards):
				var new_card = get_node("Board/" + str(c - 1))
				var target = new_card.global_position
				var wait = CD * (c - old_nb_cards - 1)
				
				new_card.global_position = $Deck.global_position
				new_card.set_card_type(cards[c])
				new_card.visible = true
				new_card.go_to(target, 0.2, wait)
				new_card.reveal(0.2 + wait)
				board_cards.append(cards[c])
	else:
		start_game(cards)

func _on_try_again_timeout() -> void:
	if tryagain_url != "" and tryagain_node != null:
		tryagain_node.request(tryagain_url)
		tryagain_url = ""
		tryagain_node = null

func _on_name_text_submitted(new_text: String) -> void:
	user_name = new_text
	
	$EnterCode/Name.text = ""
	$EnterCode/Name.placeholder_text = "En train de télécommuniquer..."
	$EnterCode/Name.editable = false
	
	if new_text == "debug":
		$EnterCode.visible = false
		$Table.visible = true
		rearrange_players(["j2", "j3", "j4", "j5", "j6", "j7", "j8", "j9", "j10", "j11", "j12", "debug"])
		$Deck.deal_cards($Players/Player1, ["HA", "SA"], [$Players/Player2, $Players/Player3, $Players/Player4, $Players/Player5, $Players/Player6, $Players/Player7, $Players/Player8, $Players/Player9, $Players/Player10, $Players/Player11, $Players/Player12])
		$UI.visible = true
		$Deck.visible = true
		$Money.visible = true
		url = ""
		return
	
	url = "http://gambling.share.zrok.io"
	$Requests/Register.request(str(url) + "/register/user?name=" + user_name)

func _on_update_timer_timeout() -> void:
	$Requests/Update.request(url + "/update?id=" + str(user_id))
	
func animate_bets(bets):
	for b in bets:
		var who = b[0]
		var what = b[1]
		get_node("Players/Player" + str(true_i_of_i(who))).animate_bet(int(what))

func your_turn():
	if can_activate_btns:
		$UI/SeCoucher.disabled = false
		$UI/Surencherir.disabled = false
		$UI/Suivre.disabled = false
	else:
		can_activate_btns = true
	
func end_turn():
	$UI/SeCoucher.disabled = true
	$UI/Surencherir.disabled = true
	$UI/Suivre.disabled = true
	can_activate_btns = false
	# TODO (bug) : on reçoit un update dans lequel c'est tjrs notre tour juste après avoir lancé end_turn
	# donc disabled se remet à false et les boutons restent accessibles

func _on_update_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("Erreur au moment de parser la réponse de /update/ !!")
		return
	
	if round != data["round"]:
		round = int(data["round"])
		$UI/Round.text = ["Pre-flop", "Quoicouflop", "Turn", "River", "FIN"][round]
		
		if round == 4:
			$Requests/Showdown.request(url + "/showdown")
		else:
			$Requests/Cards.request(url + "/cards?id=" + str(user_id))
	
	money_left = data["money_left"]
	
	for i in range(nb_players):
		var true_i = true_i_of_i(i)
		get_node("Players/Player" + str(true_i) + "/money_left").text = str(int(money_left[i])) + "€"
		
	if total_bet != int(data["total_bet"]):
		total_bet = int(data["total_bet"])
		$Money/TotalBet.text = "Mise : " + str(total_bet) + "€"
		for m in range(20, total_bet, 20):
			get_node("Money/MoneyBag" + str(min(m / 20, 10))).visible = true
	
	current_blind = int(data["current_blind"])
	your_bet = int(data["your_bet"])
	$UI/Suivre.text = "Suivre (" + str(current_blind - your_bet) + "€)"
	var old_val = $UI/Surencherir/HowMuch.value
	$UI/Surencherir/HowMuch.min_value = current_blind - your_bet + 1
	$UI/Surencherir/HowMuch.max_value = int(money_left[my_player_offset])
	$UI/Surencherir/HowMuch.value = old_val
	
	animate_bets(data["update"])
	
	who_is_playing = int(data["who_is_playing"])
	$UI/WhoIsPlaying.text = "Au tour de " + every_name[who_is_playing]
	if who_is_playing == my_player_offset:
		your_turn()

func _on_surencherir_pressed() -> void:
	print(str(int($UI/Surencherir/HowMuch.value)))
	$Requests/Bet.request(url + "/bet?id=" + str(user_id) + "&how_much=" + str(int($UI/Surencherir/HowMuch.value)))
	end_turn()

func _on_se_coucher_pressed() -> void:
	$Requests/Fold.request(url + "/fold?id=" + str(user_id))
	end_turn()

func _on_suivre_pressed() -> void:
	if your_bet == current_blind:
		$Requests/Check.request(url + "/check?id=" + str(user_id))
	else:
		$Requests/Bet.request(url + "/bet?id=" + str(user_id) + "&how_much=" + str(current_blind - your_bet))
	end_turn()

# TODO : gérer le cas où le serveur nous répond "transition" avec un TryAgain

# "winners" : all_winners,
# "money_left" : self.money_left,
# "cards" : [self.cards_per_player[p] for p in self.ids],
# "did_timeout" : self.did_timeout,
# "hand_per_player" : hand_per_player

func _on_showdown_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Showdown time !")
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("Erreur au moment de parser la réponse de /update/ !!")
		return
	print("Winners : ", data["winners"])
	print("Money left : ", data["money_left"])
	print("Cards : ", data["cards"])
	print("Hand per player : ", data["hand_per_player"])
	print("Did timeout : ", data["did_timeout"])
	for i in range(nb_players):
		var true_i = true_i_of_i(i)
		if true_i > 1:
			get_node("Players/Player" + str(true_i) + "/money_left").text = str(int(data["money_left"][i])) + "€"
			var their_cards = data["cards"][i].split(",")
			get_node("Players/Player" + str(true_i) + "/Card_1").set_card_type(their_cards[0])
			get_node("Players/Player" + str(true_i) + "/Card_2").set_card_type(their_cards[1])
			get_node("Players/Player" + str(true_i) + "/Card_1").reveal(CD * 2.0 * (true_i - 1))
			get_node("Players/Player" + str(true_i) + "/Card_2").reveal(CD * 2.0 * (true_i - 1) + CD)
			get_node("Players/Player" + str(true_i) + "/combo").text = data["hand_per_player"][i]
			get_node("Players/Player" + str(true_i) + "/combo").visible = true
			if int(data["did_timeout"][i]):
				get_node("Players/Player" + str(true_i)).visible = false
	$Requests/UpdateTimer.stop()
