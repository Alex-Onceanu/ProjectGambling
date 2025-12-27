import requests     # pour ENVOYER des requêtes HTTP
import time
import json
from random import randint

# on représentera les couleurs des cartes par des entiers entre 1 et 4 ici
SPADES = 1
CLUBS = 2
HEARTS = 3
DIAMONDS = 4

# une carte. on reçoit un "HQ" et on veut le transformer en (3, 12) puis en "dame de coeur"
class Card:
    # contient juste 2 attributs : une couleur (int de [1, 4]) et une valeur (int de [2, 14]) (14 = As)
    def __init__(self, __color, __value):
        color_of_str = { "S" : SPADES, "C" : CLUBS, "H" : HEARTS, "D" : DIAMONDS }
        value_of_str = { "J" : 11, "Q" : 12, "K" : 13, "A" : 14 }
        self.color = color_of_str[__color]
        self.value = (1 + int(__value)) if __value <= '9' else value_of_str[__value]

    # un cast vers string, pratique pour print (transforme (3, 12) en "dame de coeur")
    def __str__(self):
        str_of_color = ["pique", "trèfle", "coeur", "carreau"]
        str_of_value = ["valet", "dame", "roi", "as"]

        return (str(self.value) if self.value <= 10 else str_of_value[self.value - 11]) + " de " + str_of_color[self.color - 1]

# passer de "HQSJ" à ((3, 12), (1, 11)) par exemple
def parseCards(s : str) -> tuple:
    assert(len(s) == 5)
    return (Card(s[0], s[1]), Card(s[3], s[4]))

def parseUpdate(json_str : str) -> tuple:
    if json_str == "error":
        raise ValueError("/update/ nous renvoie \"error\"")
    ans = json.loads(json_str)
    return ans["round"], ans["update"], ans["money_left"], ans["total_bet"], ans["current_blind"], ans["who_is_playing"], ans["your_bet"]

# Le client. Pour le projet final ce sera le jeu godot entier qui représentera cette classe
class Client:
    def __init__(self, __serverURL, __userName):
        # contient l'url du serveur, un nom, l'id que nous a renvoyé le serveur, 2 cartes
        self.serverURL = __serverURL
        self.userName = __userName
        self.client_id = -1
        self.card1 = None
        self.card2 = None
        self.players = []
        self.round = 0
        self.money_left = []
        self.total_bet = 0
        self.current_blind = 0
        self.who_is_playing = 0
        self.user_index = None
        self.user_bet = 0

        while True:
            try:
                # on attend que le serveur soit joignable et qu'il nous donne un id
                # print(requests.get(self.serverURL + f"/register/user?name={self.userName}", allow_redirects=True).text)
                print(" << Go ans !")
                ans = requests.get(self.serverURL + f"/register/user?name={self.userName}&skin=2&money=100", allow_redirects=True).text
                print(" << ans : ", ans)
                self.client_id = int(ans)
                break
            except Exception as e:
                print(" << Le serveur est inacessible, alex ce gros shlag a sûrement oublié de le lancer mdr : ", str(e))
                time.sleep(1)

        print(" << Mon id est " + str(self.client_id))

    def try_GET(self, parsing, req, error_msg):
        while True:
            try:
                ans = parsing(requests.get(self.serverURL + req,allow_redirects=True).text)
                return ans
            except Exception as e:
                print(f" << {error_msg} : ", str(e))
                time.sleep(1)

    # fonction "main" du client un peu
    def run(self):
        while True:
            shouldStart = ""
            print(" << On attend le feu vert du serveur")
            while not shouldStart.startswith("go!"):
                # la partie commence lorsque le serveur nous répond "go!"
                time.sleep(1)
                # Truc important à retenir : on fera en godot un peu comme ça aussi. On envoie une requête GET avec un certain url, ici "http://urlchelou/ready?id=..." pour demander au serveur si la partie a commencé
                # le serveur nous renvoie un string, qu'on récupère dans shouldStart. Ici on a juste à vérifier que ce string vaut bien "go!" pour lancer la game
                shouldStart = requests.get(self.serverURL + "/ready?id=" + str(self.client_id),allow_redirects=True).text

            data = json.loads(shouldStart[3:])
            self.players = list(filter(None, data["names"]))
            print(f" << Partie lancée ! Joueurs : {self.players}")
            self.user_index = data["offset"]         # correspond à true_i en Godot
            print(f" << mon user index vaut {self.user_index}")

            self.card1, self.card2 = self.try_GET(parseCards, f"/cards?id={self.client_id}", "Erreur dans la distribution de cartes")
            print(f" << Vos cartes : {self.card1}, {self.card2}")

            while True:
                self.round, update, self.money_left, self.total_bet, self.current_blind, self.who_is_playing, self.user_bet = self.try_GET(parseUpdate, f"/update?id={self.client_id}", "J'ai pas de nouvelles :(")
                for action in update:
                    who = action[0]
                    what = action[1]
                    print(f" << Insérer super animation pour montrer que {self.players[who]} a misé {what} !")
                if self.round >= 4:
                    break
                if self.who_is_playing == self.user_index:
                    print(f" << État actuel de la partie : mise totale : {self.total_bet}, blinde actuelle : {self.current_blind}")
                    minimal_bet = self.current_blind - self.user_bet
                    # while True:
                    #     try:
                    #         user_action = input(f" << Votre tour ! Vos cartes sont {self.card1}, {self.card2}. Vous devez miser au moins {minimal_bet}. \n << Répondez par votre mise (ou 0 pour Check, -1 pour Fold, \"quitter\" pour arrêter de jouer)\n >> ")
                    #         if user_action.startswith("quitter"):
                    #             # TODO : gérer quelqu'un qui se casse mid-game ?
                    #             break
                    #         user_action = int(user_action)
                    #         if user_action < -1:
                    #             user_action = -1
                    #         break
                    #     except:
                    #         print(" << C'est pas une mise ça, fais un effort stp")
                    #         continue
                    time.sleep(0.5)
                    user_action = str(minimal_bet)

                    if str(user_action).startswith("quitter"):
                        exit(0)     # TODO : faire ça proprement

                    if user_action == -1:
                        self.try_GET(lambda x : None, f"/fold?id={self.client_id}", "Impossible de fold wtf")
                    elif user_action == 0:
                        self.try_GET(lambda x : None, f"/check?id={self.client_id}", "Impossible de check wtf")
                    else:
                        self.try_GET(lambda x : None, f"/bet?id={self.client_id}&how_much={user_action}", f"Impossible de bet {user_action} ?")
                    print(" << Fin de tour pour moi")
                else:
                    print(f" << On attend {self.players[self.who_is_playing]}")
                
                time.sleep(1)

print(" << Bienvenue dans le prototype du projet GAMBLING !")
time.sleep(randint(500, 1500) / 1000)
# name = input(" << Veuillez entrer votre pseudo :\n >> ").strip()    # strip enlève les espaces, tabs, saut à la ligne 
name = "Bot_" + str(randint(1, 9999))
url = "http://[2a09:6847:fa10:1410::279]:8080/" + input(" << Code a 4 lettres ?\n >> ")

cl = Client(url, name)
cl.run()