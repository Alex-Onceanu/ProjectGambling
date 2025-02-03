import requests     # pour ENVOYER des requêtes HTTP
import time
import threading    # pour le multithreading

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
def parseCards(s : str) -> tuple[Card, Card]:
    assert(len(s) == 4)
    return (Card(s[0], s[1]), Card(s[2], s[3]))

# Le client. Pour le projet final ce sera le jeu godot entier qui représentera cette classe
class Client:
    def __init__(self, __serverURL, __userName):
        # contient l'url du serveur, un nom, l'id que nous a renvoyé le serveur, 2 cartes
        self.serverURL = __serverURL
        self.userName = __userName
        self.client_id = -1
        self.card1 = None
        self.card2 = None
        self.alreadySeen = []   # et la liste des messages déjà reçus

        while True:
            try:
                # on attend que le serveur soit joignable et qu'il nous donne un id
                self.client_id = int(requests.get(self.serverURL + f"/register/user?name={self.userName}").text)
                break
            except:
                print(" << Le serveur est inacessible, alex ce gros shlag a sûrement oublié de le lancer mdr")
                time.sleep(1)

        print(" << Mon id est " + str(self.client_id))

    # Le mode "messagerie". j'ai implémenté ça à la va-vite donc le code est moche
    # cette fonction va s'exécuter en parallèle de celle pour envoyer des messages, celle-ci les reçoit et les affiche
    def messenger(self):
        while True:
            # toutes les 0.5s, demande au serveur s'il y a du nouveau
            time.sleep(0.5)
            # récupère le dernier message reçu par le serveur
            namemsg = (requests.get(self.serverURL + "/messenger").text).split()
            if namemsg[0][0] == '8':
                name, msg = namemsg[0][1:], namemsg[1]
                # s'il commence par "8" (donc s'il est pas buggé en gros) et qu'il est nouveau
                if not msg in self.alreadySeen:
                    # on l'affiche et on l'ajoute aux messages déjà affichés (pour pas afficher en boucle le même message 500 fois)
                    print("\n >> " + name + " a dit : " + msg + "\n >> ", end="")
                    self.alreadySeen.append(msg)

    # fonction "main" un peu
    def run(self):
        shouldStart = ""
        print(" << On attend le feu vert du serveur")
        while shouldStart != "go!":
            # la partie commence lorsque le serveur nous répond "go!"
            time.sleep(1)
            # Truc important à retenir : on fera en godot un peu comme ça aussi. On envoie une requête GET avec un certain url, ici "http://urlchelou/ready/" pour demander au serveur si la partie a commencé
            # le serveur nous renvoie un string, qu'on récupère dans shouldStart. Ici on a juste à vérifier que ce string vaut bien "go!" pour lancer la game
            shouldStart = requests.get(self.serverURL + "/ready/").text

        print(" << Partie lancée !")

        while True:
            try:
                # on demande au serveur nos 2 cartes. 
                # Il nous répond un string de la forme "HQSJ" par exemple (pour vouloir dire reine de coeur & valet de pique)
                # on transforme ce string en 2 cartes grâce à parseCards
                self.card1, self.card2 = parseCards(requests.get(self.serverURL + f"/cards?id={self.client_id}").text)
                break
            except Exception as e:
                print(" << Erreur dans la distribution de cartes : ", str(e))
                time.sleep(1)

        print(f" << Vos cartes : {self.card1}, {self.card2}")
        print(" << Vous pouvez envoyer des messages désormais")

        # on passe au mode messagerie. on lance en parallèle la fonction qui reçoit et affiche les messages
        msgThread = threading.Thread(target=self.messenger)
        msgThread.start()

        # puis on demande en boucle à l'utilisateur d'entrer un message
        while True:
            msg = input(" >> ")
            # et on l'envoie au serveur en y joignant notre nom, via un POST
            requests.post(self.serverURL + "/messenger?name=" + str(self.userName) + "&msg=" + msg)

print(" << Bienvenue dans le prototype du projet GAMBLING !")
name = input(" << Veuillez entrer votre pseudo :\n >> ").strip()    # strip enlève les espaces, tabs, saut à la ligne avant et après un string
url = "https://" + input(" << Veuillez entrer le code de la partie que vous souhaitez rejoindre :\n >> ").strip() + ".ngrok-free.app" # on complète l'url de ngrok-free.app par le code qui a été généré par le serveur lorsque le tunneling a commencé

cl = Client(url, name)
cl.run()