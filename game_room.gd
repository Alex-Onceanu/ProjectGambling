extends Node2D

var user_id
var url
var tryagain_node
var tryagain_url

# demander à l'utilisateur d'entrer le code de la game
func _on_server_key_text_submitted(new_text: String) -> void:
	if len($EnterCode/ServerKey.text) <= 30:
		return
	
	url = "https://" + $EnterCode/ServerKey.text + ".ngrok-free.app"
	$Requests/Register.request(str(url) + "/register/user?name=leGodot")

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_register_completed(result, response_code, headers, body):
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	
	if len(ans) > 3 or len(ans) <= 0:
		$EnterCode/Welcome.text = "Code invalide, fais un effort stp"
		return
		
	user_id = int(ans)
	print("ID : ", ans)
	$EnterCode/ServerKey.text = ""
	$EnterCode/Welcome.text = "En train de télécommuniquer..."
	$Requests/Cards.request(str(url) + "/cards?id=" + str(user_id))
	


func _on_cards_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "notready":
		$EnterCode/Welcome.text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Cards
		tryagain_url = str(url) + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
	if ans == "invalid" or len(ans) != 4:
		$EnterCode/Welcome.text = "No way ?? Un bug rare sauvage apparait : ID invalide"
		print("Error : ", ans)
		tryagain_node = $Requests/Cards
		tryagain_url = str(url) + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
	
	$EnterCode.visible = false
	$Deck.deal_cards($Players/Player1, [ans[0] + ans[1], ans[2] + ans[3]], [$Players/Player6, $Players/Player4, $Players/Player7, $Players/Player2, $Players/Player5, $Players/Player3, $Players/Player8])


func _on_try_again_timeout() -> void:
	if tryagain_url != "" and tryagain_node != null:
		tryagain_node.request(tryagain_url)
		tryagain_url = ""
		tryagain_node = null
