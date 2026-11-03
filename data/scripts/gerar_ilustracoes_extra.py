"""
gerar_ilustracoes_extra.py — FitWise TCC UNISINOS

Desenha as ilustrações dos grupos que não vêm do Everkinetic (Corrida e
Alongamentos): um boneco "manequim" de contorno preto sobre fundo branco,
no mesmo espírito do traço das outras imagens. Cada exercício tem 2 quadros
(posição inicial e final), animados na tela de detalhe do app.

As poses são descritas por ângulos (cinemática direta), não por desenho à
mão: ângulo 0 aponta para baixo, 90 para a frente (direita), 180 para cima
e -90 para trás (esquerda). Os ângulos são absolutos, não relativos ao
segmento anterior.

Uso:
    python gerar_ilustracoes_extra.py [pasta_saida]

Padrão: ../../app/assets/images
"""

import math
import os
import sys

from PIL import Image, ImageDraw

SAIDA_PADRAO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "app", "assets", "images")

LARGURA, ALTURA = 900, 820
CHAO_Y = 770
ESCALA_AA = 2  # desenha em 2x e reduz, para suavizar as bordas

# Comprimentos (px, em 1x)
TRONCO, PESCOCO, CABECA_R = 150, 14, 34
BRACO, ANTEBRACO = 82, 78
COXA, CANELA, PE = 118, 112, 34
OMBRO_FRENTE, QUADRIL_FRENTE = 40, 22

# Espessuras: contorno preto por fora, preenchimento por dentro
MEMBRO, TRONCO_LADO, TRONCO_FRENTE, CONTORNO = 30, 60, 78, 5
PRETO, BRANCO, CINZA = (0, 0, 0), (255, 255, 255), (200, 200, 200)


def direcao(angulo):
    a = math.radians(angulo)
    return math.sin(a), math.cos(a)


def somar(p, angulo, comprimento):
    dx, dy = direcao(angulo)
    return p[0] + dx * comprimento, p[1] + dy * comprimento


def esqueleto(pose):
    """Calcula as partes do boneco (com o quadril na origem)."""
    frente = pose.get("vista") == "frente"
    t = pose.get("t", 180)
    quadril = (0.0, 0.0)
    pescoco = somar(quadril, t, TRONCO)

    # Curva do tronco (gato/vaca): ponto médio deslocado na perpendicular
    meio = somar(quadril, t, TRONCO / 2)
    meio = somar(meio, t + 90, pose.get("curva", 0))
    tronco = [quadril, meio, pescoco] if pose.get("curva") else [quadril, pescoco]

    cabeca = somar(pescoco, pose.get("cabeca", t), PESCOCO + CABECA_R)

    if frente:
        ombro_d = somar(pescoco, t - 90, OMBRO_FRENTE)
        ombro_e = somar(pescoco, t + 90, OMBRO_FRENTE)
        quadril_d = somar(quadril, t - 90, QUADRIL_FRENTE)
        quadril_e = somar(quadril, t + 90, QUADRIL_FRENTE)
        # pescoço um pouco abaixo da linha dos ombros fica estranho de frente
        ombro_d = somar(ombro_d, t, -10)
        ombro_e = somar(ombro_e, t, -10)
    else:
        ombro_d = ombro_e = somar(pescoco, t, -8)
        quadril_d = quadril_e = quadril

    def braco(ombro, angulos):
        cotovelo = somar(ombro, angulos[0], BRACO)
        return [ombro, cotovelo, somar(cotovelo, angulos[1], ANTEBRACO)]

    def perna(origem, angulos):
        joelho = somar(origem, angulos[0], COXA)
        tornozelo = somar(joelho, angulos[1], CANELA)
        pontos = [origem, joelho, tornozelo]
        if not frente and pose.get("pes", True):
            pe = angulos[2] if len(angulos) > 2 else angulos[1] + 90
            pontos.append(somar(tornozelo, pe, PE))
        return pontos

    partes = {
        "tronco": tronco,
        "cabeca": cabeca,
        "braco_perto": braco(ombro_d, pose.get("bp", (5, 5))),
        "braco_longe": braco(ombro_e, pose.get("bl", (-5, -5))),
        "perna_perto": perna(quadril_d, pose.get("pp", (3, 0))),
        "perna_longe": perna(quadril_e, pose.get("pl", (-3, 0))),
    }

    extras = []
    if "parede" in pose.get("props", []):
        mao = partes["braco_perto"][-1]
        x = mao[0] + MEMBRO / 2 + 6
        extras.append(("parede", x, mao[1] - 170))
    partes["extras"] = extras
    return partes


