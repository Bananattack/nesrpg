#!/bin/env python
import math
import struct
import PIL.Image
import PIL.ImageDraw

COLUMNS = 16
ROWS = 4
SQUARE_SIZE = 16

FADE_RATIOS = [0.8, 0.5, 0.33, 0.2]
FADE_STEPS = len(FADE_RATIOS)

infile = open('default_nitsuja.pal', 'rb')
pal = []
for j in range(ROWS):
    for i in range(COLUMNS):
        rgb = struct.unpack('BBB', infile.read(3))
        pal.append(rgb)
#outfile = open('default_nitsuja.png', 'wb')

# Convert a color index into its corresponding HSV value.
def getHSV(c) :
    return convertRGBtoHSV(c[0], c[1], c[2])

# Convert RGB into its corresponding HSV value.
def convertRGBtoHSV(r, g, b) :
    h = 0
    s = 0
    v = 0
    maximum = r
    delta = r
    if (g > maximum) :
        maximum = g
    elif (g < delta) :
        delta = g
    if (b > maximum) :
        maximum = b
    elif (b < delta) :
        delta = b

    delta = maximum - delta
    # Value (Brightness)
    v = maximum
    # Saturation
    if (maximum == 0) :
        s = 0
    else :
        s = (delta * 255) / maximum

    # Grey        
    if delta == 0 :
        h = 0
    # (300)magenta->(0)red->(60)yellow
    elif (r == maximum) :        
        h = (360 + ((60 * (g - b)) / delta)) % 360
    # (60)yellow->(120)green->(180)cyan
    elif (g == maximum) :
        h = (120) + ((60 * (b - r)) / delta)
    # (180)cyan->(240)blue->(300)magenta
    else :
        h = (240) + ((60 * (r - g)) / delta)
    return (h, s, v)
        
def colorDistance(a, b):
    x = (a[0] - b[0]) * 0.5
    y = (a[1] - b[1])
    z = (a[2] - b[2]) * 0.25
    hsva = getHSV(a)
    hsvb = getHSV(b)
    #h = (hsva[0] - hsvb[0])
    h = 0
    s = 0
    v = 0
    #s = (hsva[1] - hsvb[1]) * 0.2
    v = (hsva[2] - hsvb[2]) / 255.0
    #if hsva[2] < 13:
        #h = 0
    h *= (255 - hsva[1]) / 255.0
    return math.sqrt(x * x + y * y + z * z + h * h + s * s)
    
def findClosest(match, palette):
    closestDistance = None
    closestIndex = None
    for i in range(len(palette)):
        color = palette[i]
        dist = colorDistance(match, color)
        if closestDistance == None or dist < closestDistance:
            closestDistance = dist
            closestIndex = i
    return closestIndex
    
for fadeEntry in range(64):
    fadeTable = []

    image = PIL.Image.new('RGB', (COLUMNS * SQUARE_SIZE, ROWS * SQUARE_SIZE * (FADE_STEPS + 2)))
    draw = PIL.ImageDraw.Draw(image)
    
    outfile = open(('fade_%02x' % (fadeEntry, )) + '.bin', 'wb')

    DEST_COLOR = pal[fadeEntry]
    draw.rectangle((0, 0, image.size[0], image.size[1]), DEST_COLOR)        
    for j in range(ROWS):
        for i in range(COLUMNS):
            x = i * SQUARE_SIZE
            y = j * SQUARE_SIZE
            draw.rectangle((x, y, x + SQUARE_SIZE - 1, y + SQUARE_SIZE - 1), pal[j * COLUMNS + i])
        
    for step in range(FADE_STEPS):
        fadeTable.append([])
        #ratio = 1 - float(step + 1) / float(FADE_STEPS + 1)
        ratio = FADE_RATIOS[step] 
        print('; fade = ' + str(int((1 - ratio) * 100)) + '% (step ' + str(step + 1) + ')')
        for color in pal:
            #match = (color[0] * ratio, color[1] * ratio, color[2] * ratio)
            r = ratio * (color[0] - DEST_COLOR[0]) + DEST_COLOR[0]
            g = ratio * (color[1] - DEST_COLOR[1]) + DEST_COLOR[1]
            b = ratio * (color[2] - DEST_COLOR[2]) + DEST_COLOR[2]
            match = r, g, b
            fadeTable[step].append(findClosest(match, pal))
        for j in range(ROWS):
            for i in range(COLUMNS):
                x = i * SQUARE_SIZE
                y = (j + ROWS * (step + 1)) * SQUARE_SIZE
                
                index = fadeTable[step][j * COLUMNS + i]
                if index == 0x0D or index == 0x1D or index & 0xF == 0xE or index & 0xF == 0xF:
                    index = 0x0F
                elif index == 0x2D:
                    index = 0x00
                elif index == 0x3D:
                    index = 0x10
                
                outfile.write(struct.pack('B', index))
                draw.rectangle((x, y, x + SQUARE_SIZE - 1, y + SQUARE_SIZE - 1), pal[index])
                #draw.rectangle((x, y, x + SQUARE_SIZE - 1, y + SQUARE_SIZE - 1), pal[step + 1][j * COLUMNS + i])
    outfile.close()
    image.save(('pal_%02x' % (fadeEntry, )) + '.png', 'PNG')