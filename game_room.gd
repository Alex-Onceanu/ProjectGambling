extends Node2D

func _ready():
	# on veut que la fonction _on_request_completed se lance une fois que la requête sera faite
	$HTTPRequest.request_completed.connect(_on_request_completed)
	
	var code = "" # demander à l'utilisateur d'entrer le code de la game
	var url = "https://" + code + ".ngrok-free.app"
	$HTTPRequest.request(str(url) + "/register/user?name=leGodot")

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_request_completed(result, response_code, headers, body):
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	print(ans)
