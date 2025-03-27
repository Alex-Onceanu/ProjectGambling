def val_of_str(c): 
    val_of_figure = { "J" : 11, "Q" : 12, "K" : 13, "A" : 14 }
    return (1 + int(c)) if c <= '9' else val_of_figure[c]

def make_unique_by_key(l, f) -> list:
    ans = []
    fs = []
    for i in l:
        fi = f(i)
        if not fi in fs:
            fs.append(fi)
            ans.append(i)
    return ans

# Renvoie par exemple [S8, D7, S6, S5, S4] ou []
def has_straight(cards) -> list:
    cards = make_unique_by_key(cards, lambda c : val_of_str(c[1]))
    if len(cards) < 5: return []
    by_value = sorted(cards, key=(lambda c : val_of_str(c[1])), reverse=True)
    
    straight_count = 1
    prev = by_value[0]
    for i in range(1, len(by_value)):
        if straight_count >= 5:
            return by_value[i - 5 : i]
        if prev is None or val_of_str(prev[1]) - val_of_str(by_value[i][1]) == 1:
            straight_count += 1 
        else:
            straight_count = 1
            if len(by_value) - i < 5:
                return []
        prev = by_value[i]
    return by_value[i - 4 : i + 1]

def sort_by_color(cards) -> list:
    ans = [[], [], [], []]
    for c in cards:
        match c[0]:
            case "S":
                ans[0].append(c)
            case "C":
                ans[1].append(c)
            case "H":
                ans[2].append(c)
            case "D":
                ans[3].append(c)                
    return ans

# Renvoie un [[], [], [], ...] avec les cartes associées à chaque valeur
def per_value(hand) -> list:
    ans = [[] for _ in range(13)]
    for card in hand:
        ans[val_of_str(card[1]) - 2].append(card)
    ans.reverse()
    return ans

# fait en sorte que combo contienne min(5, len(hand)) cartes
# en ajoutant à combo les meilleures cartes (dans l'ordre) de hand
def fill_with(combo, hand) -> list:
    order = sorted(hand, key=(lambda c : val_of_str(c[1])), reverse=True)[:5]
    for card in order:
        if len(combo) >= 5:
            return combo
        if not (card in combo):
            combo.append(card)
    return combo

# Renvoie (x, [...]) avec str_of_combo(x) qui vaut "carte haute", "paire", "double paire", "brelan", ...
def has_multiples(hand) -> tuple:
    every_value = per_value(hand)
    sorted_multiples = sorted(every_value, key=len, reverse=True)
    best = len(sorted_multiples[0])
    if best >= 4:
        # carré
        return (7, fill_with(sorted_multiples[0], hand))
    if best == 3:
        if len(sorted_multiples) > 1 and len(sorted_multiples[1]) >= 2:
            # full house
            return (6, (sorted_multiples[0] + sorted_multiples[1])[:5])
        # brelan
        return (3, fill_with(sorted_multiples[0], hand))
    if best == 2:
        if len(sorted_multiples) > 1 and len(sorted_multiples[1]) == best:
            # double paire
            return (2, fill_with(sorted_multiples[0] + sorted_multiples[1], hand))
        # paire
        return (1, fill_with(sorted_multiples[0], hand))
    # carte haute
    return (0, fill_with([], hand))

def str_of_combo(hand) -> str:
    assert(hand >= 0 and hand < 10)
    return [
        "carte haute",
        "paire",
        "double paire",
        "brelan",
        "suite",
        "couleur",
        "main pleine",
        "carré",
        "quinte flush",
        "quinte flush royale"
    ][hand]

def poker_hand(cards : list) -> tuple:
    flush = []
    by_color = sort_by_color(cards)
    for c in by_color:
        if len(c) >= 5:
            flush = sorted(c, key=(lambda x : val_of_str(x[1])), reverse=True)
            straight = has_straight(flush)
            if straight != []:
                if straight[0][1] == 'A':
                    # quinte flush royale
                    return (9, straight)
                # quinte flush
                return (8, straight)
            flush = flush[:5]

    val, combo = has_multiples(cards)
    if val >= 6:
        # carré ou full
        return (val, combo)
    
    if flush != []:
        # couleur
        return (5, flush)
    
    straight = has_straight(cards)
    if straight != []:
        # suite
        return (4, straight)

    return (val, combo)


if __name__ == "__main__":
    assert poker_hand(["D4", "H6", "S3", "SQ", "C5", "C2", "H9"]) == (4, ["H6", "C5", "D4", "S3", "C2"])
    assert poker_hand(["SA", "CA", "HJ", "DJ", "SQ", "HQ", "S2"]) == (2, ["SA", "CA", "SQ", "HQ", "HJ"])
    assert poker_hand(["S3", "S4", "SA", "S5", "S6", "DQ", "S7"]) == (8, ["S7", "S6", "S5", "S4", "S3"])
    assert poker_hand(["S3", "S7", "SA", "S5", "S6", "DQ", "S9", "S2"]) == (5, ["SA", "S9", "S7", "S6", "S5"])
    assert poker_hand(["S3", "S4", "DA", "S5", "S6", "DQ", "C9"]) == (0, ["DA", "DQ", "C9", "S6", "S5"])
    assert poker_hand(["SA"]) == (0, ["SA"])
    assert poker_hand(["SA", "CA"]) == (1, ["SA", "CA"])
    assert poker_hand(["SA", "CA", "DA"]) == (3, ["SA", "CA", "DA"])
    assert poker_hand(["SA", "CA", "DQ", "DA", "D9", "D2", "D4", "CQ"]) == (6, ["SA", "CA", "DA", "DQ", "CQ"])
    assert poker_hand(["SA", "CA", "DA", "HA"]) == (7, ["SA", "CA", "DA", "HA"])
    assert poker_hand(["S9", "SJ", "SA", "SK", "DQ", "SQ", "DK"]) == (9, ["SA", "SK", "SQ", "SJ", "S9"])
    assert poker_hand(["HQ", "H9", "D8", "H7", "H3", "H6", "H5"]) == (5, ["HQ", "H9", "H7", "H6", "H5"])
    assert poker_hand(["HQ", "H9", "H5", "H7", "H3", "H6", "D8"]) == (5, ["HQ", "H9", "H7", "H6", "H5"])
    assert poker_hand(["DA", "S8", "H9", "H5", "H7", "H6", "D8"]) == (4, ["H9", "S8", "H7", "H6", "H5"])
    assert poker_hand(["C4", "SJ", "S7", "S6", "H8", "C9", "H7"]) == (4, ["SJ", "C9", "H8", "S7", "S6"])
    assert poker_hand(["S8", "C8", "C7", "D8", "D7", "S7", "HQ"]) == (6, ["S8", "C8", "D8", "C7", "D7"])

    # print(max([poker_hand(["S8", "C7", "D2", "C2", "HK", "S6", "C6"]), poker_hand(["S8", "C7", "D2", "C2", "HK", "SQ", "CQ"])]))

    print("Tests passés !!!")
