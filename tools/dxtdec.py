import struct, zlib, sys, numpy as np
from PIL import Image
def dec(data, w, h):
    raw = zlib.decompress(data)[8:]
    img = np.zeros((h, w, 4), np.uint8); o = 0
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            a0, a1 = raw[o], raw[o+1]; ab = int.from_bytes(raw[o+2:o+8], 'little')
            pal = [a0, a1] + ([((7-i)*a0 + i*a1)//7 for i in range(1, 7)] if a0 > a1 else [((5-i)*a0 + i*a1)//5 for i in range(1, 5)] + [0, 255])
            c0, c1, cb = struct.unpack('<HHI', raw[o+8:o+16]); o += 16
            def u(v): return np.array([((v>>11)&31)*255//31, ((v>>5)&63)*255//63, (v&31)*255//31])
            p0, p1 = u(c0), u(c1); cp = [p0, p1, (2*p0+p1)//3, (p0+2*p1)//3]
            for i in range(16):
                y, x = by + i//4, bx + i%4
                img[y, x, :3] = cp[(cb >> (2*i)) & 3]; img[y, x, 3] = pal[(ab >> (3*i)) & 7]
    return img
if __name__ == '__main__':
    p, w, h, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    Image.fromarray(dec(open(p, 'rb').read(), w, h), 'RGBA').save(out)
