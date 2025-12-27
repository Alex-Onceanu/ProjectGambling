import http.server                  # pour RECEVOIR des requêtes HTTP
import threading                    # pour le multithreading
from urllib.parse import urlparse   # cf parse_qs
from urllib.parse import parse_qs   # pour transformer "/name?first=hamoude&last=akbar" en { "first" : "hamoude", "last" : "akbar" }
import time
from random import randint, shuffle
import json

from combos import poker_hand, str_of_combo, val_of_str

INITIAL_MONEY = 100
SMALL_BLIND = -3
BIG_BLIND = -4
CHECK = 0
FOLD = -1
TIMEOUT = -2
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
        self.stable_since = 0           # quand stable vaut len(self.ids), le tour de table s'arrête et on passe à l'étape suivante
        self.id_to_update = {}          # un update est de la forme [(1, 80), (2, CHECK), (3, 90), (4, FOLD)]
        self.money_left = []            # argent de chaque joueur dans le bon ordre
        self.total_bet = 0              # argent au centre de la table
        self.current_blind = 10         # mise minimale pour suivre
        self.folded_ones = []           # liste des joueurs ayant foldé
        self.id_to_bet = {}             # associe à chaque id la mise de ce joueur pour ce tour
        self.round_transition = False   # vaut True tant que Game est en train de passer d'un round à un autre 
        self.spectators = []            # ceux qui regardent la game sans y jouer
        self.did_timeout = []           # ceux qui vont devenir specateurs en fin de manche
        self.last_showdown = {}         # en fin de partie, on remplit ce dictionnaire avec tout ce qu'il faut
        self.nb_players = 0             # len(self.ids)
        self.combo_per_player = {}      # { i : poker_hand(cards_per_player[i] + self.board) for i in self.ids }
        self.nb_skippable = 0
        self.dealer = 0
        self.id_to_skin = {}
        self.spectator_to_money = {}
        self.shouldRun = True
        self.latestUpdateTime = time.time()

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
        while self.shouldRun:
            self.latestUpdateTime = time.time()
            self.inGame = False
            print(" << En attente de joueurs...")
            self.shouldStart = False
            while not self.shouldStart:
                # La partie se lance lorsque l'utilisateur (celui qui a lancé le serveur) répond "OK"
                # self.shouldStart = input(" << Tapez \"GO\" pour commencer la partie.\n >> ") == "GO"
                time.sleep(0.5)
        
            self.round = 0
            self.id_to_bet = {}
            self.who_is_playing = self.dealer
            self.nb_skippable = 0
            
            print(" << Go ! Joueurs actuels : ", self.ids)

            self.deck = shuffle_deck()              # créer le deck
            self.give_personal_cards()              # distribuer des cartes

            for idp in self.ids:
                self.id_to_update[idp] = []

            self.inGame = True
            print(" << Les cartes ont été distribuées")

            for nbca in [0, 3, 1, 1]:
                self.play_round(nbca)
                if len(self.folded_ones) + 1 >= self.nb_players:
                    break

            self.round_transition = True
            self.round = 4

            self.showdown()
            self.round_transition = False
            self.dealer = (1 + self.dealer) % len(self.ids)

    def kickPlayer(self, name : str):
        for idp in self.id_to_name.keys():
            if name == self.id_to_name[idp]:
                if idp in self.ids:
                    self.ids.remove(idp)
                elif idp in self.spectators:
                    self.spectators.remove(idp)
                self.nb_players -= 1

    def showdown(self):
        hand_per_player = [poker_hand([self.cards_per_player[p][:2], self.cards_per_player[p][2:4]] + self.board) for p in self.ids]
        who_didnt_fold = [i for i in range(self.nb_players) if not i in self.folded_ones]
        print(f" << hand per player : {hand_per_player}\n << who didnt fold : {who_didnt_fold}")
        
        all_winners = []
        if who_didnt_fold != []:
            winner = max(who_didnt_fold, key=(lambda i : (hand_per_player[i][0], list(map(lambda j : val_of_str(j[1]), hand_per_player[i][1])))))
            print(f" << winner : {winner}")

            winner_values = [val_of_str(h[1]) for h in hand_per_player[winner][1]]
            all_winners = [winner]
            for i in range(self.nb_players):
                if i != winner and hand_per_player[i][0] == hand_per_player[winner][0] and not i in self.folded_ones:
                    values = [val_of_str(h[1]) for h in hand_per_player[i][1]]
                    if values == winner_values:
                        all_winners.append(i)

            print(f" << all winners : {all_winners}")
            
            reward = round(self.total_bet / len(all_winners))
            for w in all_winners:
                self.money_left[w] += reward
                print(f" << Youpi gg {self.id_to_name[self.ids[w]]} tu as désormais {self.money_left[w]}$")
                if w in self.did_timeout:
                    print(" << et meme que je t'enleve des did_timeout")
                    self.did_timeout.remove(w)

        self.total_bet = 0
        self.money_left = [self.money_left[i] for i in range(len(self.money_left)) if i not in self.did_timeout]

        self.last_showdown = {
            "winners" : all_winners,
            "money_left" : self.money_left,
            "cards" : [f"{self.cards_per_player[p][0:2]},{self.cards_per_player[p][2:4]}" for p in self.ids],
            "hand_per_player" : [str_of_combo(co[0]) for co in hand_per_player],
            "reward" : reward
        }
    
        which_id_did_timeout = [self.ids[i] for i in self.did_timeout]
        for p in range(len(which_id_did_timeout)):
            self.spectators.append(which_id_did_timeout[p])
            self.ids.remove(which_id_did_timeout[p])
            self.nb_players -= 1

        self.did_timeout = []
        self.folded_ones = []

    # donne 2 cartes de self.deck à chaque joueur
    def give_personal_cards(self):
        self.board = []
        for p in self.ids:
            self.cards_per_player[p] = self.deck.pop() + self.deck.pop()
            self.combo_per_player[p] = poker_hand([self.cards_per_player[p][:2], self.cards_per_player[p][2:4]] + self.board)

    def next_player(self):
        self.who_is_playing = (1 + self.who_is_playing) % len(self.ids)

    def bet(self, who : int, how_much : int):
        print(f" << {who} veut bait {how_much} c'est le tour de {self.who_is_playing}")
        if not who in self.ids:
            print(f" << Qui a invité {who} ? il est pas dans {self.ids}")
            return
        if self.ids[self.who_is_playing] != who:
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car c'est le tour de {self.id_to_name[self.ids[self.who_is_playing]]}")
            return

        bet_for_update = how_much
        if how_much == SMALL_BLIND:
            how_much = 5
        elif how_much == BIG_BLIND:
            how_much = 10
        
        if self.money_left[self.who_is_playing] <= how_much:
            print(f" << {self.id_to_name[who]} choisit de ALL-IN")
            how_much = self.money_left[self.who_is_playing]
            self.did_timeout.append(self.who_is_playing)
            self.nb_skippable += 1
        
        elif (how_much + self.id_to_bet[who] < self.current_blind) or (how_much + self.id_to_bet[who] > self.current_blind and how_much < BIG_BLIND):
            print(f" << Non {self.id_to_name[who]}, tu peux pas miser car la blinde actuelle c'est {self.current_blind} et t'as mis {how_much} gros naze")
            return

        for idp in self.id_to_update.keys():
            self.id_to_update[idp].append((self.who_is_playing, bet_for_update))
        
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

    def folded(self, who, fold_or_timeout = FOLD):
        if not who in self.ids:
            print(f" << Qui a invité {who} ?")
            return
        if self.ids[self.who_is_playing] != who:
            print(f" << Non {self.id_to_name[who]}, tu peux pas fold car c'est le tour de {self.id_to_name[self.ids[self.who_is_playing]]}")
            return
        if len(self.folded_ones) + 1 == len(self.ids):
            print(f" << Non {self.id_to_name[who]}, tu peux pas fold car t'es le dernier en lice t'as gagné")
            return
        
        self.folded_ones.append(self.who_is_playing)
        self.nb_skippable += 1

        for idp in self.id_to_update.keys():
            self.id_to_update[idp].append((self.who_is_playing, fold_or_timeout))

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
        for i in self.spectators:
            self.id_to_bet[i] = 0

    def cards_id_for_vfx(self, player_id : int) -> list:
        combo_to_nb_cards = [1, 2, 4, 3, 5, 5, 5, 4, 5, 5]
        combo, cards = self.combo_per_player[player_id]
        cards_in_combo = cards[:combo_to_nb_cards[combo]]

        ans = []
        for i in range(len(self.board)):
            if self.board[i] in cards_in_combo:
                ans.append(i)
        # board : 0,1,2,3,4 ; hand : 5,6
        if self.cards_per_player[player_id][:2] in cards_in_combo:
            ans.append(5)
        if self.cards_per_player[player_id][2:4] in cards_in_combo:
            ans.append(6)

        return ans

    def play_round(self, nb_cards_to_add_to_board : int):
        self.nb_players = len(self.ids)
        CD = 0.1
        DURATION_PER_PLAYER = 40
        self.reset_id_to_bet()
        self.current_blind = 0
        self.who_is_playing = self.dealer
        self.next_player()

        for _ in range(nb_cards_to_add_to_board):
            self.board.append(self.deck.pop())
        
        for p in self.ids:
            self.combo_per_player[p] = poker_hand([self.cards_per_player[p][:2], self.cards_per_player[p][2:4]] + self.board)

        if nb_cards_to_add_to_board == 0:
            print(f" << {self.id_to_name[self.ids[(self.dealer + 1) % self.nb_players]]} mise la petite blinde de {SMALL_BLIND}")
            self.bet(self.ids[(self.dealer + 1) % self.nb_players], SMALL_BLIND)
            print(f" << {self.id_to_name[self.ids[(self.dealer + 2) % self.nb_players]]} mise la grosse blinde de {BIG_BLIND}")
            self.bet(self.ids[(self.dealer + 2) % self.nb_players], BIG_BLIND)
    
        self.stable_since = 0
        self.round_transition = False

        while self.stable_since < self.nb_players:
            print(f" << stable since : {self.stable_since} / {self.nb_players}")
            if self.who_is_playing in self.folded_ones or self.money_left[self.who_is_playing] <= 0:
                if len(self.ids) == self.nb_skippable or len(self.ids) == self.nb_skippable + 1:
                    time.sleep(0.5)
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
                    self.did_timeout.append(self.who_is_playing)
                    self.nb_skippable += 1
                    self.folded(self.ids[self.who_is_playing], TIMEOUT)
                    break
        self.round_transition = True
        print(f" << On est revenus au tour de {self.id_to_name[self.ids[self.who_is_playing]]}, fin du round !")
        self.round += 1

    # ajoute un joueur à la partie (à partir de son nom), cette fonction sera appelée par Server
    def add_player(self, player : str, skin="1", money=100) -> int:
        # comme 2 joueurs peuvent avoir le même nom, on attribue à chaque joueur un identifiant unique
        # on prend un entier de [1, 100], et s'il y est déja (parmi les id des joueurs) on reroll
        player_id = randint(1000, 9999)
        while player_id in self.ids or player_id in self.spectators:
            player_id = randint(1000, 9999)

        self.id_to_skin[player_id] = skin

        if self.inGame:
            self.spectators.append(player_id)
            self.id_to_name[player_id] = player    # on associe à cet id qu'on vient de générer le nom du joueur
            print(f"\n << Ajouté {player} d'id {player_id} aux spectateurs.\n >> ", end="")
            self.id_to_update[player_id] = [(0, 0)]
            self.id_to_bet[player_id] = 0
            self.spectator_to_money[player_id] = int(money)
        else:
            self.ids.append(player_id)
            self.money_left.append(int(money))
            self.id_to_name[player_id] = player    # on associe à cet id qu'on vient de générer le nom du joueur
            print(f"\n << Ajouté {player} d'id {player_id} aux joueurs.\n >> ", end="")
            self.nb_players += 1
        return player_id
    
    def get_all_names(self):
        return [self.id_to_name[p] for p in self.ids]

    def get_all_spectators(self):
        return [self.id_to_name[p] for p in self.spectators]
    
    def get_all_skins(self):
        return [self.id_to_skin[p] for p in self.ids]
    
    def get_all_spectators_skins(self):
        return [self.id_to_skin[p] for p in self.spectators]
    
    def get_offset(self, who):
        if not who in self.ids:
            return -1
        return self.ids.index(who)
    
    def change_skin(self, who, skin):
        if not who in self.ids:
            return
        self.id_to_skin[who] = skin
        i = self.ids.index(who)
        for idp in self.id_to_update.keys():
            if idp != who:
                self.id_to_update[idp].append((i, -5, skin))

    def update_money(self, who, how_much : int):
        if not who in self.ids:
            print(f" >> Qui est {who} ? ")
            return
        print(f"who = {who}, how much = {how_much}")
        i = self.ids.index(who)
        if who in self.ids and (self.inGame or self.money_left[i] <= how_much):
            print(f"Nah je suis en self.ingame={self.inGame} et self.money_left[i] = {self.money_left}")
            return
        if who in self.spectators:
            print(" << T'es spectateur frero")
            if self.spectator_to_money[who] > how_much:
                self.spectator_to_money[who] = how_much
            return
        
        print(f"Ok {who} tu as desormais {how_much}")
        self.money_left[i] = how_much

    def unspectate(self, who):
        if not who in self.spectators or self.inGame:
            return
        self.spectators.remove(who)
        self.ids.append(who)
        if not who in self.spectator_to_money.keys() or self.spectator_to_money[who] <= 0:
            self.spectator_to_money[who] = 100
        self.money_left.append(self.spectator_to_money[who])
        self.spectator_to_money.pop(who)
        print(f"\n << Ajouté {self.id_to_name[who]} d'id {who} aux joueurs.\n >> ", end="")
        self.nb_players += 1


