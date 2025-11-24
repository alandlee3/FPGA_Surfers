def hex_to_rgb(hex_code):
    b = hex_code % (256)
    hex_code //= 256
    g = hex_code % 256
    hex_code //= 256
    r = hex_code

    return (r // 8) * (2**11) + (g // 4) * (2**5) + b // 8

def rgb_to_hex(num):
    
    b = (num % 32) * 8
    num //= 32
    g = (num % 64) * 4
    num //= 64
    r = num * 8
    return hex(r * (2**16) + g * (2**8) + b)

print(hex(hex_to_rgb(0xFFDE21)))