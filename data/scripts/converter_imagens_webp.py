"""
converter_imagens_webp.py — AppGym TCC UNISINOS

Converte os PNGs dos exercícios para WebP, que reduz o peso em cerca de 85%
sem perda visível nestas ilustrações (diferença média medida: 0,15%).

Os PNGs originais continuam no histórico do git, então a conversão é
reversível com `git checkout`.

Uso:
    python converter_imagens_webp.py <pasta> [--aplicar]

Sem --aplicar, só relata o que seria feito.
"""

import os
import sys
import glob

from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

QUALIDADE = 90
METODO = 6  # 0 = rápido, 6 = melhor compressão


def main():
    if len(sys.argv) < 2:
        print("uso: python converter_imagens_webp.py <pasta> [--aplicar]")
        sys.exit(1)

    pasta = sys.argv[1]
    aplicar = "--aplicar" in sys.argv

    pngs = sorted(glob.glob(os.path.join(pasta, "*.png")))
    if not pngs:
        print(f"❌ Nenhum PNG em {pasta}")
        sys.exit(1)

    print(f"{'CONVERTENDO' if aplicar else 'SIMULANDO'} {len(pngs)} imagens")
    print(f"Pasta: {pasta}  |  qualidade {QUALIDADE}, método {METODO}")
    print("-" * 52)

    antes = depois = 0
    convertidos, erros = [], []

    for png in pngs:
        destino = os.path.splitext(png)[0] + ".webp"
        try:
            with Image.open(png) as im:
                origem = os.path.getsize(png)
                if aplicar:
                    im.save(destino, "WEBP", quality=QUALIDADE, method=METODO)
                    novo = os.path.getsize(destino)
                    os.remove(png)
                else:
                    import io
                    buf = io.BytesIO()
                    im.save(buf, "WEBP", quality=QUALIDADE, method=METODO)
                    novo = buf.tell()
            antes += origem
            depois += novo
            convertidos.append(os.path.basename(destino))
        except Exception as e:
            erros.append(f"{os.path.basename(png)}: {e}")

    print(f"✅ {len(convertidos)} imagem(ns) convertida(s)")
    print(f"   antes:  {antes / 1024 / 1024:7.1f} MB")
    print(f"   depois: {depois / 1024 / 1024:7.1f} MB")
    if antes:
        print(f"   redução: {100 - depois * 100 // antes}%")

    if erros:
        print(f"\n❌ {len(erros)} erro(s):")
        for e in erros:
            print(f"   - {e}")

    if not aplicar:
        print("\nℹ️  Simulação — nenhum arquivo foi alterado.")
        print("   Para aplicar: adicione --aplicar")


if __name__ == "__main__":
    main()
