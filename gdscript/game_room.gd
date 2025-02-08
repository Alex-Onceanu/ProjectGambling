extends Node2D

var user_id
var url
var tryagain_node
var tryagain_url
var nb_players

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
		rearrange_players(["moi", "toi", "lui", "soi", "n", "v", "j", "soi", "n", "v", "j", "j"])
		$Deck.deal_cards($Players/Player1, ["HA", "SA"], [$Players/Player2, $Players/Player3, $Players/Player4, $Players/Player5, $Players/Player6, $Players/Player7, $Players/Player8, $Players/Player9, $Players/Player10, $Players/Player11, $Players/Player12])
		return
	
	if len(new_text) <= 10:
		return
		
	$EnterCode/Welcome.text = "En train de télécommuniquer..."
	
	url = "https://" + new_text + ".ngrok-free.app"
	$Requests/Register.request(str(url) + "/register/user?name=" + user_name)
	$EnterCode/ServerKey.text = ""

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_register_completed(result, response_code, headers, body):
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	
	if len(ans) > 3 or len(ans) <= 0:
		$EnterCode/Welcome.text = "Code invalide, fais un effort stp"
		return
		
	user_id = int(ans)
	print("ID : ", ans)
	$EnterCode/ServerKey.text = ""
	$EnterCode/Welcome.text = "Partie trouvée !"
	$Requests/Ready.request(str(url) + "/ready/")

func _on_ready_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/Welcome.text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Ready
		tryagain_url = str(url) + "/ready/"
		$Requests/TryAgain.start()
		return
	elif ans.begins_with("go!"):
		$EnterCode/Welcome.text = "Go go go go !!"
		rearrange_players(ans.substr(3).split(",", false))
		$Requests/Cards.request(url + "/cards?id=" + str(user_id))

func _on_cards_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/Welcome.text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Cards
		tryagain_url = url + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
	if ans == "invalid" or len(ans) > 20:
		$EnterCode/Welcome.text = "No way ?? Un bug rare sauvage apparait : ID invalide"
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


func _on_try_again_timeout() -> void:
	if tryagain_url != "" and tryagain_node != null:
		tryagain_node.request(tryagain_url)
		tryagain_url = ""
		tryagain_node = null


func _on_name_text_submitted(new_text: String) -> void:
	user_name = new_text
	$EnterCode/Name.visible = false
	$EnterCode/ServerKey.visible = true
