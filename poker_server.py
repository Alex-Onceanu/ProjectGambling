import http.server                  # pour RECEVOIR des requêtes HTTP
import threading                    # pour le multithreading
from urllib.parse import urlparse   # cf parse_qs
from urllib.parse import parse_qs   # pour transformer "/name?first=hamoude&last=akbar" en { "first" : "hamoude", "last" : "akbar" }
import time
from random import randint, shuffle
import ngrok                        # pour envoyer localhost ailleurs (tunneling)
import pyperclip
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
        self.stable = False             # quand stable vaut True, le tour de table s'arrête et on passe à l'étape suivante
        self.id_to_update = {}          # un update est de la forme [(1, 80), (2, CHECK), (3, 90), (4, FOLD)]
        self.money_left = []            # argent de chaque joueur dans le bon ordre
        self.total_bet = 0              # argent au centre de la table
        self.current_blind = SMALL_BLIND# mise minimale pour suivre
        self.folded_ones = []           # liste des joueurs ayant foldé

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
        print(" << Go ! Joueurs actuels :", end=" ")
        for p in self.ids:
            print(self.id_to_name[p], end=" ")
        print()

        self.deck = shuffle_deck()              # créer le deck
        self.give_personal_cards()              # distribuer des cartes

        self.inGame = True
        print(" << Les cartes ont été distribuées")

        self.play_round(0)
        print(" << Preflop fini")
        self.play_round(3)
        print(" << Flop fini")
        self.play_round(1)
        print(" << Turn fini")
        self.play_round(1)
        print(" << River fini")

    # donne 2 cartes de self.deck à chaque joueur
    def give_personal_cards(self):
        for p in self.ids:
            self.cards_per_player[p] = self.deck.pop() + self.deck.pop()

    def next_player(self):
        self.who_is_playing = (1 + self.who_is_playing) % len(self.ids)

    def bet(self, who : int, how_much : int):
        if how_much < self.current_blind:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car la blinde actuelle c'est {self.current_blind} gros naze")
            return
        if not who in self.ids:
            print(f" << Qui a invité {who} ?")
            return
        if self.ids[self.who_is_playing] != who:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car c'est le tour de {self.id_to_name[self.ids[self.who_is_playing]]}")
            return
        if self.money_left[self.who_is_playing] < how_much:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car t'as pas assez d'argent mdr cheh")
            return

        for idp in self.id_to_update.keys():
            self.id_to_update[idp].append((self.who_is_playing, how_much))
        
        self.money_left[self.who_is_playing] -= how_much
        self.total_bet += how_much

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

        print(f"{self.id_to_name[who]} folded")
        self.next_player()

    def play_round(self, nb_cards_to_add_to_board : int):
        CD = 0.1
        DURATION_PER_PLAYER = 10
        while not self.stable:
            old_who = self.who_is_playing
            print(f" << On attend {self.id_to_name[self.ids[old_who]]}")
            waited = 0.0
            while self.who_is_playing == old_who:
                time.sleep(CD)
                waited += CD
                if waited >= DURATION_PER_PLAYER:
                    self.folded(self.ids[self.who_is_playing])
                    break

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
# il est de la forme "https://<CODE>.ngrok-free.app" où CODE est ce qu'on print pour que le client le copie-colle
# pour le récupérer on fait url[8:-15] (donc on veut les charactères allant du 8ème au 15ème en partant de la fin)

