import py5

with open("sim_build/test_projector_list.txt", "r") as file:
    triangles = eval(file.read())
    

def rgb(num):
    
    b = (num % 32) * 8
    num //= 32
    g = (num % 64) * 4
    num //= 64
    r = num * 8
    return (r,g,b)

def twos_comp_16_bit(num):
    if num < 2 ** 15:
        return num
    else:
        return num - 2 ** 16

def to_triangle(num):
    depth = num % (2 ** 16)
    num //= 2 ** 16

    p3y = twos_comp_16_bit(num % (2 ** 16))
    num //= 2 ** 16
    p3x = twos_comp_16_bit(num % (2 ** 16))
    num //= 2 ** 16
    p2y = twos_comp_16_bit(num % (2 ** 16))
    num //= 2 ** 16
    p2x = twos_comp_16_bit(num % (2 ** 16))
    num //= 2 ** 16
    p1y = twos_comp_16_bit(num % (2 ** 16))
    num //= 2 ** 16
    p1x = twos_comp_16_bit(num % (2 ** 16))
    num //= 2 ** 16

    color = rgb(num % (2 ** 16))

    return ((p1x, p1y), (p2x, p2y), (p3x, p3y), color, depth)


scale = 1
def setup():
    py5.size(1280 * scale, 720 * scale)
    py5.background(255)

    triangles_dupe = [to_triangle(triangle) for triangle in triangles]
    triangles_dupe = sorted(triangles_dupe, key=lambda x : -x[4])

    for triangle in triangles_dupe:
        (p1, p2, p3, color, _) = triangle
        py5.fill(*color)
        py5.no_stroke()

        print(p1, p2, p3, color)
        py5.triangle(p1[0] * scale, p1[1] * scale, p2[0] * scale, p2[1] * scale, p3[0] * scale, p3[1] * scale)

def draw():
    pass

py5.run_sketch()

