#!/bin/env python
import struct
import PIL.Image

def eval_file(filename):
    f = open(filename, 'r')
    return eval(f.read(), { "__builtins__" : None }, {})

def load_palettes(palettes):
    COLUMNS = 16
    ROWS = 4
    f = open('default_nitsuja.pal', 'rb')
    colors = []
    for j in range(ROWS):
        for i in range(COLUMNS):
            rgb = struct.unpack('BBB', f.read(3))
            colors.append(rgb)
    result = []
    for palette in palettes:
        item = []
        for entry in palette:
            item.append(colors[entry])
        result.append(item)
    f.close()
    return result

def load_chr(filename, palettes):
    images = []
    rasters = []
    f = open(filename, 'rb')
    for palette in palettes:
        image = PIL.Image.new('RGB', (16384, 8))
        images.append(image)
        rasters.append(image.load())
        
    for x in range(256):
        lowPlane = struct.unpack('8B', f.read(8))
        highPlane = struct.unpack('8B', f.read(8))
        for j in range(8):
            for i in range(8):
                index = (((highPlane[j] >> (7 - i)) & 1) << 1) | ((lowPlane[j] >> (7 - i)) & 1)
                for p in range(len(palettes)):
                    rasters[p][x * 8 + i, j] = palettes[p][index]
    return images
    
def writeCHR(w, h, data, f):
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            # Copy low bits of each 8x8 chunk into the first 8x8 plane.
            for j in range(8):
                c = 0
                for i in range(8):
                    c = (c * 2) | (data[x + i, y + j] & 1)
                f.write(chr(c))
            # Copy high bits of each chunk into the second 8x8 plane.
            for j in range(8):
                c = 0
                for i in range(8):
                    c = (c * 2) | ((data[x + i, y + j] >> 1) & 1)
                f.write(chr(c))

def write_tiles(images, tiles, filename):
    # 4x4 tiles (each 16x16 pixels), repeated 4 times (each a different palette.)
    dummy = PIL.Image.new('RGB', (16 * 8, 16 * 8 * 4))
    
    tiles.extend([ [0, 0, 0, 0] for i in range(64 - len(tiles)) ])

    for p in range(4):
        for y in range(4):
            for x in range(8):
                t = tiles[y * 8 + x]
                chunk = images[p].crop((t[0] * 8, 0, t[0] * 8 + 8, 8))
                dummy.paste(chunk, (x * 16, (p * 8 + y) * 16))
                chunk = images[p].crop((t[1] * 8, 0, t[1] * 8 + 8, 8))
                dummy.paste(chunk, (x * 16 + 8, (p * 8 + y) * 16))
                chunk = images[p].crop((t[2] * 8, 0, t[2] * 8 + 8, 8))
                dummy.paste(chunk, (x * 16, (p * 8 + y) * 16 + 8))
                chunk = images[p].crop((t[3] * 8, 0, t[3] * 8 + 8, 8))
                dummy.paste(chunk, (x * 16 + 8, (p * 8 + y) * 16 + 8))
                
    dummy.save(filename, 'PNG') 
    

if __name__ == '__main__':
    import sys
    
    def main():
        if len(sys.argv) > 1:
                for arg in range(1, len(sys.argv)):
                    filename = sys.argv[arg]
                    tileset = eval_file(filename)
                    palettes = load_palettes(tileset['palettes'])
                    images = load_chr(tileset['source_chr'], palettes)
                    write_tiles(images, tileset['tiles'], tileset['dummy_png'])
                                
                print(sys.argv[0] + ': Done!')
        else:
            print('Usage: ' + sys.argv[0] + ' file [file...]')
            print('Uses a tileset description to generate metatile dummy images.')
  
    main()
