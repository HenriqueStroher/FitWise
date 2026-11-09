"""
baixar_imagens_everkinetic.py — FitWise TCC UNISINOS

Copia as ilustrações dos exercícios de musculação de um clone do Everkinetic
(https://github.com/everkinetic/data, CC BY-SA 4.0) para app/assets/images,
já no formato do app: <slug>-1.webp e <slug>-2.webp, fundo branco.

O Everkinetic tem duas versões de cada ilustração:
  - src/images-web/<slug>-1.png e -2.png: traço fino, a mesma origem das
    imagens que o app já usava. É a versão padrão.
  - src/exercises/<NNNN>/<NNNN>-relaxation.png e -tension.png: redesenho com
    traço mais grosso. Usada quando a versão web não existe ou está errada
    (ver USAR_SRC).

Uso:
    python baixar_imagens_everkinetic.py <clone_everkinetic> [slug ...] [--substituir] [--aplicar]

Sem slugs, processa os exercícios de gerar_base_appgym.py que ainda não têm
imagem no app. Com slugs, só os informados. Imagens que já existem só são
sobrescritas com --substituir. Sem --aplicar, só relata o que faria.
"""

import glob
import json
import os
import sys

from PIL import Image

from gerar_base_appgym import EXERCICIOS_SELECIONADOS, EXERCICIOS_SEM_REGISTRO

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PASTA_APP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "app", "assets", "images")

# Mesmos parâmetros de converter_imagens_webp.py
QUALIDADE = 90
METODO = 6
# As imagens web têm 960 px de altura; o redesenho é maior e é reduzido a isso
LADO_MAXIMO = 960

# Exercícios cuja versão web está errada ou é pior que o redesenho:
USAR_SRC = {
    # Na fonte, os três PNGs web mostram outro exercício (flexão com os pés
    # na bola). Era a imagem errada do "Levantamento Terra no Smith".
    "t-bar-rows",
    "smith-machine-dead-lifts",
    "smith-machine-incline-bench-press",
    # A versão web mostra banco inclinado; o exercício é no banco reto
    "dumbbell-flys",
    "bench-press-dumbbell",
    "flat-bench-cable-flys",
    # A versão web é outra rosca (em pé, apoiado no banco), não a inclinada
    "incline-inner-biceps-curl-with-dumbbell-2",
    # Na web os dois quadros são iguais (hack) ou repetem os do leg press
    "hack-squat-machine",
    "narrow-stance-leg-press",
    # Na web é a rosca sentada comum, igual a seated-biceps-curl-with-dumbbell;
    # o redesenho mostra a concentrada, com o cotovelo apoiado na coxa
    "concentration-curls-with-dumbbell",
    # Na web é o mesmo desenho da cadeira abdutora, com os quadros invertidos
    "thigh-adductor",
}

# Exercícios que usam a ilustração de outro registro do Everkinetic
IMAGEM_DE = {
    # A ilustração própria mostra um cabo; os passos são com haltere, como
    # no registro "-2", que é o mesmo exercício.
    "standing-triceps-extension": "standing-triceps-extension-2",
}


# Ilustrações sem exercício no dataset (src/images-png-unknown/<id>.svg.png),
# do mesmo autor e no mesmo traço. Os dados desses exercícios ficam em
# gerar_base_appgym.EXERCICIOS_SEM_REGISTRO; a lista aqui define os quadros.
IMAGENS_SEM_REGISTRO = {
    "face-pull": ["327a", "327b"],
    "plank": ["848"],
    "hanging-knee-raise": ["753a", "753b"],
    "hanging-leg-raise": ["690a", "690b"],
    "ab-wheel-rollout": ["728a", "728b"],
    "kneeling-cable-crunch": ["732a", "732b"],
    "cable-woodchop": ["949a", "949b"],
    "side-lying-hip-abduction": ["488a", "488b"],
    "kettlebell-goblet-squat": ["473a", "473b"],
}


def pastas_src(clone):
    """slug -> pasta em src/exercises (o primeiro registro com aquele nome)."""
    mapa = {}
    for f in sorted(glob.glob(os.path.join(clone, "src", "exercises", "*", "*.json"))):
        with open(f, encoding="utf-8") as arq:
            nome = json.load(arq).get("name")
        mapa.setdefault(nome, os.path.basename(os.path.dirname(f)))
    return mapa


def origem(clone, slug, mapa_src):
    """Os PNGs de origem do slug e de que versão vieram, ou None."""
    if slug in IMAGENS_SEM_REGISTRO:
        pngs = [os.path.join(clone, "src", "images-png-unknown", f"{i}.svg.png")
                for i in IMAGENS_SEM_REGISTRO[slug]]
        return (pngs, "images-png-unknown") if all(map(os.path.exists, pngs)) else None
    fonte = IMAGEM_DE.get(slug, slug)
    web = [os.path.join(clone, "src", "images-web", f"{fonte}-{n}.png") for n in (1, 2)]
    pasta = mapa_src.get(fonte)
    src = None
    if pasta:
        src = [os.path.join(clone, "src", "exercises", pasta, f"{pasta}-{fase}.png")
               for fase in ("relaxation", "tension")]
    usa_web = all(map(os.path.exists, web))
    usa_src = src and all(map(os.path.exists, src))
    if usa_src and (slug in USAR_SRC or not usa_web):
        return src, f"src/exercises/{pasta}"
    if usa_web:
        return web, "images-web"
    return None


def converter(png, destino):
    with Image.open(png) as im:
        im = im.convert("RGBA")
        fundo = Image.new("RGBA", im.size, "white")
        fundo.alpha_composite(im)
        im = fundo.convert("RGB")
        im.thumbnail((LADO_MAXIMO, LADO_MAXIMO), Image.LANCZOS)
        im.save(destino, "WEBP", quality=QUALIDADE, method=METODO)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(1)
    clone, slugs = args[0], args[1:]
    aplicar = "--aplicar" in sys.argv
    substituir = "--substituir" in sys.argv

    mapa_src = pastas_src(clone)
    if not slugs:
        slugs = [s for s in [*EXERCICIOS_SELECIONADOS, *EXERCICIOS_SEM_REGISTRO]
                 if not os.path.exists(os.path.join(PASTA_APP, f"{s}-1.webp"))]

    feitos, pulados, sem_origem = [], [], []
    for slug in slugs:
        quadros = len(IMAGENS_SEM_REGISTRO.get(slug, [1, 2]))
        destinos = [os.path.join(PASTA_APP, f"{slug}-{n}.webp") for n in range(1, quadros + 1)]
        if not substituir and any(map(os.path.exists, destinos)):
            pulados.append(slug)
            continue
        achado = origem(clone, slug, mapa_src)
        if not achado:
            sem_origem.append(slug)
            continue
        pngs, versao = achado
        if aplicar:
            for png, destino in zip(pngs, destinos):
                converter(png, destino)
        feitos.append(f"{slug}  ←  {versao}")

    print(f"{'GRAVADAS' if aplicar else 'SIMULAÇÃO'}: {len(feitos)} exercício(s)")
    for f in feitos:
        print(f"   {f}")
    if pulados:
        print(f"\nJá tinham imagem (use --substituir): {', '.join(pulados)}")
    if sem_origem:
        print(f"\n❌ Sem ilustração no Everkinetic: {', '.join(sem_origem)}")
    if not aplicar:
        print("\nℹ️  Nada foi gravado. Para aplicar: adicione --aplicar")


if __name__ == "__main__":
    main()
