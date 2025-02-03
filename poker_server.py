import http.server                  # pour RECEVOIR des requêtes HTTP
import threading                    # pour le multithreading
from urllib.parse import urlparse   # cf parse_qs
from urllib.parse import parse_qs   # pour transformer "/name?first=hamoude&last=akbar" en { "first" : "hamoude", "last" : "akbar" }
import time
from random import randint, shuffle
import ngrok                        # pour envoyer localhost ailleurs (tunneling)

everyColor = ['S', 'C', 'H', 'D']   # spades, clubs, hearts, diamonds
everyValue = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'J', 'Q', 'K', 'A']  # valeurs de cartes

# renvoie un deck (mélangé) de 52 cartes
# une carte est un string de 2 chars (ex : H6 = 6 de coeur, SK = roi de pique)
def shuffleDeck():
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
        self.players = {}           # associe à chaque nom de joueur un identifiant unique (int dans [1, 100])
        self.shouldStart = False    # vaut False tant que la partie n'est pas lancée
        self.inGame = False         # vaut True une fois que les cartes sont distribuées
        self.cards_per_player = {}  # associe à chaque id de joueur ses 2 cartes
        self.deck = None            # deck de la partie en cours (cf shuffleDeck)

        print(" << Classe Game initialisée.")

    # Lance la partie. Au début attend des joueurs jusqu'à la confirmation de lancer la partie
    # puis crée un deck, et distribue 2 cartes à chaque joueur
    # cette fonction sera lancée en parallèle du serveur
    def run(self):
        print(" << En attente de joueurs...")
        while not self.shouldStart:     # boucle jusqu'à ce que le serveur nous débloque
            time.sleep(1.1)
            # La partie se lance lorsque l'utilisateur (celui qui a lancé le serveur) répond "OK"
            self.shouldStart = input(" << Tapez \"OK\" pour commencer la partie.\n >> ") == "OK"

        # On affiche tous les joueurs de self.players
        # ce dictionnaire aura été rempli par Server via add_player()
        print(" << Go ! Joueurs actuels :", end=" ")
        for p in self.players.keys():
            print(p, end=" ")
        print()

        self.deck = shuffleDeck()   # créer le deck
        self.preFlop()              # distribuer des cartes

        self.inGame = True
        print("Les cartes ont été distribuées")

    # donne 2 cartes de self.deck à chaque joueur
    def preFlop(self):
        for p in self.players.values():
            self.cards_per_player[p] = self.deck.pop() + self.deck.pop()

    # ajoute un joueur à la partie (à partir de son nom), cette fonction sera appelée par Server
    def add_player(self, player : str) -> int:
        # comme 2 joueurs peuvent avoir le même nom, on attribue à chaque joueur un identifiant unique
        # on prend un entier de [1, 100], et s'il y est déja (parmi les id des joueurs) on reroll
        player_id = randint(1, 100)
        while player_id in self.players.items():
            player_id = randint(1, 100)

        self.players[player] = player_id    # on associe à ce nom de joueur l'id qu'on vient de générer
        print(f"\n << Ajouté {player} d'id {player_id} aux joueurs.\n >> ", end="")
        return player_id


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
        if self.path.startswith('/register/user'):
            parsed_url = urlparse(self.path)
            name = parse_qs(parsed_url.query)["name"][0]    # ici on récupère le str "HAMOUDE" dans la variable name
            player_id = self.gameInstance.add_player(name)  # on appelle la fonction add_player de game avec le nom reçu 

            # ces 3 lignes reviendront souvent, elles servent à "répondre" au programme qui fait la requête GET
            self.send_response(200, 'OK')
            self.end_headers()
            self.wfile.write((str(player_id)).encode())     # ici on répond str(player_id), autrement dit on renvoie l'identifiant unique du joueur qui vient de s'ajouter à la partie

        # si on reçoit un "http://urlchelou/ready", donc si quelqu'un veut nous demander si la partie a démarré
        elif self.path.startswith('/ready') and self.gameInstance.shouldStart:
            self.send_response(200, 'OK')
            self.end_headers()
            self.wfile.write("go!".encode())    # on lui répond "go!" ssi la variable shouldStart de game vaut True

        # si quelqu'un nous demande quel est le dernier message envoyé 
        elif self.path.startswith('/messenger') and len(self.msgs) >= 1:
            self.send_response(200, 'OK')
            self.end_headers()
            rep_name, rep_msg = self.msgs[-1]
            self.wfile.write(("8" + rep_name + " " + rep_msg).encode())     # on lui répond un string de la forme "8nom message" (où le message et le nom de la personne qui l'a envoyé sont séparés par un espace)

            # Pourquoi le 8 ? en fait c'est un peu une technique de gros shlag mais c'est pour qu'ensuite le client puisse vérifier que la réponse du serveur commence bien par un 8
            # genre s'il y a un bug et qu'il reçoit "<DOCTYPE=HTML>" bah comme ça commence pas par un "8" il l'ignore mdr

        elif self.gameInstance.inGame:
            # si la partie a commencé et que qlq nous demande quelles sont ses cartes
            if self.path.startswith('/cards'):
                parsed_url = urlparse(self.path)
                their_id = int(parse_qs(parsed_url.query)["id"][0])                     # on récupère son identifiant
                
                self.send_response(200, 'OK')
                self.end_headers()
                self.wfile.write(self.gameInstance.cards_per_player[their_id].encode()) # on lui renvoie ses cartes, stockées dans le dictionnaire cards_per_player dans game (pour chaque id)

    # Cette fonction sera appelée à chaque fois que le serveur recevra une requête POST
    def do_POST(self):
        # si la requête est de la forme "http://urlchelou/messenger?name=HAMOUDE&msg=sesbian_lex"
        if self.path.startswith("/messenger"):
            parsed_url = urlparse(self.path)
            msg_name = parse_qs(parsed_url.query)["name"][0]    # on récupère HAMOUDE
            msg = parse_qs(parsed_url.query)["msg"][0]          # on récupère sesbian_lex
            self.msgs.append((msg_name, msg))
            # comme c'est un POST, on renvoie rien

    def log_message(self, format, *args):
        pass