def caixa(partes):
    """Retângulo que contém todas as partes (com a espessura)."""
    xs, ys = [], []
    for nome, pontos in partes.items():
        if nome == "extras":
            continue
        if nome == "cabeca":
            r = CABECA_R + CONTORNO
            xs += [pontos[0] - r, pontos[0] + r]
            ys += [pontos[1] - r, pontos[1] + r]
            continue
        r = (TRONCO_FRENTE if nome == "tronco" else MEMBRO) / 2
        for x, y in pontos:
            xs += [x - r, x + r]
            ys += [y - r, y + r]
    for _, x, topo in partes["extras"]:
        xs.append(x + 8)
        ys.append(topo)
    return min(xs), min(ys), max(xs), max(ys)


def capsula(draw, pontos, largura, cor):
    draw.line(pontos, fill=cor, width=int(largura), joint="curve")
    r = largura / 2
    for x, y in (pontos[0], pontos[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=cor)


def desenhar(partes, pose, escala, deslocamento, caminho):
    s = escala * ESCALA_AA
    dx, dy = deslocamento
    tr = lambda p: ((p[0] + dx) * s, (p[1] + dy) * s)

    img = Image.new("RGB", (LARGURA * ESCALA_AA, ALTURA * ESCALA_AA), BRANCO)
    draw = ImageDraw.Draw(img)

    frente = pose.get("vista") == "frente"
    tronco_l = TRONCO_FRENTE if frente else TRONCO_LADO

    def parte(nome, largura, recheio):
        pontos = [tr(p) for p in partes[nome]]
        capsula(draw, pontos, (largura + CONTORNO * 2) * s, PRETO)
        capsula(draw, pontos, largura * s, recheio)

    def cabeca():
        cx, cy = tr(partes["cabeca"])
        r = (CABECA_R + CONTORNO) * s
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=PRETO)
        r = CABECA_R * s
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRANCO)

    # Chão: um traço curto sob o boneco
    x0, _, x1, _ = caixa(partes)
    chao = (CHAO_Y / escala) - dy
    draw.line([tr((x0 - 30, chao + CONTORNO)), tr((x1 + 30, chao + CONTORNO))], fill=PRETO, width=int(4 * s))

    for _, x, topo in partes["extras"]:
        draw.line([tr((x, chao)), tr((x, topo))], fill=PRETO, width=int(8 * s))

    if frente:
        parte("perna_longe", MEMBRO, BRANCO)
        parte("perna_perto", MEMBRO, BRANCO)
        parte("tronco", tronco_l, BRANCO)
        cabeca()
        parte("braco_longe", MEMBRO, BRANCO)
        parte("braco_perto", MEMBRO, BRANCO)
    else:
        parte("braco_longe", MEMBRO, CINZA)
        parte("perna_longe", MEMBRO, CINZA)
        parte("tronco", tronco_l, BRANCO)
        cabeca()
        parte("perna_perto", MEMBRO, BRANCO)
        parte("braco_perto", MEMBRO, BRANCO)

    img = img.resize((LARGURA, ALTURA), Image.LANCZOS)
    img.save(caminho, "WEBP", quality=82, method=6)


def gerar(slug, quadros, pasta):
    partes = [esqueleto(p) for p in quadros]
    caixas = [caixa(p) for p in partes]
    # Mesma escala e mesmo centro horizontal nos quadros, para o boneco não
    # "pular" na animação; cada quadro encosta no chão separadamente.
    largura = max(c[2] for c in caixas) - min(c[0] for c in caixas)
    altura = max(c[3] - c[1] for c in caixas)
    escala = min(1.5, (LARGURA - 120) / largura, (CHAO_Y - 60) / altura)
    centro_x = (min(c[0] for c in caixas) + max(c[2] for c in caixas)) / 2
    for i, (p, pose, c) in enumerate(zip(partes, quadros, caixas), start=1):
        deslocamento = (LARGURA / 2 / escala - centro_x, CHAO_Y / escala - c[3])
        desenhar(p, pose, escala, deslocamento, os.path.join(pasta, f"{slug}-{i}.webp"))


NEUTRO = {"t": 180}
NEUTRO_FRENTE = {"vista": "frente", "t": 180, "bp": (8, 4), "bl": (-8, -4), "pp": (4, 1), "pl": (-4, -1)}

