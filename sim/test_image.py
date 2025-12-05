import png

with open("sim_build/test_renderer_list.txt", "r") as file:
    img = eval(file.read())
    
def rgb(num):
    
    b = (num % 32) * 8
    num //= 32
    g = (num % 64) * 4
    num //= 64
    r = num * 8
    return (r,g,b)

print(rgb(65280))

def create_png(tile):
    width = 1280
    height = 180
    img = []
    for y in range(height):
        row = ()
        for x in range(width):
            row = row + rgb( tile[y][x] )
        img.append(row)
    with open('result.png', 'wb') as f:
        w = png.Writer(width, height, greyscale=False)
        w.write(f, img)

create_png(img)