print(" << Bienvenue sur le serveur du prototype du projet GAMBLING!")

gameInstances = {}
gameThreads = {}

# Cette classe va gérer les requêtes reçues sur notre URL, en disant à "game" quoi faire par exemple
class Server(http.server.SimpleHTTPRequestHandler):
    def _set_headers(self, code):
        self.send_response(code)
        self.end_headers()

    # askip parfois le serveur refuse certaines connexions, ici on dit de tout accepter
    def send_my_headers(self, length : int):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(length))
        # self.send_header("skip_zrok_interstitial", "*")
        self.end_headers()

    def new_game(self, code : str) -> int:
        if len(code) != 4 or code in gameInstances.keys(): return -1
        gameInstances[code] = Game()
        gameThreads[code] = threading.Thread(target=gameInstances[code].run)
        gameThreads[code].start()
        return 0
    
    def randomLobbyName(self) -> str:
        return chr(ord('A') + randint(0, 25))\
             + chr(ord('A') + randint(0, 25))\
             + chr(ord('A') + randint(0, 25))\
             + chr(ord('A') + randint(0, 25))

    # Cette méthode sera automatiquement appelée lorsque le serveur reçoit une requête GET
    # l'url reçu sera automatiquement stocké dans self.path
    def do_GET(self):
        currCode = self.path[1:5]
        if currCode != "$$$$":
            if not currCode in gameInstances.keys():
                print(" << Unknown lobby " + currCode)
                self.send_response(200, 'OK')
                self.send_my_headers(len("wronglobby"))
                self.wfile.write("wronglobby".encode())
                return
            currGame = gameInstances[currCode]
        self.path = self.path[5:]
        # print(" << GET Coucou j'ai reçu ", self.path)
        # si on reçoit un "http://urlchelou/register/user?name=HAMOUDE" par exemple
        try:
            if self.path.startswith('/register/user'):
                parsed_url = urlparse(self.path)
                name = parse_qs(parsed_url.query)["name"][0]    # ici on récupère le str "HAMOUDE" dans la variable name
                skin = parse_qs(parsed_url.query)["skin"][0]
                money = parse_qs(parsed_url.query)["money"][0]
                player_id = currGame.add_player(name, skin, int(money))  # on appelle la fonction add_player de game avec le nom reçu 
                # print(" << player id : ", player_id)
                # ces 3 lignes reviendront souvent, elles servent à "répondre" au programme qui fait la requête GET
                self.send_response(200, 'OK')
                self.send_my_headers(4)
                self.wfile.write((str(player_id)).encode())     # ici on répond str(player_id), autrement dit on renvoie l'identifiant unique du joueur qui vient de s'ajouter à la partie

            # si on reçoit un "http://urlchelou/ready", donc si quelqu'un veut nous demander si la partie a démarré
            elif self.path.startswith('/ready'):
                parsed_url = urlparse(self.path)
                their_id = int(parse_qs(parsed_url.query)["id"][0])
                ans = "notready"
                if currGame.shouldStart:
                    data = {"names" : currGame.get_all_names(),
                            "skins" : currGame.get_all_skins(),
                            "offset": currGame.get_offset(their_id)}
                    ans = "go!" + json.dumps(data)
                
                if their_id in currGame.spectators:
                    ans = "spectator" + ans

                self.send_response(200, 'OK')
                self.send_my_headers(len(ans))
                self.wfile.write(ans.encode())
                # on lui répond "go!j1,j2,j3" ssi la variable shouldStart de game vaut True (j1 j2 et j3 sont les noms des joueurs dans le bon ordre)

            elif self.path.startswith('/newlobby'):
                lobbyName = self.randomLobbyName()
                while lobbyName in gameInstances.keys():
                    lobbyName = self.randomLobbyName()
                gameInstances[lobbyName] = Game()
                gameThreads[lobbyName] = threading.Thread(target=gameInstances[lobbyName].run)
                gameThreads[lobbyName].start()
                self.send_response(200, 'OK')
                self.send_my_headers(4)
                self.wfile.write(lobbyName.encode())

            elif self.path.startswith('/lobbyupdate'):
                data = {"names" : currGame.get_all_names() + currGame.get_all_spectators(),
                        "skins" : currGame.get_all_skins() + currGame.get_all_spectators_skins()}
                ans = json.dumps(data)

                self.send_response(200, 'OK')
                self.send_my_headers(len(ans))
                self.wfile.write(ans.encode())

            elif self.path.startswith('/kick'):
                parsed_url = urlparse(self.path)
                their_name = parse_qs(parsed_url.query)["who"][0]
                currGame.kickPlayer(their_name)

                self.send_response(200, 'OK')
                self.send_my_headers(2)
                self.wfile.write("ok".encode())

            elif not currGame.round_transition:
                # si qlq nous demande quelles sont ses cartes
                if self.path.startswith('/cards'):
                    ans = "notready"

                    if currGame.inGame:
                        parsed_url = urlparse(self.path)

                        if "id" in parse_qs(parsed_url.query).keys():
                            their_id = int(parse_qs(parsed_url.query)["id"][0])
                            if not their_id in currGame.spectators:
                                their_cards = currGame.cards_per_player[their_id]

                                ans = f"{their_cards[0:2]},{their_cards[2:4]}"
                                for board_card in currGame.board:
                                    ans += "," + board_card
                            else:
                                ans = ""
                                if len(currGame.board) > 0:
                                    ans = currGame.board[0]
                                    for board_card in currGame.board[1:]:
                                        ans += "," + board_card

                            self.send_response(200, 'OK')
                        else:
                            ans = "invalid"
                            self.send_response(400, 'NOTOK')
                    else:
                        self.send_response(200, 'OK')

                    self.send_my_headers(len(ans))
                    self.wfile.write(ans.encode()) # on lui renvoie ses cartes, stockées dans le dictionnaire cards_per_player dans game (pour chaque id) (ou "notready" si la partie n'est pas lancée)
                
                elif self.path.startswith('/update'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])

                    if not their_id in currGame.ids and not their_id in currGame.spectators:
                        print(" << c'est qui " + str(their_id) + " ?")
                        self.send_response(200, 'OK')
                        self.send_my_headers(6)
                        self.wfile.write("GETOUT".encode())
                        return
                    if not their_id in currGame.id_to_update.keys():
                        raise RuntimeError(f"id {their_id} pas dans currGame.id_to_update {currGame.id_to_update.keys()}")
                    if not their_id in currGame.id_to_bet.keys():
                        raise RuntimeError(f"id {their_id} pas dans currGame.id_to_update {currGame.id_to_bet.keys()}")
                    
                    ans = {
                        "round" : currGame.round,
                        "update" : currGame.id_to_update[their_id], 
                        "money_left" : currGame.money_left, 
                        "total_bet" : currGame.total_bet,
                        "current_blind" : currGame.current_blind,
                        "who_is_playing" : currGame.who_is_playing,
                        "your_bet" : currGame.id_to_bet[their_id]
                    }

                    self.send_response(200, 'OK')
                    jj = json.dumps(ans)
                    self.send_my_headers(len(jj))
                    self.wfile.write(jj.encode())

                    currGame.id_to_update[their_id] = []

                elif self.path.startswith('/showdown'):
                    parsed_url = urlparse(self.path)
                    self.send_response(200, 'OK')
                    jj = json.dumps(currGame.last_showdown)
                    self.send_my_headers(len(jj))
                    self.wfile.write(jj.encode())
                
                elif self.path.startswith('/vfx'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    
                    cl = currGame.cards_id_for_vfx(their_id)
                    self.send_response(200, 'OK')
                    jj = json.dumps(cl)
                    self.send_my_headers(len(jj))
                    self.wfile.write(jj.encode())
                
                ans = "ok"
                if self.path.startswith('/bet'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    how_much = int(parse_qs(parsed_url.query)["how_much"][0])
                    currGame.bet(their_id, how_much)
                    self.send_response(200, 'OK')
                    jj = json.dumps(ans)
                    self.send_my_headers(len(jj))
                    self.wfile.write(jj.encode())

                elif self.path.startswith('/fold'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    currGame.folded(their_id)
                    self.send_response(200, 'OK')
                    jj = json.dumps(ans)
                    self.send_my_headers(len(jj))
                    self.wfile.write(jj.encode())

                elif self.path.startswith('/check'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    currGame.checked(their_id)
                    self.send_response(200, 'OK')
                    jj = json.dumps(ans)
                    self.send_my_headers(len(jj))
                    self.wfile.write(jj.encode())

                elif self.path.startswith('/unspectate'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    currGame.unspectate(their_id)
                    self.send_response(200, 'OK')
                    self.send_my_headers(2)
                    self.wfile.write(("ok" if not currGame.inGame else "no").encode())

                elif self.path.startswith('/changeskin'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    skin = parse_qs(parsed_url.query)["which"][0]
                    currGame.change_skin(their_id, skin)
                    self.send_response(200, 'OK')
                    self.send_my_headers(2)
                    self.wfile.write("ok".encode())

                elif self.path.startswith('/changemoney'):
                    print(" << CHANGE MONEY !!")
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    value = int(parse_qs(parsed_url.query)["howmuch"][0])
                    currGame.update_money(their_id, value)
                    self.send_response(200, 'OK')
                    self.send_my_headers(2)
                    self.wfile.write("ok".encode())

                elif self.path.startswith('/GO'):
                    currGame.shouldStart = len(currGame.ids) > 1
                    parsed_url = urlparse(self.path)
                    self.send_response(200, 'OK')
                    self.send_my_headers(5)
                    self.wfile.write("okbro".encode())
            else:
                print(f" << Je skip la requête {self.path} car Game est en pleine transition")
                self.send_response(200, 'OK')
                self.send_my_headers(len("transition"))
                self.wfile.write("transition".encode())

        except Exception as e:
            print(f" << Erreur dans do_GET pour la requête reçue {self.path} : {e}")
            self.send_response(400, 'NOTOK')
            self.send_my_headers(5)
            self.wfile.write("error".encode())

    # Cette fonction sera appelée à chaque fois que le serveur recevra une requête POST
    def do_POST(self):
        currCode = self.path[1:5]
        currGame = gameInstances[currCode]
        self.path = self.path[5:]
        # print(" << POST Coucou j'ai reçu ", self.path)
        try:
            if not currGame.round_transition:
                if self.path.startswith('/bet'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    how_much = int(parse_qs(parsed_url.query)["how_much"][0])
                    currGame.bet(their_id, how_much)

                elif self.path.startswith('/fold'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    currGame.folded(their_id)

                elif self.path.startswith('/check'):
                    parsed_url = urlparse(self.path)
                    their_id = int(parse_qs(parsed_url.query)["id"][0])
                    currGame.checked(their_id)
            else:
                print(f" << Je skip la requête {self.path} car Game est en pleine transition")
        
        except Exception as e:
            print(f" << Erreur dans do_POST pour la requête reçue {self.path} : {e}")

    def log_message(self, format, *args):
        pass


def removeDeadGames():
    t = time.time()
    for k in gameInstances.keys():
        if t - gameInstances[k].latestUpdateTime > 20 * 60:
            gameInstances.pop(k)
            gameThreads[k].shouldRun = False
            gameThreads.pop(k)
    time.sleep(60)

killerThread = threading.Thread(target=removeDeadGames)
killerThread.start()

# Pour dire à notre Server de s'éxécuter et de gérer les requêtes en continu, on l'envoie à la fonction magique
# http.server.HTTPServer, qui va récupérer toutes les requêtes envoyées à localhost (mais qui auront été transférées depuis l'url sus) et les faire gérer par notre classe Server via do_GET et do_POST

handler_object = Server

PORT = 8080
httpd = http.server.HTTPServer(("localhost", PORT), handler_object)
httpd.serve_forever()