POSES = {
    # ── Corrida ──
    "corrida": [
        {"t": 170, "bp": (-40, 45), "bl": (45, 150), "pp": (50, -10), "pl": (-30, -100)},
        {"t": 170, "bp": (45, 150), "bl": (-40, 45), "pp": (-30, -100), "pl": (50, -10)},
    ],
    "tiro": [
        {"t": 160, "bp": (-60, 30), "bl": (70, 165), "pp": (78, 10), "pl": (-40, -120)},
        {"t": 160, "bp": (70, 165), "bl": (-60, 30), "pp": (-40, -120), "pl": (78, 10)},
    ],
    "longao": [
        {"t": 175, "bp": (-25, 60), "bl": (30, 125), "pp": (35, -5), "pl": (-20, -75)},
        {"t": 175, "bp": (30, 125), "bl": (-25, 60), "pp": (-20, -75), "pl": (35, -5)},
    ],
    # ── Alongamentos ──
    "alongamento-quadriceps-em-pe": [
        NEUTRO,
        {"t": 180, "bp": (-24, -24), "bl": (85, 88), "pp": (-15, -160, -95), "pl": (0, 0)},
    ],
    "alongamento-posterior-sentado": [
        {"t": 180, "bp": (12, 8), "bl": (8, 4), "pp": (90, 90, 180), "pl": (90, 90, 180)},
        {"t": 120, "cabeca": 112, "bp": (100, 96), "bl": (96, 92), "pp": (90, 90, 180), "pl": (90, 90, 180)},
    ],
    "alongamento-panturrilha-na-parede": [
        {"t": 168, "bp": (100, 95), "bl": (96, 92), "pp": (12, 0), "pl": (-12, -12), "props": ["parede"]},
        {"t": 150, "bp": (112, 100), "bl": (108, 96), "pp": (32, 8), "pl": (-24, -24), "props": ["parede"]},
    ],
    "alongamento-flexor-quadril": [
        {"t": 180, "bp": (40, 75), "bl": (35, 70), "pp": (90, 0), "pl": (-10, -90, 180)},
        {"t": 186, "bp": (174, 178), "bl": (170, 176), "pp": (84, 8), "pl": (-22, -90, 180)},
    ],
    "alongamento-gluteo-deitado": [
        {"t": -90, "bp": (95, 92), "bl": (92, 90), "pp": (90, 90, 180), "pl": (90, 90, 180)},
        {"t": -90, "bp": (138, 142), "bl": (132, 140), "pp": (-150, 100, 190), "pl": (90, 90, 180)},
    ],
    "alongamento-lombar-postura-crianca": [
        {"t": 104, "cabeca": 85, "bp": (2, 0), "bl": (-2, -2), "pp": (0, -90, 180), "pl": (2, -90, 180)},
        {"t": 88, "cabeca": 92, "bp": (70, 85), "bl": (68, 84), "pp": (75, -90, 180), "pl": (77, -90, 180)},
    ],
    "alongamento-gato-vaca": [
        {"t": 104, "curva": 38, "cabeca": 40, "bp": (2, 0), "bl": (-2, -2), "pp": (0, -90, 180), "pl": (2, -90, 180)},
        {"t": 104, "curva": -38, "cabeca": 140, "bp": (2, 0), "bl": (-2, -2), "pp": (0, -90, 180), "pl": (2, -90, 180)},
    ],
    "alongamento-peitoral": [
        NEUTRO,
        {"t": 174, "cabeca": 176, "bp": (-50, -62), "bl": (-46, -58), "pp": (3, 0), "pl": (-3, 0)},
    ],
    "alongamento-ombro-cruzado": [
        NEUTRO_FRENTE,
        {**NEUTRO_FRENTE, "bp": (-90, -90), "bl": (22, 150)},
    ],
    "alongamento-triceps": [
        NEUTRO_FRENTE,
        {**NEUTRO_FRENTE, "bp": (170, -30), "bl": (155, 95)},
    ],
    "alongamento-lateral-tronco": [
        {**NEUTRO_FRENTE, "pp": (10, 6), "pl": (-10, -6)},
        {**NEUTRO_FRENTE, "t": -162, "cabeca": -158, "bp": (-172, -140), "bl": (-35, 45), "pp": (10, 6), "pl": (-10, -6)},
    ],
    "alongamento-pescoco": [
        NEUTRO_FRENTE,
        {**NEUTRO_FRENTE, "cabeca": 158, "bp": (165, -69), "bl": (-15, -10)},
    ],
    "alongamento-adutores-borboleta": [
        {"vista": "frente", "t": 180, "bp": (-12, -14), "bl": (12, 14), "pp": (140, -40), "pl": (-140, 40)},
        {"vista": "frente", "t": 180, "bp": (-14, -16), "bl": (14, 16), "pp": (85, -95), "pl": (-85, 95)},
    ],
    "alongamento-isquiotibiais-em-pe": [
        NEUTRO,
        {"t": 95, "cabeca": 60, "bp": (8, 4), "bl": (5, 2), "pp": (4, 0), "pl": (-4, 0)},
    ],
}


def main():
    pasta = sys.argv[1] if len(sys.argv) > 1 else SAIDA_PADRAO
    os.makedirs(pasta, exist_ok=True)
    for slug, quadros in POSES.items():
        gerar(slug, quadros, pasta)
        print(f"✓ {slug} ({len(quadros)} quadros)")


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main()
