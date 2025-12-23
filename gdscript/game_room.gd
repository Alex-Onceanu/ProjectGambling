extends Node2D

var game_code
var user_id
var url0 = "http://localhost:8080/"
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
var old_dealer

var cards_front
var cards_back

const CD = 0.15
const VOLUME_MIN = -30.0
const VOLUME_MAX = 6.0
const SAVEFILE_PATH = "user://sauvegarde.givs"


@onready var current_money = 5000
@onready var old_money = current_money
@onready var current_skin = "1"
@onready var user_did_timeout = false
@onready var is_spectator = false
@onready var round = -1
@onready var can_activate_btns = true
@onready var board_cards = []
@onready var in_game = false
@onready var user_name = "debug"
@onready var p1_has_cards = false
@onready var purchased_skins = ["1", "6"]

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

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("check") and in_game and not $UI/Suivre.disabled:
		_on_suivre_pressed()
	elif Input.is_action_just_pressed("pause"):
		if $Shop/CanvasLayer.visible:
			_on_close_shop_pressed($Shop.current_equipped)
		elif $PauseMenu/CanvasLayer.visible:
			_on_close_menu_pressed()
		else:
			pause()

func rearrange_players(names, anim = false):
	var true_i
	for i in range(nb_players):
		true_i = true_i_of_i(i)
		get_node("Players/Player" + str(true_i) + "/name_label").text = names[i]
		if not anim:
			get_node("Players/Player" + str(true_i)).global_position = compute_player_pos(true_i - 1)
			get_node("Players/Player" + str(true_i)).visible = true

# se lance dès que le serveur nous a répondu (la réponse est en argument)
func _on_register_completed(result, response_code, headers, body):
	#print("Body : ", body)
	var ans = body.get_string_from_utf8() # le serv répond juste un string
	if ans == "wronglobby":
		$TitleScreen/CanvasLayer/Play.disabled = false
		$TitleScreen/CanvasLayer/Play.visible = true
		$TitleScreen/CanvasLayer/Submit.disabled = false
		$TitleScreen/CanvasLayer/Submit.visible = false
		$EnterCode/CanvasLayer/Name.text = ""
		$EnterCode/CanvasLayer/GameCode.text = ""
		$EnterCode/CanvasLayer/Name.placeholder_text = "Ton code est faux frr"
		return
	elif len(ans) > 4 or len(ans) <= 0:
		print("error : " + ans)
		$EnterCode/CanvasLayer/Name.text = ""
		$EnterCode/CanvasLayer/Name.placeholder_text = "Le serveur est inacessible mdr cheh"
		tryagain_node = $Requests/Register
		tryagain_url = url + "/register/user?name=" + user_name + "&skin=" + current_skin + "&money=" + str(current_money)
		$Requests/TryAgain.start()
		return
		
	user_id = int(ans)
	#print("ID : ", ans)
	$EnterCode/CanvasLayer/Name.placeholder_text = "Partie trouvée !"
	$Requests/Ready.request(url + "/ready?id=" + str(user_id))

func _on_ready_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	$UI/Rejouer.visible = false
		
	if ans.begins_with("spectator"):
		ans = ans.substr(9)
		$EnterCode/CanvasLayer/Name.placeholder_text = "Tkt je te fais entrer en tant que spectateur"
		$EnterCode/CanvasLayer/Name.text = ""
		is_spectator = true
	
	if ans == "notready":
		$EnterCode/CanvasLayer/Name.placeholder_text = "On attend que la partie se lance..."
		$Money/TotalBet.text = "On attend que la partie se lance..."
		tryagain_node = $Requests/Ready
		tryagain_url = url + "/ready?id=" + str(user_id)
		$Requests/TryAgain.start()
	
	elif ans.begins_with("go!"):
		if not is_spectator:
			$Shop/CanvasLayer/Invoc.disabled = true
		$EnterCode/CanvasLayer/Name.placeholder_text = "Go go go go !!" if not is_spectator else "Tu es sur le point de spectate une masterclass"
		$Money/TotalBet.text = "Allez une game de +"
		var data = JSON.parse_string(ans.substr(3))
		every_name = data["names"]
		nb_players = len(every_name)
		my_player_offset = int(data["offset"]) # vaudra -1 si on est spectateur !
		
		for i in range(nb_players):
			change_skin_of(i, data["skins"][i])
		
		rearrange_players(every_name)
		$Requests/Cards.request(url + "/cards?id=" + str(user_id))
		$TitleScreen/CanvasLayer.layer = 1
		$TitleScreen.fade_in()
		$TitleScreen/TitleMusic.stream_paused = true
		

