extends Node2D

var user_id
var url
var tryagain_node
var tryagain_url
var nb_players
var my_player_offset
var money_left
var total_bet
var current_blind
var who_is_playing
var your_bet
var other_players
var every_name

const CD = 0.15

@onready var user_did_timeout = false
@onready var is_spectator = false
@onready var round = -1
@onready var can_activate_btns = true
@onready var board_cards = []
@onready var in_game = false
@onready var user_name = "debug"
@onready var p1_has_cards = false

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
	
	if len(ans) > 4 or len(ans) <= 0:
		print("error : " + ans)
		$EnterCode/Name.text = ""
		$EnterCode/Name.placeholder_text = "Le serveur est inacessible mdr cheh"
		tryagain_node = $Requests/Register
		tryagain_url = str(url) + "/register/user?name=" + user_name
		$Requests/TryAgain.start()
		return
		
	user_id = int(ans)
	print("ID : ", ans)
	$EnterCode/Name.placeholder_text = "Partie trouvée !"
	$Requests/Ready.request(str(url) + "/ready?id=" + str(user_id))

func _on_ready_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	print("Ready completed : ", ans)
	$UI/Rejouer.visible = false
	if ans.begins_with("spectator"):
		ans = ans.substr(9)
		$EnterCode/Name.placeholder_text = "Tkt je te fais entrer en tant que spectateur"
		$EnterCode/Name.text = ""
		is_spectator = true
	
	if ans == "notready":
		$EnterCode/Name.placeholder_text = "On attend que la partie se lance..."
		$Money/TotalBet.text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Ready
		tryagain_url = str(url) + "/ready?id=" + str(user_id)
		$Requests/TryAgain.start()
	
	elif ans.begins_with("go!"):
		$EnterCode/Name.placeholder_text = "Go go go go !!" if not is_spectator else "Tu es sur le point de spectate une masterclass"
		$Money/TotalBet.text = "Allez une game de +"
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
	$UI/Rejoindre.visible = false
	in_game = true
	board_cards = []
	
	if is_spectator:
		other_players.append($Players/Player1)
		var how_much_wait = $Deck.deal_cards(null, [], other_players)
		$Requests/WaitBeforeUpdate.wait_time = max(0, how_much_wait - $Requests/UpdateTimer.wait_time)
	else:
		var how_much_wait = $Deck.deal_cards($Players/Player1, [cards[0], cards[1]], other_players) - $Requests/UpdateTimer.wait_time
		$Requests/WaitBeforeUpdate.wait_time = max(0, how_much_wait - $Requests/UpdateTimer.wait_time)

	$Requests/WaitBeforeUpdate.start()

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
		
	if not is_spectator and (len(cards) <= 1 or len(cards) > 7):
		print("Erreur : on reçoit trop/pas de cartes là")
		return

	if in_game and len(cards) > 0 and (len(cards) > 1 or cards[0] != ""):
		if not p1_has_cards and not is_spectator:
			$Requests/CardToVFX.request(url + "/vfx?id=" + str(user_id))
		
		var old_nb_cards = len(board_cards)
		var new_nb_cards = len(cards)
		var player_nb_cards = 0 if is_spectator and not user_did_timeout else 2
		if new_nb_cards - player_nb_cards != old_nb_cards:
			for c in range(player_nb_cards + old_nb_cards, new_nb_cards):
				if p1_has_cards and not is_spectator:
					$Requests/CardToVFX.request(url + "/vfx?id=" + str(user_id))
					
				var new_card = get_node("Board/" + str(c - player_nb_cards + 1))
				var target = $Board.position + Vector2(75.0 * (c - player_nb_cards) - 150.0, 0.0)
				var wait = CD * (c - old_nb_cards - player_nb_cards + 1)
				
				new_card.global_position = $Deck.get_global_pos()
				new_card.set_card_type(cards[c])
				new_card.visible = true
				new_card.go_to(target, 0.2, wait)
				new_card.reveal(0.2 + wait)
				board_cards.append(cards[c])
		if not is_spectator:
			p1_has_cards = true
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
	
	url = "http://gambling2.share.zrok.io"
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

