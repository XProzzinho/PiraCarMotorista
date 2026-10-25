import pathlib
from PIL import Image, ImageChops, ImageDraw, ImageFilter

# Lê logo.png (na raiz) e gera: assets/logo.png e os ícones do Android.
im = Image.open("logo.png").convert("RGB")
w, h = im.size

# 1) Acha os cantos brancos (fora do quadrado arredondado)
marca = (255, 0, 255)
tmp = im.copy()
for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
    ImageDraw.floodfill(tmp, xy, marca, thresh=60)
r, g, b = tmp.split()
mask = ImageChops.multiply(
    ImageChops.multiply(r.point(lambda v: 255 if v == 255 else 0),
                        g.point(lambda v: 255 if v == 0 else 0)),
    b.point(lambda v: 255 if v == 255 else 0),
).filter(ImageFilter.MaxFilter(7))

# 2) Preenche os cantos estendendo a cor do fundo, linha por linha
px = im.load()
mk = mask.load()
vazias = []
for y in range(h):
    xs = [x for x in range(w) if mk[x, y] == 0]
    if not xs:
        vazias.append(y)
        continue
    esq, dir_ = xs[0], xs[-1]
    ce = px[min(w - 1, esq + 3), y]
    cd = px[max(0, dir_ - 3), y]
    for x in range(0, esq):
        px[x, y] = ce
    for x in range(dir_ + 1, w):
        px[x, y] = cd
cheias = [y for y in range(h) if y not in set(vazias)]
for y in vazias:
    ref = min(cheias, key=lambda c: abs(c - y))
    for x in range(w):
        px[x, y] = px[x, ref]

# 3) Logo cheia (sem cantos brancos) para a tela de login
raiz = pathlib.Path(".")
(raiz / "assets").mkdir(exist_ok=True)
im.resize((512, 512), Image.LANCZOS).save(raiz / "assets" / "logo.png")

# 4) Ícones do Android
res = raiz / "android/app/src/main/res"
legado = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
camada = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
ESCALA = 0.72

for d, tam in legado.items():
    pasta = res / f"mipmap-{d}"
    pasta.mkdir(parents=True, exist_ok=True)
    im.resize((tam, tam), Image.LANCZOS).save(pasta / "ic_launcher.png")

for d, S in camada.items():
    pasta = res / f"mipmap-{d}"
    pasta.mkdir(parents=True, exist_ok=True)
    # fundo: degradê vertical que continua o do logo
    fundo = Image.new("RGB", (S, S))
    dr = ImageDraw.Draw(fundo)
    for y in range(S):
        sy = ((y / S - 0.5) / ESCALA + 0.5) * (h - 1)
        sy = int(max(0, min(h - 1, sy)))
        dr.line([(0, y), (S, y)], fill=px[40, sy])
    fundo.save(pasta / "ic_launcher_background.png")
    # frente: logo menor, centralizado, com transparência ao redor
    lado = int(S * ESCALA)
    frente = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    logo = im.resize((lado, lado), Image.LANCZOS).convert("RGBA")
    frente.paste(logo, ((S - lado) // 2, (S - lado) // 2))
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
