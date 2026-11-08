"""Genera el ícono de MandiDog IA: una placa de collar blanca, inclinada, con su argolla
y un diente grabado en el teal de la marca.

    uv run --with pillow python tool/make_icons.py

Salidas (assets/icon/): icon.png (ícono completo), icon_foreground.png (capa frontal del
ícono adaptativo de Android, transparente) y splash.png (marca para la pantalla de arranque).
"""

from pathlib import Path

from PIL import Image, ImageDraw

TEAL = (15, 110, 115, 255)
WHITE = (255, 255, 255, 255)
STEEL = (154, 166, 173, 255)
SCALE = 4  # se dibuja grande y se reduce para suavizar bordes
OUT = Path(__file__).resolve().parents[1] / "assets" / "icon"


def tag_layer(size: int) -> Image.Image:
    """Placa con argolla y diente, centrada en un lienzo transparente de `size`."""
    s = size * SCALE
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    w, h = int(s * 0.80), int(s * 0.50)
    x0, y0 = (s - w) // 2, (s - h) // 2
    d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=int(h * 0.42), fill=WHITE)

    # Argolla perforada a la izquierda y aro partido de acero.
    r = int(h * 0.13)
    cx, cy = x0 + int(h * 0.30), y0 + h // 2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(0, 0, 0, 0))
    ring_r = int(r * 1.9)
    d.arc(
        (cx - ring_r - int(r * 1.1), cy - ring_r, cx + ring_r - int(r * 1.1), cy + ring_r),
        start=-70, end=210, fill=STEEL, width=max(4, int(r * 0.42)),
    )

    # Diente grabado: corona ancha y redondeada, muesca suave arriba, dos raíces cortas.
    tx = x0 + int(w * 0.62)
    ty = y0 + h // 2
    tw = int(h * 0.66)  # ancho de la corona
    half = tw // 2
    crown_top = ty - int(tw * 0.48)
    crown_bottom = ty + int(tw * 0.10)
    d.rounded_rectangle(
        (tx - half, crown_top, tx + half, crown_bottom), radius=int(tw * 0.30), fill=TEAL
    )
    notch = int(tw * 0.13)
    d.ellipse((tx - notch, crown_top - notch, tx + notch, crown_top + notch // 2), fill=WHITE)
    root_bottom = ty + int(tw * 0.55)
    leg = int(tw * 0.30)
    for side in (-1, 1):
        outer = tx + side * half
        inner = tx + side * int(tw * 0.08)
        pts = [(outer, crown_bottom - 2), (inner, crown_bottom - 2),
               (tx + side * int(tw * 0.18), root_bottom),
               (tx + side * (half - int(leg * 0.15)), root_bottom)]
        d.polygon(pts, fill=TEAL)
        foot = tx + side * int(tw * 0.18), tx + side * (half - int(leg * 0.15))
        lo, hi = min(foot), max(foot)
        d.ellipse((lo, root_bottom - (hi - lo) // 2, hi, root_bottom + (hi - lo) // 2), fill=TEAL)
    # Brillo del esmalte.
    d.arc(
        (tx - int(half * 0.80), crown_top + int(tw * 0.10), tx - int(half * 0.05), crown_top + int(tw * 0.55)),
        start=190, end=255, fill=WHITE, width=max(4, int(tw * 0.06)),
    )

    layer = layer.rotate(14, resample=Image.Resampling.BICUBIC, center=(s // 2, s // 2))
    return layer.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    size = 1024

    full = Image.new("RGBA", (size, size), TEAL)
    full.alpha_composite(tag_layer(size))
    full.save(OUT / "icon.png")

    # El ícono adaptativo recorta al 66 % central: la placa va reducida en ese margen.
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = tag_layer(int(size * 0.62))
    off = (size - inner.width) // 2
    fg.alpha_composite(inner, (off, off))
    fg.save(OUT / "icon_foreground.png")

    splash = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    disc = Image.new("RGBA", (size * SCALE, size * SCALE), (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse((0, 0, size * SCALE, size * SCALE), fill=TEAL)
    splash.alpha_composite(disc.resize((size, size), Image.Resampling.LANCZOS))
    splash.alpha_composite(inner, (off, off))
    splash.save(OUT / "splash.png")
    print("ícono generado en", OUT)


if __name__ == "__main__":
    main()