func _on_update_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	var data = JSON.parse_string(ans)
	if data == null:
		print("Erreur au moment de parser la réponse de /update/ !! err : " + ans)
		return
	
	if round != data["round"]:
		round = int(data["round"])
		$UI/Round.text = ["Pre-flop", "Quoicouflop", "Turn", "River", "FIN"][round]
		
		if round == 4:
			$Requests/Showdown.request(url + "/showdown")
		else:
			$Requests/Cards.request(url + "/cards?id=" + str(user_id))

	money_left = data["money_left"]
	
	if round != 4:
		for i in range(nb_players):
			var true_i = true_i_of_i(i)
			if i < len(money_left):
				get_node("Players/Player" + str(true_i) + "/money_left").text = str(int(money_left[i])) + "€"
				get_node("Players/Player" + str(true_i) + "/money_left").visible = true
#	
	if total_bet != int(data["total_bet"]):
		total_bet = int(data["total_bet"])
		$Money/TotalBet.text = "Mise : " + str(total_bet) + "€"
		for m in range(20, total_bet, 20):
			get_node("Money/MoneyBag" + str(min(m / 20, 10))).visible = true
	
	if round != 4:
		current_blind = int(data["current_blind"])
		your_bet = int(data["your_bet"])
		$UI/Suivre.text = "Suivre (" + str(current_blind - your_bet) + "€)"
		var old_val = $UI/Surencherir/HowMuch.value
		$UI/Surencherir/HowMuch.min_value = current_blind - your_bet + 1
		$UI/Surencherir/HowMuch.max_value = int(money_left[my_player_offset])
		$UI/Surencherir/HowMuch.value = old_val
	
	animate_bets(data["update"])
	if data["update"].find([my_player_offset * 1.0, -2.0]) != -1:
		is_spectator = true
		$Players/Player1/Card_1/vfx.visible = false
		$Players/Player1/Card_2/vfx.visible = false
		user_did_timeout = true
		
	if who_is_playing != int(data["who_is_playing"]):
		if who_is_playing != null:
			get_node("Players/Player" + str(true_i_of_i(who_is_playing))).end_scale_anim()
		who_is_playing = int(data["who_is_playing"])
		get_node("Players/Player" + str(true_i_of_i(who_is_playing))).begin_scale_anim()
		$UI/WhoIsPlaying.text = "Au tour de " + every_name[who_is_playing]
	if who_is_playing == my_player_offset:
		your_turn()
	else:
		end_turn()

func _on_surencherir_pressed() -> void:
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

# "winners" : all_winners,
# "money_left" : self.money_left,
# "cards" : [self.cards_per_player[p] for p in self.ids],
# "did_timeout" : self.did_timeout,
# "hand_per_player" : hand_per_player

func _on_showdown_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("Erreur au moment de parser la réponse de /update/ !!")
		return

	#print("Winners : ", data["winners"])
	#print("Money left : ", data["money_left"])
	#print("Cards : ", data["cards"])
	#print("Hand per player : ", data["hand_per_player"])
	#print("Did timeout : ", data["did_timeout"])
	
	$UI/WhoIsPlaying.text = ""
	get_node("Players/Player" + str(true_i_of_i(who_is_playing))).end_scale_anim()
	
	if len(data["winners"]) > 1:
		$UI/Round.text = "Vainqueurs : "
	else:
		$UI/Round.text = "Vainqueur : "
	var true_winners = []
	for w in data["winners"]:
		# dire aux sacs d'argent d'aller au gagnant
		$UI/Round.text += every_name[w] + " "
		var player_node = get_node("Players/Player" + str(true_i_of_i(int(w))))
		true_winners.append(player_node.global_position)
		player_node.begin_scale_anim()
		get_node("Players/Player" + str(true_i_of_i(int(w))) + "/money_left").text = str(int(get_node("Players/Player" + str(true_i_of_i(int(w))) + "/money_left").text) + int(data["reward"])) + "€"
	$Money.set_winners(true_winners)
	
	for i in range(nb_players):
		var true_i = true_i_of_i(i)
		if true_i > 1 or is_spectator:
			var their_cards = data["cards"][i].split(",")
			get_node("Players/Player" + str(true_i) + "/Card_1").set_card_type(their_cards[0])
			get_node("Players/Player" + str(true_i) + "/Card_2").set_card_type(their_cards[1])
			get_node("Players/Player" + str(true_i) + "/Card_1").reveal(CD * 2.0 * (true_i - 1))
			get_node("Players/Player" + str(true_i) + "/Card_2").reveal(CD * 2.0 * (true_i - 1) + CD)
		get_node("Players/Player" + str(true_i) + "/combo").text = data["hand_per_player"][i]
		get_node("Players/Player" + str(true_i) + "/combo").visible = true
	$Requests/UpdateTimer.stop()
	
	if int($Players/Player1/money_left.text) <= 0 and not str(my_player_offset * 1.0) in data["winners"]:
		is_spectator = true
		$Players/Player1/Card_1/vfx.visible = false
		$Players/Player1/Card_2/vfx.visible = false
	
	if is_spectator:
		$UI/CDSpectate.start()
		$UI/Rejoindre.disabled = false
		$UI/Rejoindre.visible = true
	else:
		$UI/Rejouer.visible = true

