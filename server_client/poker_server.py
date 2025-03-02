import http.server                  # pour RECEVOIR des requêtes HTTP
import threading                    # pour le multithreading
from urllib.parse import urlparse   # cf parse_qs
from urllib.parse import parse_qs   # pour transformer "/name?first=hamoude&last=akbar" en { "first" : "hamoude", "last" : "akbar" }
import time
from random import randint, shuffle
# import ngrok                        # pour envoyer localhost ailleurs (tunneling)
# import pyperclip
import json

INITIAL_MONEY = 100
SMALL_BLIND = 5
CHECK = 0
FOLD = -1
everyColor = ['S', 'C', 'H', 'D']   # spades, clubs, hearts, diamonds
everyValue = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'J', 'Q', 'K', 'A']  # valeurs de cartes

# renvoie un deck (mélangé) de 52 cartes
# une carte est un string de 2 chars (ex : H6 = 6 de coeur, SK = roi de pique)
def shuffle_deck():
    full_deck = []

    for c in everyColor:
        for v in everyValue:
            full_deck.append(c + v)

    shuffle(full_deck)  # merci à random.shuffle qui mélange une liste
    return full_deck

# C'est cette classe qui joue vraiment au jeu. C'est elle qui fait tous les calculs de poker et qui dit
# à qui est le tour, distribue des cartes etc..
class Game:
    def __init__(self):
        self.id_to_name = {}            # associe à chaque identifiant unique (int dans [1, 100]) le nom du joueur
        self.ids = []                   # on retient l'ordre de jeu ici
        self.shouldStart = False        # vaut False tant que la partie n'est pas lancée
        self.inGame = False             # vaut True une fois que les cartes sont distribuées
        self.cards_per_player = {}      # associe à chaque id de joueur ses 2 cartes
        self.deck = None                # deck de la partie en cours (cf shuffle_deck)
        self.board = []                 # cartes communes
        self.who_is_playing = 0         # à qui est le tour ? 
        # (!! c'est un index de self.ids : pour accéder au nom, faire self.id_to_name[self.ids[self.who_is_playing]])
        self.round = 0                  # pré-flop, flop, turn, river
        self.stable_since = 0           # quand stable vaut len(self.ids), le tour de table s'arrête eft on passe à l'étape suivante
        self.id_to_update = {}          # un update est de la forme [(1, 80), (2, CHECK), (3, 90), (4, FOLD)]
        self.money_left = []            # argent de chaque joueur dans le bon ordre
        self.total_bet = 0              # argent au centre de la table
        self.current_blind = SMALL_BLIND# mise minimale pour suivre
        self.folded_ones = []           # liste des joueurs ayant foldé
        self.id_to_bet = {}             # associe à chaque id la mise de ce joueur pour ce tour
        self.round_transition = False   # vaut True tant que Game est en train de passer d'un round à un autre 

        print(" << Classe Game initialisée.")

    """
    à chaque id, associer une liste d'updates
    dès que quelqu'un mise, mettre à jour tous les champs de id_to_update[id_tlm]
    dès que quelqu'un demande un update, lui donner son update et le remettre à []
    en pratique la pile d'updates aura rarement + d'un élément, mais on sait jamais
    genre si quelqu'un perd la connexion pendant 30s, on peut le reconnecter (ce qui est cool)
    """

    # Lance la partie. Au début attend des joueurs jusqu'à la confirmation de lancer la partie
    # puis crée un deck, et distribue 2 cartes à chaque joueur
    # cette fonction sera lancée en parallèle du serveur
    def run(self):
        print(" << En attente de joueurs...")
        while not self.shouldStart:
            # La partie se lance lorsque l'utilisateur (celui qui a lancé le serveur) répond "OK"
            self.shouldStart = input(" << Tapez \"GO\" pour commencer la partie.\n >> ") == "GO"
        
        # ce dictionnaire aura été rempli par Server via add_player()
        print(" << Go ! Joueurs actuels : ", self.ids)

        self.deck = shuffle_deck()              # créer le deck
        self.give_personal_cards()              # distribuer des cartes

        for idp in self.ids:
            self.id_to_update[idp] = []
        self.money_left = [INITIAL_MONEY] * len(self.ids)

        self.inGame = True
        print(" << Les cartes ont été distribuées")

        self.play_round(0)
        print(" << Preflop fini")
        self.play_round(3)
        print(" << Flop fini")
        self.play_round(1)
        print(" << Turn fini")
        self.play_round(1)
        print(" << River fini, FIN")
        self.round_transition = False

    # donne 2 cartes de self.deck à chaque joueur
    def give_personal_cards(self):
        for p in self.ids:
            self.cards_per_player[p] = self.deck.pop() + self.deck.pop()

    def next_player(self):
        self.who_is_playing = (1 + self.who_is_playing) % len(self.ids)

    def bet(self, who : int, how_much : int):
        if not who in self.ids:
            print(f" << Qui a invité {who} ? il est pas dans {self.ids}")
            return
        if self.ids[self.who_is_playing] != who:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car c'est le tour de {self.id_to_name[self.ids[self.who_is_playing]]}")
            return
        if how_much + self.id_to_bet[who] < self.current_blind:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car la blinde actuelle c'est {self.current_blind} gros naze")
            return
        if self.money_left[self.who_is_playing] < how_much:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car t'as pas assez d'argent mdr cheh")
            return

        for idp in self.id_to_update.keys():
            self.id_to_update[idp].append((self.who_is_playing, how_much))
        
        self.money_left[self.who_is_playing] -= how_much
        self.total_bet += how_much
        self.id_to_bet[who] += how_much

        self.last_player_to_bet = self.who_is_playing
        if self.id_to_bet[who] > self.current_blind:
            # donc c'est un raise
            self.stable_since = 1
            self.current_blind = self.id_to_bet[who]
            print(f" << {self.id_to_name[who]} a raise jusqu'à {self.current_blind}")
        else:
            # donc c'est un call
            self.stable_since += 1
            print(f" << {self.id_to_name[who]} a call jusqu'à {self.current_blind}")


        self.next_player()

    def folded(self, who):
        if not who in self.ids:
            print(f" << Qui a invité {who} ?")
            return
        if self.ids[self.who_is_playing] != who:
            print(f" << Non {self.id_to_name[who]}, tu peux pas fold car c'est le tour de {self.id_to_name[self.ids[self.who_is_playing]]}")
            return
        
        self.folded_ones.append(self.who_is_playing)

        for idp in self.id_to_update.keys():
            self.id_to_update[idp].append((self.who_is_playing, FOLD))

        print(f" << {self.id_to_name[who]} s'est couché")
        self.stable_since += 1
        self.next_player()

    def checked(self, who):
        if not who in self.ids:
            print(f" << Qui a invité {who} ?")
            return
        if self.ids[self.who_is_playing] != who:
            print(f" << Non {self.id_to_name[who]}, tu peux pas check car c'est le tour de {self.id_to_name[self.ids[self.who_is_playing]]}")
            return
        if self.id_to_bet[who] != self.current_blind:
            print(f" << Non {self.id_to_name[who]}, tu peux pas check car t'as misé que {self.id_to_bet[who]} au lieu de {self.current_blind}")
            return

        for idp in self.id_to_update.keys():
            self.id_to_update[idp].append((self.who_is_playing, CHECK))
        
        self.stable_since += 1
        print(f" << {self.id_to_name[who]} a checké")
        self.next_player()

    def reset_id_to_bet(self):
        self.id_to_bet = {}
        for i in self.ids:
            self.id_to_bet[i] = 0

    def play_round(self, nb_cards_to_add_to_board : int):
        NB_PLAYERS = len(self.ids)
        CD = 0.1
        DURATION_PER_PLAYER = 30
        self.reset_id_to_bet()
        self.current_blind = 0
        self.who_is_playing = 0

        for _ in range(nb_cards_to_add_to_board):
            self.board.append(self.deck.pop())

        if nb_cards_to_add_to_board == 0:
            print(f" << {self.id_to_name[self.ids[0]]} mise la petite blinde de {SMALL_BLIND}")
            self.bet(self.ids[0], SMALL_BLIND)
            print(f" << {self.id_to_name[self.ids[1]]} mise la grosse blinde de {2 * SMALL_BLIND}")
            self.bet(self.ids[1], 2 * SMALL_BLIND)
        
        self.stable_since = 0
        self.round_transition = False

        while self.stable_since < NB_PLAYERS:
            print(f" << stable since : {self.stable_since} / {NB_PLAYERS}")
            if self.who_is_playing in self.folded_ones:
                self.stable_since += 1
                self.next_player()
                continue
            old_who = self.who_is_playing
            print(f" << On attend {self.id_to_name[self.ids[old_who]]}")
            waited = 0.0
            while self.who_is_playing == old_who:
                time.sleep(CD)
                waited += CD
                if waited >= DURATION_PER_PLAYER:
                    self.folded(self.ids[self.who_is_playing])
                    break
        self.round_transition = True
        print(f" << On est revenus au tour de {self.id_to_name[self.ids[self.who_is_playing]]}, fin du round !")
        self.round += 1

    # ajoute un joueur à la partie (à partir de son nom), cette fonction sera appelée par Server
    def add_player(self, player : str) -> int:
        # comme 2 joueurs peuvent avoir le même nom, on attribue à chaque joueur un identifiant unique
        # on prend un entier de [1, 100], et s'il y est déja (parmi les id des joueurs) on reroll
        player_id = randint(1, 100)
        while player_id in self.ids:
            player_id = randint(1, 100)

        self.ids.append(player_id)
        self.id_to_name[player_id] = player    # on associe à cet id qu'on vient de générer le nom du joueur
        print(f"\n << Ajouté {player} d'id {player_id} aux joueurs.\n >> ", end="")
        return player_id
    
    def get_all_names(self):
        ans = ""
        for p in self.ids:
            ans += self.id_to_name[p] + ","
        return ans


