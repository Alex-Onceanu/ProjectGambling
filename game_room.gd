extends Node2D

var user_id

func _ready():
	# on veut que la fonction _on_request_completed se lance une fois que la requête sera faite
	$HTTPRequest.request_completed.connect(_on_request_completed)

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_request_completed(result, response_code, headers, body):
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	
	# TODO : gestion d'erreurs (faire des try-catch)
	user_id = int(ans)
	print("ID : " + ans)
	
	$enter_code.visible = false
	$Deck.deal_cards($Players/Player1, ["HA", "DA"], [$Players/Player6, $Players/Player4, $Players/Player7, $Players/Player2, $Players/Player5, $Players/Player3, $Players/Player8])

# demander à l'utilisateur d'entrer le code de la game
func _on_server_key_text_submitted(new_text: String) -> void:
	if len($enter_code/server_key.text) <= 30:
		return
	var url = "https://" + $enter_code/server_key.text + ".ngrok-free.app"
	$HTTPRequest.request(str(url) + "/register/user?name=leGodot")
	
	