func update_rythm():
	$BackgroundParticles.visible = true
	get_node("BackgroundParticles").set_frequency($MusicPlayer.get_bps())
	get_node("BackgroundParticles").set_phase($MusicPlayer.get_phase() + fposmod(Time.get_ticks_msec() / 1000, 1.0))
	$MusicPlayer/StreamPlayer.play()

func start_game(cards):
	$TitleScreen.fade_out()
	if not $BackgroundParticles.visible:
		$BackgroundParticles.pause_particles(true)
		update_rythm()
	var other_players = []
	for i in range(2, nb_players + 1):
		other_players.append(get_node("Players/Player" + str(i)))
	
	$PauseMenu/CanvasLayer/Menu/NextMusic.disabled = false
	$PauseMenu/CanvasLayer/Menu/PrevMusic.disabled = false
	$PauseMenu/CanvasLayer/Menu/PauseMusic.disabled = false
	
	$EnterCode/CanvasLayer.visible = false
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
		$EnterCode/CanvasLayer/Name.placeholder_text = "On attend que la partie se lance..."
		$EnterCode/CanvasLayer/Name.text = ""
		$EnterCode/CanvasLayer/Name.editable = false
		tryagain_node = $Requests/Cards
		tryagain_url = url + "/cards?id=" + str(user_id)
		$Requests/TryAgain.start()
		return
	if ans == "invalid" or len(ans) > 20:
		$EnterCode/CanvasLayer/Name.placeholder_text = "No way ?? Un bug rare sauvage apparait : ID invalide"
		$EnterCode/CanvasLayer/Name.text = ""
		print("Error : ", ans)
		tryagain_node = $Requests/Cards
		tryagain_url = url + "/cards?id=" + str(user_id)
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
		$BackgroundParticles.set_colors(cards)
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
		$TitleScreen.visible = false
		$TitleScreen/ChipRain.emitting = false
		$TitleScreen/CanvasLayer/Play.visible = false
		$TitleScreen/CanvasLayer/Options.visible = false
		$TitleScreen/CanvasLayer/Gacha.visible = false
		$TitleScreen/CanvasLayer/Submit.visible = false
		start_game(cards)

func _on_try_again_timeout() -> void:
	if tryagain_url != "" and tryagain_node != null:
		tryagain_node.request(tryagain_url)
		tryagain_url = ""
		tryagain_node = null

func _on_name_text_submitted(new_text: String) -> void:
	if len(new_text) == 0: return
	user_name = new_text.replace(" ", "_")
	
	$TitleScreen/CanvasLayer/Submit.disabled = true
	$EnterCode/CanvasLayer/Name.text = ""
	$EnterCode/CanvasLayer/Name.placeholder_text = "En train de télécommuniquer..."
	$EnterCode/CanvasLayer/Name.editable = false
	$EnterCode/CanvasLayer.layer = 1
	
	url = url0 + game_code
	$Lobby/StartGame.disabled = false
	$Requests/Register.request(url + "/register/user?name=" + user_name + "&skin=" + current_skin + "&money=" + str(current_money))
	$PauseMenu/CanvasLayer/Menu/BackToTitle.disabled = false

func _on_update_timer_timeout() -> void:
	$Requests/Update.request(url + "/update?id=" + str(user_id))
	
func change_player_text_color(who : int, col : Color) -> void:
	get_node("Players/Player" + str(who) + "/name_label").set("theme_override_colors/font_color", col)
	get_node("Players/Player" + str(who) + "/money_left").set("theme_override_colors/font_color", col)
	get_node("Players/Player" + str(who) + "/combo").set("theme_override_colors/font_color", col)
	
func change_skin_of(who, skin):
	var back
	if skin == "2":
		back = cards_back[1][randi_range(0, 9)]
	else:
		back = cards_back[int(skin) - 1]
	get_node("Players/Player" + str(true_i_of_i(who))).change_skin(skin, cards_front[int(skin) - 1], back)
	
