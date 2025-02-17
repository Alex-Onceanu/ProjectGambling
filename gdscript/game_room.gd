extends Node2D

var user_id
var url
var tryagain_node
var tryagain_url
var nb_players
var round
var money_left
var total_bet
var current_blind
var who_is_playing
var your_bet

@onready var user_name = "debug"

# met les joueurs sur un polygone régulier à nb_players faces
# cf racines nb_players-ièmes de l'unité (merci à Martial)
func compute_player_pos(player_i):
	const pi = 3.1416
	var theta = 2.0 * pi * player_i / nb_players
	theta += pi / 2		# pour que le joueur 0 soit en bas
	const module = 240.0
	return Vector2(1.4 * module * cos(theta), module * sin(theta)) + $Players.global_position

func rearrange_players(names, anim = false):
	nb_players = len(names)
	var offset = names.find(user_name)
	if offset == -1:
		print("Me suis pas trouvé moi-même parmi les joueurs ??")
		pass
	
	var true_i
	for i in range(0, nb_players):
		true_i = 1 + posmod(i - offset, nb_players)
		get_node("Players/Player" + str(true_i) + "/name_label").text = names[i]
		if not anim:
			get_node("Players/Player" + str(true_i)).global_position = compute_player_pos(true_i - 1)
			get_node("Players/Player" + str(true_i)).visible = true

# demander à l'utilisateur d'entrer le code de la game
func _on_server_key_text_submitted(new_text: String) -> void:
	if new_text == "debug":
		$EnterCode.visible = false
		$Table.visible = true
		rearrange_players(["j2", "j3", "j4", "j5", "j6", "j7", "j8", "j9", "j10", "j11", "j12", "player"])
		$Deck.deal_cards($Players/Player1, ["HA", "SA"], [$Players/Player2, $Players/Player3, $Players/Player4, $Players/Player5, $Players/Player6, $Players/Player7, $Players/Player8, $Players/Player9, $Players/Player10, $Players/Player11, $Players/Player12])
		return
		
	$EnterCode/ServerKey.text = ""
	
	if len(new_text) <= 10:
		$EnterCode/ServerKey.placeholder_text = "Mauvais code mdr cheh"
		return
		
	$EnterCode/ServerKey.placeholder_text = "En train de télécommuniquer..."
	$EnterCode/ServerKey.editable = false
	
	url = "https://" + new_text + ".ngrok-free.app"
	$Requests/Register.request(str(url) + "/register/user?name=" + user_name)

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_register_completed(result, response_code, headers, body):
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	
	if len(ans) > 3 or len(ans) <= 0:
		$EnterCode/ServerKey.text = ""
		$EnterCode/ServerKey.placeholder_text = "Code invalide, fais un effort stp"
		$EnterCode/ServerKey.editable = true
		return
		
	user_id = int(ans)
	print("ID : ", ans)
	$EnterCode/ServerKey.placeholder_text = "Partie trouvée !"
	$EnterCode/ServerKey.text = ""
	$EnterCode/ServerKey.editable = false
	$Requests/Ready.request(str(url) + "/ready/")

func _on_ready_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/ServerKey.placeholder_text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Ready
		tryagain_url = str(url) + "/ready/"
		$Requests/TryAgain.start()
	elif ans.begins_with("go!"):
		$EnterCode/ServerKey.placeholder_text = "Go go go go !!"
		rearrange_players(ans.substr(3).split(",", false))
		$Requests/Cards.request(url + "/cards?id=" + str(user_id))
	$EnterCode/ServerKey.text = ""
	$EnterCode/ServerKey.editable = false

func _on_cards_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/ServerKey.placeholder_text = "On attend que la partie se lance..."
		$EnterCode/ServerKey.text = ""
		$EnterCode/ServerKey.editable = false
		tryagain_node = $Requests/Cards
		tryagain_url = url + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
	if ans == "invalid" or len(ans) > 20:
		$EnterCode/ServerKey.placeholder_text = "No way ?? Un bug rare sauvage apparait : ID invalide"
		$EnterCode/ServerKey.text = ""
		print("Error : ", ans)
		tryagain_node = $Requests/Cards
		tryagain_url = str(url) + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
		
	var other_players = []
	for i in range(2, nb_players + 1):
		other_players.append(get_node("Players/Player" + str(i)))
	
	var cards = ans.split(",")
	
	if len(cards) <= 1 or len(cards) > 7:
		print("TODO ??")
		pass
	
	$EnterCode.visible = false
	$Deck.deal_cards($Players/Player1, [cards[0], cards[1]], other_players)
	$Table.visible = true
	$Deck.visible = true


func _on_try_again_timeout() -> void:
	if tryagain_url != "" and tryagain_node != null:
		tryagain_node.request(tryagain_url)
		tryagain_url = ""
		tryagain_node = null


func _on_name_text_submitted(new_text: String) -> void:
	user_name = new_text
	$EnterCode/Name.visible = false
	$EnterCode/ServerKey.visible = true

func _on_update_timer_timeout() -> void:
	$Requests/Update.request(url + "/update?id=" + str(user_id))
	
func animate_bets(bets):
	for b in bets:
		var who = b[0]
		var what = b[1]
		pass

func _on_update_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("Erreur au moment de parser la réponse de /update/ !!")
		return
	
	round = data["round"]
	money_left = data["money_left"]
	total_bet = data["total_bet"]
	current_blind = data["current_blind"]
	who_is_playing = data["who_is_playing"]
	your_bet = data["your_bet"]
	
	animate_bets(data["update"])