ngrok_listener = ngrok.forward("localhost:" + str(PORT), authtoken="2sgDQwcgTEhjKCy8Zc0fENZUTxA_WttXEMohEf1P5iMZfkdQ")
print(f" << Partie créée (le code de la partie est dans votre presse-papiers) : \n << {ngrok_listener.url()[8:-15]}")
pyperclip.copy(ngrok_listener.url()[8:-15])

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

    # Cette méthode sera automatiquement appelée lorsque le serveur reçoit une requête GET
    # l'url reçu sera automatiquement stocké dans self.path
    def do_GET(self):
        # si on reçoit un "http://urlchelou/register/user?name=HAMOUDE" par exemple
        try:
            if self.path.startswith('/register/user'):
                parsed_url = urlparse(self.path)
                name = parse_qs(parsed_url.query)["name"][0]    # ici on récupère le str "HAMOUDE" dans la variable name
                player_id = self.gameInstance.add_player(name)  # on appelle la fonction add_player de game avec le nom reçu 

                # ces 3 lignes reviendront souvent, elles servent à "répondre" au programme qui fait la requête GET
                self.send_response(200, 'OK')
                self.end_headers()
                self.wfile.write((str(player_id)).encode())     # ici on répond str(player_id), autrement dit on renvoie l'identifiant unique du joueur qui vient de s'ajouter à la partie

            # si on reçoit un "http://urlchelou/ready", donc si quelqu'un veut nous demander si la partie a démarré
            elif self.path.startswith('/ready'):
                self.send_response(200, 'OK')
                self.end_headers()
                ans = "notready"
                if self.gameInstance.shouldStart:
                    ans = "go!" + self.gameInstance.get_all_names()
                self.wfile.write(ans.encode())
                # on lui répond "go!j1,j2,j3" ssi la variable shouldStart de game vaut True (j1 j2 et j3 sont les noms des joueurs dans le bon ordre)

            # si qlq nous demande quelles sont ses cartes
            elif self.path.startswith('/cards'):
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

                self.end_headers()
                self.wfile.write(ans.encode()) # on lui renvoie ses cartes, stockées dans le dictionnaire cards_per_player dans game (pour chaque id) (ou "notready" si la partie n'est pas lancée)
            
            elif self.path.startswith('/update'):
                parsed_url = urlparse(self.path)
                their_id = parse_qs(parsed_url.query)["id"][0]

                if not their_id in self.gameInstance.ids:
                    raise RuntimeError("C'est qui " + str(their_id) + " ?")
                
                ans = {
                    "round" : self.gameInstance.round,
                    "update" : self.gameInstance.id_to_update[their_id], 
                    "money_left" : self.gameInstance.money_left, 
                    "total_bet" : self.gameInstance.total_bet,
                    "current_blind" : self.gameInstance.current_blind,
                    "who_is_playing" : self.gameInstance.who_is_playing
                }

                self.send_response(200, 'OK')
                self.end_headers()
                self.wfile.write(json.dumps(ans).encode())

        except Exception as e:
            print(f" << Erreur dans do_GET pour la requête reçue {self.path} : {e}")
            self.send_response(400, 'NOTOK')
            self.end_headers()
            self.wfile.write("error".encode())

    # Cette fonction sera appelée à chaque fois que le serveur recevra une requête POST
    def do_POST(self):
        try:
            if self.path.startswith('/bet'):
                parsed_url = urlparse(self.path)
                their_id = parse_qs(parsed_url.query)["id"][0]
                how_much = int(parse_qs(parsed_url.query)["how_much"][0])
                self.gameInstance.bet(their_id, how_much)

            elif self.path.startswith('/fold'):
                parsed_url = urlparse(self.path)
                their_id = parse_qs(parsed_url.query)["id"][0]
                self.gameInstance.folded(their_id)
        
        except Exception as e:
            print(f" << Erreur dans do_POST pour la requête reçue {self.path} : {e}")


    def log_message(self, format, *args):
        pass

# Pour dire à notre Server de s'éxécuter et de gérer les requêtes en continu, on l'envoie à la fonction magique
# http.server.HTTPServer, qui va récupérer toutes les requêtes envoyées à localhost (mais qui auront été transférées depuis l'url sus) et les faire gérer par notre classe Server via do_GET et do_POST

handler_object = Server

httpd = http.server.HTTPServer(("localhost", PORT), handler_object)
httpd.serve_forever()