print(" << Bienvenue sur le serveur du prototype du projet GAMBLING!")

PORT = 8080

# ngrok est l'API de "tunneling" qui nous permet d'envoyer localhost sur un url un peu random mais en ligne
# pour faire ça on appelle ngrok.forward avec comme source "localhost:8080" (parce que c'est ce qu'on veut transférer)
# ça nous renvoie dans ngrok_listener.url() l'url sus où a été envoyé notre localhost
# il est de la forme "https://<CODE>.ngrok-free.app" où CODE est ce qu'on print pour que le client le copie-colle
# pour le récupérer on fait url[8:-15] (donc on veut les charactères allant du 8ème au 15ème en partant de la fin)

ngrok_listener = ngrok.forward("localhost:" + str(PORT), authtoken_from_env=True)
print(f" << Partie créée (donnez ce code aux joueurs) : \n << {ngrok_listener.url()[8:-15]}")

# Pour dire à notre Server de s'éxécuter et de gérer les requêtes en continu, on l'envoie à la fonction magique
# http.server.HTTPServer, qui va récupérer toutes les requêtes envoyées à localhost (mais qui auront été transférées depuis l'url sus) et les faire gérer par notre classe Server via do_GET et do_POST

handler_object = Server

httpd = http.server.HTTPServer(("localhost", PORT), handler_object)
httpd.serve_forever()

# pour lancer ce programme, il faut que ngrok puisse vérifier qu'on a un compte sur leur site
# donc on peut pas juste faire "python poker_server.py", il faut lui envoyer un "auth token" 
# donc il faut plutôt lancer NGROK_AUTHTOKEN=... python poker_server.py
# (en remplaçant "..." par le auth token qu'on peut trouver sur le site de ngrok après s'être créé un compte)