func animate_bets(bets):
	for b in bets:
		var who = b[0]
		var what = int(b[1])
		if what == -5:
			# changement de skin
			change_skin_of(who, b[2])
			return
		if what == -3:
			# petite blinde
			change_player_text_color(true_i_of_i(posmod(who - 1, nb_players)), Color(0.8, 0.4, 0.4))
			if old_dealer != null:
				change_player_text_color(old_dealer, Color(0.996, 0.8353, 0.451))
			old_dealer = true_i_of_i(posmod(who - 1, nb_players))
		get_node("Players/Player" + str(true_i_of_i(who))).animate_bet(what)

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
	
	if not is_spectator:
		current_money = int($Players/Player1/money_left.text.substr(0, len($Players/Player1/money_left.text) - 1))
	
	if round != 4:
		current_blind = int(data["current_blind"])
		your_bet = int(data["your_bet"])
		$UI/Suivre.text = "Suivre (" + str(current_blind - your_bet) + "€)"
		var old_val = $UI/Surencherir/HowMuch.value
		$UI/Surencherir/HowMuch.min_value = current_blind - your_bet + 10
		$UI/Surencherir/HowMuch.max_value = current_money
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
	

func _on_showdown_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("Erreur au moment de parser la réponse de /showdown/ !!")
		return
		
	$UI/WhoIsPlaying.text = ""
	get_node("Players/Player" + str(true_i_of_i(who_is_playing))).end_scale_anim()
	who_is_playing = null
	
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
	
	current_money = int($Players/Player1/money_left.text)
	if current_money <= 0 and not str(my_player_offset * 1.0) in data["winners"]:
		is_spectator = true
		$Players/Player1/Card_1/vfx.visible = false
		$Players/Player1/Card_2/vfx.visible = false
	
	if is_spectator:
		$UI/CDSpectate.start()
		$UI/Rejoindre.disabled = false
		$UI/Rejoindre.visible = true
	else:
		$UI/Rejouer.visible = true
		
	save()

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
	$Requests/Ready.request(url + "/ready?id=" + str(user_id))

func _on_server_go_pressed() -> void:
	if url != null:
		$Requests/ServerGo.request(url + "/GO")
		$PauseMenu/CanvasLayer/Menu/Lobby.visible = true
		$Lobby/Back.disabled = false

func _on_cd_spectate_timeout() -> void:
	_on_rejouer_pressed()

func _on_rejoindre_pressed() -> void:
	$Requests/Unspectate.request(url + "/unspectate?id=" + str(user_id))
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

func pause() -> void:
	$PauseMenu/CanvasLayer.visible = true
	$TitleScreen/TitleMusic.volume_db -= 8.0
	$MusicPlayer/StreamPlayer.volume_db -= 8.0

func _on_close_menu_pressed() -> void:
	$PauseMenu/CanvasLayer.visible = false
	$TitleScreen/TitleMusic.volume_db += 8.0
	$MusicPlayer/StreamPlayer.volume_db += 8.0
	
func _on_volume_down_pressed() -> void:
	$TitleScreen/TitleMusic.volume_db = clampf($TitleScreen/TitleMusic.volume_db - 2.0, VOLUME_MIN, VOLUME_MAX)
	$MusicPlayer/StreamPlayer.volume_db = clampf($MusicPlayer/StreamPlayer.volume_db - 2.0, VOLUME_MIN, VOLUME_MAX)
	$MusicPlayer/ShopMusic.volume_db = clampf($MusicPlayer/ShopMusic.volume_db - 2.0, VOLUME_MIN, VOLUME_MAX)
	$MusicPlayer/ShopMusic2.volume_db = clampf($MusicPlayer/ShopMusic2.volume_db - 2.0, VOLUME_MIN, VOLUME_MAX)

func _on_volume_up_pressed() -> void:
	$TitleScreen/TitleMusic.volume_db = clampf($TitleScreen/TitleMusic.volume_db + 2.0, VOLUME_MIN, VOLUME_MAX)
	$MusicPlayer/StreamPlayer.volume_db = clampf($MusicPlayer/StreamPlayer.volume_db + 2.0, VOLUME_MIN, VOLUME_MAX)
	$MusicPlayer/ShopMusic.volume_db = clampf($MusicPlayer/ShopMusic.volume_db + 2.0, VOLUME_MIN, VOLUME_MAX)
	$MusicPlayer/ShopMusic2.volume_db = clampf($MusicPlayer/ShopMusic2.volume_db + 2.0, VOLUME_MIN, VOLUME_MAX)

