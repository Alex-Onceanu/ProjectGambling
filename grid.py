# pour mettre un set de cartes dans un tableau 13x4 (sera plus pratique à charger en godot)

from PIL import Image, ImageDraw, ImageFilter
from math import sqrt

UPSCALE = 2
CARD_WIDTH = UPSCALE * 61
CARD_HEIGHT = UPSCALE * 81
offset_w = UPSCALE * 5
offset_h = UPSCALE * 7

base = Image.new(mode="RGBA", size=(offset_w + (2 * offset_w + CARD_WIDTH) * 13, offset_h + (2 * offset_h + CARD_HEIGHT) * 4))

def get_val(x):
    if x <= 8:
        return str(x + 2)
    else:
        return ["jack", "queen", "king", "ace"][x - 9]

cols = ['hearts', 'clubs', 'diamonds', 'spades']
sep = "_of_"

def dist(t1, t2):
    (a1, b1, c1, d1) = t1
    (a2, b2, c2, d2) = t2
    return sqrt((a1 - a2) ** 2 + (b1 - b2) ** 2 + (c1 - c2) ** 2)

def grey(c):
    (r, g, b, a) = c
    return abs(r - g) + abs(g - b) + abs(b - r)

for line in range(4):
    for col in range(13):
        im = Image.open('cards/' + get_val(col) + sep + cols[line] + ("" if col <= 8 or get_val(col) == "ace" else "2") + ".png")
        w, h = im.size
        im = im.crop((6, 9, w - 6, h - 9))
        im2 = im.resize((CARD_WIDTH, CARD_HEIGHT))
        
        base.paste(im2, (offset_w + col * (CARD_WIDTH + 2 * offset_w), offset_h + line * (CARD_HEIGHT + 2 * offset_h)))

width, height = base.size
pixdata = base.load()
for y in range(height):
    for x in range(width):
        if grey(pixdata[x, y]) <= 2 and dist(pixdata[x, y], (0, 0, 0, 255)) >= 250:
            pixdata[x, y] = (0, 0, 0, 0)

base.save("output.png")