"""Turn two iPhone Simulator screenshots into one transparent PNG for the website.

    python3 tools/web_screenshot.py garage.png tune.png -o suspension-tuner.png

Each screenshot gets iPhone-style rounded corners, a dark bezel and a soft shadow; the two
phones sit side by side (the second slightly lower) on a fully transparent background, so the
image blends into any page colour. Needs Pillow:  pip3 install pillow
"""
import argparse

from PIL import Image, ImageDraw, ImageFilter

PHONE_W = 760          # each phone's width in the output, px
BEZEL = 22             # bezel thickness, px
GAP = 70               # space between phones
STAGGER = 120          # second phone sits this much lower
SHADOW = 60            # shadow blur radius / margin


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def framed_phone(path):
    shot = Image.open(path).convert("RGBA")
    inner_w = PHONE_W - 2 * BEZEL
    inner_h = round(shot.height * inner_w / shot.width)
    shot = shot.resize((inner_w, inner_h), Image.LANCZOS)

    outer = (PHONE_W, inner_h + 2 * BEZEL)
    radius_outer = int(PHONE_W * 0.145)
    radius_inner = radius_outer - BEZEL

    phone = Image.new("RGBA", outer, (0, 0, 0, 0))
    body = Image.new("RGBA", outer, (24, 26, 32, 255))           # bezel colour
    phone.paste(body, (0, 0), rounded_mask(outer, radius_outer))
    # thin metallic edge
    ImageDraw.Draw(phone).rounded_rectangle((1, 1, outer[0] - 2, outer[1] - 2), radius=radius_outer,
                                            outline=(70, 76, 88, 255), width=3)
    phone.paste(shot, (BEZEL, BEZEL), rounded_mask(shot.size, radius_inner))
    return phone


def compose(paths, out):
    phones = [framed_phone(p) for p in paths]
    width = sum(p.width for p in phones) + GAP * (len(phones) - 1) + 2 * SHADOW
    height = max(p.height + i * STAGGER for i, p in enumerate(phones)) + 2 * SHADOW
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    x = SHADOW
    for i, phone in enumerate(phones):
        y = SHADOW + i * STAGGER
        # soft drop shadow (semi-transparent, so it works on light or dark pages)
        alpha = phone.split()[3].point(lambda a: int(a * 0.45))
        shadow = Image.new("RGBA", phone.size, (0, 0, 0, 0))
        shadow.putalpha(alpha)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        layer.paste(shadow, (x, y + 24), shadow)
        canvas = Image.alpha_composite(canvas, layer.filter(ImageFilter.GaussianBlur(SHADOW / 2)))
        canvas.alpha_composite(phone, (x, y))
        x += phone.width + GAP

    canvas.save(out, optimize=True)
    print(f"wrote {out} ({canvas.width}×{canvas.height}, transparent background)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("screenshots", nargs="+", help="one or more Simulator screenshots (PNG)")
    ap.add_argument("-o", "--out", default="suspension-tuner.png")
    args = ap.parse_args()
    compose(args.screenshots, args.out)