func _on_close_tutorial_pressed() -> void:
	$PauseMenu/CanvasLayer/Tutorial.visible = false

func _on_tutorial_pressed() -> void:
	$PauseMenu/CanvasLayer/Tutorial.visible = true

func _on_pause_music_toggled(toggled_on: bool) -> void:
	$MusicPlayer/StreamPlayer.stream_paused = not toggled_on
	$BackgroundParticles.pause_particles(toggled_on)

func _on_next_music_pressed() -> void:
	$MusicPlayer.next_track()
	update_rythm()

func _on_prev_music_pressed() -> void:
	$MusicPlayer.previous_track()
	update_rythm()

func _on_back_to_title_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_room.tscn")

func update_deck_skin() -> void:
	var front = cards_front[int(current_skin) - 1]
	var back
	if current_skin == "2":
		back = cards_back[1][randi_range(0, 9)]
	else:
		back = cards_back[int(current_skin) - 1]

	for i in range(1, 5):
		get_node("Deck/" + str(i)).change_skin(current_skin, front, back)
		get_node("Board/" + str(i)).change_skin(current_skin, front, back)
		
	$"Board/5".change_skin(current_skin, front, back)
	
	if not is_spectator:
		$Players/Player1.change_skin(current_skin, front, back)

func save_to_file(content):
	var file = FileAccess.open(SAVEFILE_PATH, FileAccess.WRITE)
	file.store_string(content)

func load_from_file():
	var file = FileAccess.open(SAVEFILE_PATH, FileAccess.READ)
	if file == null:
		return null
	var content = file.get_as_text()
	return content
	
func save():
	pass
	#save_to_file(JSON.stringify({"current_money" : current_money, "current_skin" : current_skin, "purchased_skins" : purchased_skins}))

func load_savefile():
	pass
	#var txt = load_from_file()
	#if txt == null:
		#return
	#var data = JSON.parse_string(txt)
	#current_money = int(data["current_money"])
	#current_skin = data["current_skin"]
	#purchased_skins = data["purchased_skins"]

func _ready() -> void:
	const NB_FRONTS = 19
	cards_back = []
	cards_front = []
	for i in range(1, NB_FRONTS + 1):
		cards_front.append(load("res://assets/cards_front/" + str(i) + ".png"))
		if i != 2:
			cards_back.append(load("res://assets/cards_back/" + str(i) + ".png"))
		else:
			cards_back.append([])
			for c in range(10):
				cards_back[1].append(load("res://assets/cards_back/" + str(i) + str(c) + ".png"))
	load_savefile()
	update_deck_skin()
	$Shop.set_fronts_copy(cards_front)
	$Shop.init_skin_list(purchased_skins, cards_back)

func _on_close_shop_pressed(equipped) -> void:
	$"Shop/CanvasLayer".visible = false
	
	if not $UI.visible:
		$TitleScreen/TitleMusic.stream_paused = false
	elif $PauseMenu/CanvasLayer/Menu/PauseMusic.button_pressed:
		$MusicPlayer/StreamPlayer.stream_paused = false
		$BackgroundParticles.pause_particles(true)
		
	$MusicPlayer/ShopMusic.stop()
	$MusicPlayer/ShopMusic2.stop()
	save()
	
	if equipped != null:
		if current_skin != purchased_skins[equipped] and user_id != null:
			$"Requests/ChangeSkin".request(url + "/changeskin?id=" + str(user_id) + "&which=" + purchased_skins[equipped])
		current_skin = purchased_skins[equipped]
		update_deck_skin()
	
	if user_id != null and old_money != current_money:
		#print("go request !")
		$"Requests/ChangeMoney".request(url + "/changemoney?id=" + str(user_id) + "&howmuch=" + str(current_money))

