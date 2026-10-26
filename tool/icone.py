import pathlib
from PIL import Image

# Lê logo.png (na raiz) e gera assets/logo.png e os ícones do Android.
im = Image.open("logo.png").convert("RGB")
w, h = im.size
px = im.load()

raiz = pathlib.Path(".")
(raiz / "assets").mkdir(exist_ok=True)
im.resize((512, 512), Image.LANCZOS).save(raiz / "assets" / "logo.png")

res = raiz / "android/app/src/main/res"
legado = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
camada = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
ESCALA = 0.80

for d, tam in legado.items():
    pasta = res / f"mipmap-{d}"
    pasta.mkdir(parents=True, exist_ok=True)
    im.resize((tam, tam), Image.LANCZOS).save(pasta / "ic_launcher.png")

for d, S in camada.items():
    pasta = res / f"mipmap-{d}"
    pasta.mkdir(parents=True, exist_ok=True)
    # fundo: cores das bordas do logo esticadas (céu em cima, rio embaixo)
    fundo = Image.new("RGB", (S, S))
    for y in range(S):
        sy = int(max(0, min(h - 1, ((y / S - 0.5) / ESCALA + 0.5) * (h - 1))))
        for x in range(S):
            sx = int(max(0, min(w - 1, ((x / S - 0.5) / ESCALA + 0.5) * (w - 1))))
            fundo.putpixel((x, y), px[sx, sy])
    fundo.save(pasta / "ic_launcher_background.png")
    lado = int(S * ESCALA)
    frente = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    frente.paste(im.resize((lado, lado), Image.LANCZOS).convert("RGBA"),
                 ((S - lado) // 2, (S - lado) // 2))
    frente.save(pasta / "ic_launcher_foreground.png")

anydpi = res / "mipmap-anydpi-v26"
anydpi.mkdir(parents=True, exist_ok=True)
(anydpi / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    '</adaptive-icon>\n'
)
print("Ícones gerados com sucesso")