func _on_card_to_vfx_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	var data = JSON.parse_string(ans)
	if data == null:
		return
		
	for i in range(1, 6):
		get_node("Board/" + str(i) + "/vfx").visible = false
	$Players/Player1/Card_1/vfx.visible = false
	$Players/Player1/Card_2/vfx.visible = false
	
	for card_id in data:
		var node_path = "Board/" + str(int(card_id) + 1) if int(card_id) <= 4 else ("Players/Player1/Card_" + str(int(card_id) - 4))
		var this_vfx = get_node(node_path + "/vfx")
		this_vfx.visible = true

func _on_rejouer_pressed() -> void:
	$UI/Rejouer.visible = false
	
	const anim_speed = 0.5
	for i in range(nb_players):
		var true_i = true_i_of_i(i)
		var this_player = get_node("Players/Player" + str(true_i))
		this_player.end_scale_anim()
		this_player.send_card_to(1, $Deck.get_global_pos(), 0.08 + CD * 2.0 * (true_i - 1))
		this_player.send_card_to(2, $Deck.get_global_pos(), 0.08 + CD * 2.0 * (true_i - 1) + CD)
		get_node("Players/Player" + str(true_i) + "/combo").visible = false
		get_node("Players/Player" + str(true_i) + "/name_label").visible = false
		get_node("Players/Player" + str(true_i) + "/money_left").visible = false
		get_node("Players/Player" + str(true_i) + "/Card_1").reveal(CD * 2.0 * (true_i - 1), true)
		get_node("Players/Player" + str(true_i) + "/Card_2").reveal(CD * 2.0 * (true_i - 1) + CD, true)
	for i in range(1, 6):
		get_node("Board/" + str(i)).go_to($Deck.get_global_pos(), 0.4, 0.08 + CD * 2.0 * (nb_players - 1 + anim_speed * i))
		get_node("Board/" + str(i)).reveal(CD * 2.0 * (nb_players - 1 + anim_speed * i), true)
	p1_has_cards = false
	in_game = false
	user_did_timeout = false
	$Requests/Ready.request(str(url) + "/ready?id=" + str(user_id))

func _on_server_go_pressed() -> void:
	$Requests/ServerGo.request(str(url) + "/GO")

func _on_cd_spectate_timeout() -> void:
	_on_rejouer_pressed()

func _on_rejoindre_pressed() -> void:
	$Requests/Unspectate.request(str(url) + "/unspectate?id=" + str(user_id))
	$UI/Rejoindre.disabled = true
	
func _on_unspectate_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "ok":
		is_spectator = false
		$Money/TotalBet.text = "Tu vas join la prochaine game"
		$UI/Rejoindre.visible = false
	else:
		$UI/Rejoindre.disabled = false

func _on_wait_before_update_timeout() -> void:
	$Requests/UpdateTimer.start()