func _on_boutique_pressed() -> void:
	old_money = current_money
	if (current_money < 150 or in_game) and not is_spectator:
		$Shop/CanvasLayer/Invoc.disabled = true
	else:
		$Shop/CanvasLayer/Invoc.disabled = false
	
	$Shop/CanvasLayer/MoneyLeft.text = "Il te reste "+ str(current_money) + "€"
	$Shop/CanvasLayer/Equip.disabled = true
	$Shop/CanvasLayer/PulledCard.visible = false
	$Shop/CanvasLayer/PullName.visible = false
	
	$Shop/CanvasLayer.visible = true
	$TitleScreen/TitleMusic.stream_paused = true
	$MusicPlayer/StreamPlayer.stream_paused = true
	$BackgroundParticles.pause_particles(false)
	if randi_range(1, 12) == 9:
		$MusicPlayer/ShopMusic2.play()
	else:
		$MusicPlayer/ShopMusic.play()

func _on_title_music_finished() -> void:
	$TitleScreen/TitleMusic.play()

func _on_name_text_changed(new_text: String) -> void:
	if new_text == "":
		$TitleScreen/CanvasLayer/Submit.visible = false
		$TitleScreen/CanvasLayer/Play.visible = true
		return
	if not $TitleScreen/CanvasLayer/Submit.visible:
		$TitleScreen/CanvasLayer/Play.visible = false
		$TitleScreen/CanvasLayer/Submit.visible = true

func _on_submit_pressed() -> void:
	if $EnterCode/CanvasLayer/Name.visible:
		_on_name_text_submitted($EnterCode/CanvasLayer/Name.text)
	elif $EnterCode/CanvasLayer/GameCode.visible:
		_on_game_code_text_submitted($EnterCode/CanvasLayer/GameCode.text)

func _on_game_code_text_submitted(new_text: String) -> void:
	if len(new_text) != 4: return
	game_code = new_text
	$EnterCode/CanvasLayer/GameCode.visible = false
	$EnterCode/CanvasLayer/Name.visible = true
	$TitleScreen/CanvasLayer/Submit.visible = false
	$TitleScreen/CanvasLayer/Play.visible = true
	$EnterCode/CanvasLayer/Name.editable = true
	$EnterCode/CanvasLayer/Name.text = ""
	$EnterCode/CanvasLayer/Name.placeholder_text = "Ton pseudo :"

func _on_game_code_text_changed(new_text: String) -> void:
	_on_name_text_changed(new_text)

func _on_create_pressed() -> void:
	$Requests/Create.request(url0 + "/$$$$/newlobby")
	$Lobby.visible = true
	$TitleScreen/CanvasLayer/Create.disabled = true
	#print("create !")

func _on_create_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if len(ans) == 4:
		$Lobby/Code.text = "Code de la partie : " + ans
		game_code = "/" + ans
		$Requests/LobbyUpdate.request(url0 + game_code + "/lobbyupdate")
	else:
		$Lobby.visible = false
		$TitleScreen/CanvasLayer/Create.disabled = false


func _on_lobby_update_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var ans = body.get_string_from_utf8()
	if ans == "wronglobby":
		$TitleScreen/CanvasLayer/Play.disabled = false
		$EnterCode/CanvasLayer/Name.text = ""
		$EnterCode/CanvasLayer/GameCode.text = ""
		$EnterCode/CanvasLayer/Name.placeholder_text = "Ton code est faux frr"
		return
	var data = JSON.parse_string(ans)
	
	$Lobby/ItemList.clear()
	for i in range(len(data["names"])):
		if data["skins"][i] == "2":
			$Lobby/ItemList.add_item(data["names"][i], cards_back[int(data["skins"][i][0]) - 1])
		else:
			$Lobby/ItemList.add_item(data["names"][i], cards_back[int(data["skins"][i]) - 1])
	
	$Requests/LobbyUpdateTimer.start()

func _on_lobby_update_timer_timeout() -> void:
	if $Lobby.visible:
		$Requests/LobbyUpdate.request(url0 + game_code + "/lobbyupdate")

func _on_delete_player_pressed() -> void:
	if len($Lobby/ItemList.get_selected_items()) == 0:
		return
	var toKick = $Lobby/ItemList.get_item_text($Lobby/ItemList.get_selected_items()[0])
	$Requests/KickPlayer.request(url0 + game_code + "/kick?who=" + toKick)

func _on_lobby_pressed() -> void:
	$Lobby.visible = true
	$Requests/LobbyUpdate.request(url0 + game_code + "/lobbyupdate")

func _on_back_pressed() -> void:
	$Lobby.visible = false
