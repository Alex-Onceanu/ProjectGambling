# pour mettre un set de cartes dans un tableau 13x4 (sera plus pratique à charger en godot)

from PIL import Image, ImageDraw, ImageFilter

CARD_WIDTH = 71
CARD_HEIGHT = 95

base = Image.new(mode="RGBA", size=(CARD_WIDTH * 13, CARD_HEIGHT * 4))

def get_val(x):
    if x <= 8:
        return str(x + 2)
    else:
        return ["jack", "queen", "king", "ace"][x - 9]

cols = ['hearts', 'clubs', 'diamonds', 'spades']
sep = "_of_"

for line in range(4):
    for col in range(13):
        im = Image.open('cards/' + get_val(col) + sep + cols[line] + ".png")
        im2 = im.resize((CARD_WIDTH, CARD_HEIGHT))
        base.paste(im2, (col * CARD_WIDTH, line * CARD_HEIGHT))

base.save("output.png")