print(" << Bienvenue sur le serveur du prototype du projet GAMBLING!")

PORT = 8080

# ngrok est l'API de "tunneling" qui nous permet d'envoyer localhost sur un url un peu random mais en ligne
# pour faire ça on appelle ngrok.forward avec comme source "localhost:8080" (parce que c'est ce qu'on veut transférer)
# ça nous renvoie dans ngrok_listener.url() l'url sus où a été envoyé notre localhost
# il est de la forme "http://<CODE>.ngrok-free.app" où CODE est ce qu'on print pour que le client le copie-colle
# pour le récupérer on fait url[8:-15] (donc on veut les charactères allant du 8ème au 15ème en partant de la fin)

# ngrok_listener = ngrok.forward("localhost:" + str(PORT), authtoken="2sgDQwcgTEhjKCy8Zc0fENZUTxA_WttXEMohEf1P5iMZfkdQ")
# print(f" << Partie créée (le code de la partie est dans votre presse-papiers) : \n << {ngrok_listener.url()}")
# pyperclip.copy(ngrok_listener.url()[8:-15])

game = Game()                                   # on crée une instance globale de Game
gameThread = threading.Thread(target=game.run)  # sa méthode run s'exécutera * en parallèle * de la suite
gameThread.start()

# Cette classe va gérer les requêtes reçues sur notre URL, en disant à "game" quoi faire par exemple
class Server(http.server.SimpleHTTPRequestHandler):
    gameInstance = game # en vrai comme "game" est globale on aurait pu se passer de self.gameInstance
    msgs = []           # liste de tous les messages envoyés jusqu'à présent (pour la partie messagerie après distribution des cartes)

    # tkt on s'en blc (je crois qu'on peut l'enlever sans que tout casse)
    def _set_headers(self, code):
        self.send_response(code)
        self.end_headers()

    # askip parfois le serveur refuse certaines connexions, ici on dit de tout accepter
    # fonction un peu osef
    def send_my_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("skip_zrok_interstitial", "*")
        self.end_headers()

    # Cette méthode sera automatiquement appelée lorsque le serveur reçoit une requête GET
    # l'url reçu sera automatiquement stocké dans self.path
    def do_GET(self):
        # print(" << GET Coucou j'ai reçu ", self.path)
        # si on reçoit un "http://urlchelou/register/user?name=HAMOUDE" par exemple
        try:
            if self.path.startswith('/register/user'):
                parsed_url = urlparse(self.path)
                name = parse_qs(parsed_url.query)["name"][0]    # ici on récupère le str "HAMOUDE" dans la variable name
                player_id = self.gameInstance.add_player(name)  # on appelle la fonction add_player de game avec le nom reçu 

                # ces 3 lignes reviendront souvent, elles servent à "répondre" au programme qui fait la requête GET
                self.send_response(200, 'OK')
                self.send_my_headers()
                self.wfile.write((str(player_id)).encode())     # ici on répond str(player_id), autrement dit on renvoie l'identifiant unique du joueur qui vient de s'ajouter à la partie

            # si on reçoit un "http://urlchelou/ready", donc si quelqu'un veut nous demander si la partie a démarré
            elif self.path.startswith('/ready'):
                self.send_response(200, 'OK')
                self.send_my_headers()
                ans = "notready"
                if self.gameInstance.shouldStart:
                    ans = "go!" + self.gameInstance.get_all_names()
                self.wfile.write(ans.encode())
                # on lui répond "go!j1,j2,j3" ssi la variable shouldStart de game vaut True (j1 j2 et j3 sont les noms des joueurs dans le bon ordre)

            # si qlq nous demande quelles sont ses cartes
            elif self.path.startswith('/cards'):
                # On attend que Game passe au round suivant
                while self.gameInstance.round_transition:
                    print(f" << attend 2s stp {self.path}, y'a Game qui change de round")
                    time.sleep(0.1)

                ans = "notready"

                if self.gameInstance.inGame:
                    parsed_url = urlparse(self.path)

                    if "id" in parse_qs(parsed_url.query).keys():
                        their_id = int(parse_qs(parsed_url.query)["id"][0])
                        their_cards = self.gameInstance.cards_per_player[their_id]

                        ans = f"{their_cards[0:2]},{their_cards[2:4]}"
                        for board_card in self.gameInstance.board:
                            ans += "," + board_card

                        self.send_response(200, 'OK')
                    else:
                        ans = "invalid"
                        self.send_response(400, 'NOTOK')
                else:
                    self.send_response(200, 'OK')

                self.send_my_headers()
                self.wfile.write(ans.encode()) # on lui renvoie ses cartes, stockées dans le dictionnaire cards_per_player dans game (pour chaque id) (ou "notready" si la partie n'est pas lancée)
            
            elif self.path.startswith('/update'):
                # On attend que game finisse de passer au round suivant quand même
                while self.gameInstance.round_transition:
                    print(f" << attend 2s stp {self.path}, y'a Game qui change de round")
                    time.sleep(0.1)
                parsed_url = urlparse(self.path)
                their_id = int(parse_qs(parsed_url.query)["id"][0])

                if not their_id in self.gameInstance.ids:
                    raise RuntimeError("C'est qui " + str(their_id) + " ?")
                if not their_id in self.gameInstance.id_to_update.keys():
                    raise RuntimeError(f"id {their_id} pas dans self.gameInstance.id_to_update {self.gameInstance.id_to_update.keys()}")
                if not their_id in self.gameInstance.id_to_bet.keys():
                    raise RuntimeError(f"id {their_id} pas dans self.gameInstance.id_to_update {self.gameInstance.id_to_bet.keys()}")
                
                
                ans = {
                    "round" : self.gameInstance.round,
                    "update" : self.gameInstance.id_to_update[their_id], 
                    "money_left" : self.gameInstance.money_left, 
                    "total_bet" : self.gameInstance.total_bet,
                    "current_blind" : self.gameInstance.current_blind,
                    "who_is_playing" : self.gameInstance.who_is_playing,
                    "your_bet" : self.gameInstance.id_to_bet[their_id]
                }

                self.send_response(200, 'OK')
                self.send_my_headers()
                self.wfile.write(json.dumps(ans).encode())

                self.gameInstance.id_to_update[their_id] = []

        except Exception as e:
            print(f" << Erreur dans do_GET pour la requête reçue {self.path} : {e}")
            self.send_response(400, 'NOTOK')
            self.send_my_headers()
            self.wfile.write("error".encode())

    # Cette fonction sera appelée à chaque fois que le serveur recevra une requête POST
    def do_POST(self):
        # print(" << POST Coucou j'ai reçu ", self.path)
        try:
            if not self.gameInstance.round_transition:
                if self.path.startswith('/bet'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    how_much = int(parse_qs(parsed_url.query)["how_much"][0])
                    self.gameInstance.bet(their_id, how_much)

                elif self.path.startswith('/fold'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    self.gameInstance.folded(their_id)

                elif self.path.startswith('/check'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    self.gameInstance.checked(their_id)
            else:
                print(f" << Je skip la requête {self.path} car Game est en pleine transition")
        
        except Exception as e:
            print(f" << Erreur dans do_POST pour la requête reçue {self.path} : {e}")


    def log_message(self, format, *args):
        pass

# Pour dire à notre Server de s'éxécuter et de gérer les requêtes en continu, on l'envoie à la fonction magique
# http.server.HTTPServer, qui va récupérer toutes les requêtes envoyées à localhost (mais qui auront été transférées depuis l'url sus) et les faire gérer par notre classe Server via do_GET et do_POST

handler_object = Server

httpd = http.server.HTTPServer(("localhost", PORT), handler_object)
httpd.serve_forever()

