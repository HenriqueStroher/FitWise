"""
gerar_base_appgym.py — AppGym TCC UNISINOS

Gera a base curada de exercícios (appgym_exercises.json) a partir do dataset
bruto do Everkinetic (exercises.json).

O dataset bruto traz nome, passos, equipamento e imagens em inglês. Os campos
usados pelo algoritmo de recomendação (vetorForca, planoMovimento,
ativacaoMuscular, escoreRiscoLesao) e os textos em português NÃO existem na
fonte — são curados aqui, em EXERCICIOS_SELECIONADOS.

Uso:
    python gerar_base_appgym.py [entrada_exercises.json] [saida.json]

Padrões: ./exercises.json -> ./appgym_exercises.json
"""

import json
import os
import re
import sys
from collections import Counter

# O console do Windows usa cp1252 por padrão e quebra nos emojis do relatório
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ENTRADA_PADRAO = "exercises.json"
SAIDA_PADRAO = "appgym_exercises.json"

# Traduções dos `steps`, que no dataset de origem só existem em inglês.
# Fica fora deste arquivo por ser conteúdo, não lógica — e versionado, para
# que a base seja reproduzível sem depender do que está gravado no Firestore.
# Caminho relativo à pasta deste script; ausente, os steps saem em inglês.
STEPS_PT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "steps_pt.json")
VERSAO = "2.0.0"
ESCOPO = "completo_v2"

# ─────────────────────────────────────────────
# Grupos musculares do app
#
# O campo `primary` do Everkinetic é inconsistente (mistura músculo, região e
# rótulos soltos como "arms"). Este mapa normaliza para os grupos que o app
# exibe. `musculoPrimario` no JSON final recebe o GRUPO — é por ele que o
# ExercicioService filtra. O músculo original fica em `musculoDetalhe`.
# ─────────────────────────────────────────────
GRUPO_POR_PRIMARY = {
    "biceps": "BICEPS",
    "triceps": "TRICEPS",
    "chest": "PEITO",
    "lats": "COSTAS",
    "middle back": "COSTAS",
    "upper back": "COSTAS",
    "back": "COSTAS",
    "trapezius": "COSTAS",
    "shoulders": "OMBROS",
    "lateral deltoid": "OMBROS",
    "rear deltoid": "OMBROS",
    "posterior deltoid": "OMBROS",
    "quadriceps": "QUADRICEPS",
    "hamstrings": "POSTERIOR",
    "hamstring": "POSTERIOR",
    "gluts": "GLUTEOS",
    "glutes": "GLUTEOS",
    "calves": "PANTURRILHA",
    "abdominals": "ABDOMEN",
    "lower abdominals": "ABDOMEN",
    "obliques": "ABDOMEN",
    "core": "ABDOMEN",
    "lower back": "LOMBAR",
}

# Ordem de exibição dos grupos nos totais e no app
ORDEM_GRUPOS = [
    "PEITO", "COSTAS", "OMBROS", "BICEPS", "TRICEPS",
    "ABDOMEN", "LOMBAR", "QUADRICEPS", "POSTERIOR", "GLUTEOS", "PANTURRILHA",
]

# ─────────────────────────────────────────────
# Exercícios curados
#
# Campos obrigatórios por exercício:
#   nomePT, descricaoPT, vetorForca, planoMovimento,
#   ativacaoMuscular, escoreRiscoLesao, cuidados
# Campos opcionais:
#   grupo  — sobrepõe GRUPO_POR_PRIMARY quando o rótulo da fonte está errado
#   tipo   — sobrepõe o `type` da fonte (que classifica como "isolation"
#            vários movimentos claramente compostos)
#
# Convenções usadas na curadoria:
#   vetorForca     — direção da resistência em relação ao corpo:
#                    "vertical" (peso livre contra a gravidade),
#                    "horizontal" (empurrar/puxar à frente do tronco),
#                    "angular" (cabos e máquinas de trajetória inclinada)
#   planoMovimento — plano anatômico dominante: sagital, frontal ou transversal
#   ativacaoMuscular / escoreRiscoLesao — estimativas de 0 a 1 baseadas em
#                    literatura de EMG e biomecânica, não em medição.
# ─────────────────────────────────────────────
EXERCICIOS_SELECIONADOS = {

    # ══ BÍCEPS ══════════════════════════════

    "biceps-curl-with-dumbbell": {
        "nomePT": "Rosca com Haltere",
        "descricaoPT": "Exercício básico e eficaz para isolamento do bíceps com halteres.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha os cotovelos fixos ao lado do corpo",
            "Não balance o tronco durante o movimento",
            "Controle a descida do peso de forma lenta"
        ]
    },
    "biceps-curls-with-barbell": {
        "nomePT": "Rosca Direta com Barra",
        "descricaoPT": "Exercício básico para o bíceps utilizando barra reta.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Não balance o tronco durante o movimento",
            "Mantenha os cotovelos fixos ao lado do corpo",
            "Evite hiperextender os pulsos"
        ]
    },
    "ez-bar-curl-with-barbell": {
        "nomePT": "Rosca com Barra W",
        "descricaoPT": "Rosca com barra W, que reduz o estresse nos pulsos em relação à barra reta.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os cotovelos fixos ao lado do corpo",
            "Não balance o tronco",
            "A barra W reduz estresse no pulso — mantenha a pegada natural"
        ]
    },
    "concentration-curls-with-dumbbell": {
        "nomePT": "Rosca Concentrada com Haltere",
        "descricaoPT": "Exercício de isolamento máximo do bíceps realizado sentado com apoio do cotovelo na coxa.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.95,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Apoie o cotovelo firmemente na parte interna da coxa",
            "Realize o movimento de forma lenta e controlada",
            "Não torça o pulso durante o movimento"
        ]
    },
    "hammer-curls-with-rope-and-cable": {
        "nomePT": "Rosca Martelo no Cabo com Corda",
        "descricaoPT": "Variação da rosca martelo no cabo com corda, trabalhando bíceps e braquiorradial.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o polegar apontado para cima durante o movimento",
            "Não balance o tronco",
            "Controle a tensão do cabo no retorno"
        ]
    },
    "preacher-curl-with-barbell": {
        "nomePT": "Rosca Scott com Barra",
        "descricaoPT": "Rosca Scott com barra que isola o bíceps eliminando o uso do tronco.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.92,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Não estenda totalmente o cotovelo para evitar lesão",
            "Mantenha o braço apoiado no suporte o tempo todo",
            "Use cargas moderadas — o isolamento aumenta o risco"
        ]
    },
    "incline-inner-biceps-curl-with-dumbbell-2": {
        "nomePT": "Rosca Inclinada com Haltere",
        "descricaoPT": "Rosca realizada no banco inclinado que aumenta o alongamento do bíceps.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.91,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha as costas totalmente apoiadas no banco inclinado",
            "Não force a amplitude além do confortável",
            "Realize o movimento de forma lenta e controlada"
        ]
    },
    "standing-biceps-curl-with-cable": {
        "nomePT": "Rosca no Cabo em Pé",
        "descricaoPT": "Rosca no cabo em pé que mantém tensão constante no bíceps durante todo o movimento.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os cotovelos fixos ao lado do corpo",
            "Não use impulso do tronco",
            "Aproveite a tensão constante do cabo — faça o movimento devagar"
        ]
    },
    "seated-biceps-curl-with-dumbbell": {
        "nomePT": "Rosca com Haltere Sentado",
        "descricaoPT": "Versão sentada da rosca com haltere, que reduz o uso do tronco como compensação.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha as costas apoiadas no banco",
            "Não balance o tronco para frente",
            "Mantenha os cotovelos fixos durante o movimento"
        ]
    },
    "alternating-biceps-curl-with-dumbbell": {
        "nomePT": "Rosca Alternada com Haltere",
        "descricaoPT": "Rosca com halteres alternando os braços, permitindo maior foco em cada lado.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Não balance o tronco ao alternar os braços",
            "Mantenha o cotovelo do braço que descansa fixo",
            "Controle a descida do peso"
        ]
    },

    # ══ TRÍCEPS ═════════════════════════════

    "triceps-pushdown-with-cable": {
        "nomePT": "Pushdown de Tríceps no Cabo",
        "descricaoPT": "Exercício fundamental de isolamento do tríceps utilizando cabo com barra reta.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os cotovelos fixos e colados ao lado do corpo",
            "Não incline o tronco para frente para usar mais carga",
            "Controle o retorno do cabo — não deixe subir de forma descontrolada"
        ]
    },
    "tate-press-with-dumbbell": {
        "nomePT": "Tate Press com Haltere",
        "descricaoPT": "Exercício avançado de tríceps realizado deitado que trabalha o músculo de forma diferente.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Exercício avançado — não recomendado para iniciantes",
            "Mantenha os cotovelos apontados para cima durante todo o movimento",
            "Use cargas leves inicialmente para aprender a técnica"
        ]
    },
    "tricep-dips-using-body-weight": {
        "nomePT": "Mergulho de Tríceps no Peso Corporal",
        "descricaoPT": "Exercício com peso corporal que trabalha fortemente o tríceps usando barras paralelas ou banco.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Não desça além de 90 graus no cotovelo",
            "Mantenha o tronco levemente inclinado à frente",
            "Evite este exercício se tiver problemas no ombro"
        ]
    },
    "seated-two-arm-triceps-extension-with-dumbbell": {
        "nomePT": "Extensão de Tríceps Acima da Cabeça Sentado",
        "descricaoPT": "Extensão de tríceps com haltere acima da cabeça sentado, focando na cabeça longa do tríceps.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Mantenha os cotovelos apontados para cima e próximos à cabeça",
            "Não arqueie excessivamente a lombar",
            "Controle o peso na descida atrás da cabeça"
        ]
    },
    "triceps-kickback-with-dumbbell": {
        "nomePT": "Tríceps Coice com Haltere",
        "descricaoPT": "Exercício de isolamento do tríceps realizado curvado para frente com haltere.",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha o cotovelo fixo e paralelo ao tronco",
            "Não balance o tronco para dar impulso",
            "Estenda completamente o braço no topo do movimento"
        ]
    },
    "triceps-pushdown-with-rope-and-cable": {
        "nomePT": "Pushdown de Tríceps com Corda no Cabo",
        "descricaoPT": "Variação do pushdown com corda que permite abertura no final do movimento, aumentando a contração.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Abra a corda para os lados no final do movimento para máxima contração",
            "Mantenha os cotovelos fixos ao lado do corpo",
            "Não use o tronco para aumentar a carga"
        ]
    },
    "reverse-grip-triceps-pushdown": {
        "nomePT": "Pushdown de Tríceps com Pegada Inversa",
        "descricaoPT": "Variação do pushdown com pegada supinada que ativa mais a cabeça medial do tríceps.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os pulsos retos durante o movimento",
            "Cotovelos fixos ao lado do corpo",
            "Use carga menor que no pushdown tradicional"
        ]
    },
    "standing-triceps-extension": {
        "nomePT": "Extensão de Tríceps em Pé",
        "descricaoPT": "Extensão de tríceps realizada em pé com barra ou haltere acima da cabeça.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha os cotovelos apontados para cima próximos à cabeça",
            "Não arqueie a lombar — contraia o core",
            "Controle a descida do peso atrás da cabeça"
        ]
    },
    "decline-close-grip-bench-to-skull-crusher": {
        "nomePT": "Supino Fechado Declinado com Skull Crusher",
        "descricaoPT": "Exercício combinado que une o supino fechado com a extensão de crânio no banco declinado.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.91,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Exercício avançado — requer supervisão",
            "Mantenha controle total da barra em todo momento",
            "Não realize sem um parceiro de treino para segurança"
        ]
    },
    "tricep-dips": {
        "nomePT": "Mergulho de Tríceps na Máquina",
        "descricaoPT": "Versão do mergulho de tríceps na máquina, mais segura e controlada que a versão livre.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Ajuste o banco para a altura adequada antes de começar",
            "Mantenha as costas apoiadas no suporte",
            "Não deixe os ombros subirem durante o movimento"
        ]
    },

    # ══ PEITO ═══════════════════════════════

    "bench-press": {
        "nomePT": "Supino Reto com Barra",
        "descricaoPT": "Principal exercício de empurrar horizontal e base do desenvolvimento do peitoral maior.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.92,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha as escápulas retraídas e apoiadas no banco",
            "Não deixe a barra quicar no peito",
            "Use parceiro ou suporte de segurança em cargas altas"
        ]
    },
    "bench-press-dumbbell": {
        "nomePT": "Supino Reto com Halteres",
        "descricaoPT": "Versão com halteres do supino reto, que exige mais estabilização e permite amplitude maior.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Desça os halteres até a linha do peito, sem forçar o ombro",
            "Não choque os halteres no topo do movimento",
            "Mantenha os punhos firmes e alinhados com os antebraços"
        ]
    },
    "incline-bench-press": {
        "nomePT": "Supino Inclinado com Barra",
        "descricaoPT": "Supino em banco inclinado, que desloca o esforço para a porção clavicular do peitoral.",
        "tipo": "compound",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Use inclinação entre 30 e 45 graus para poupar o ombro",
            "Mantenha os glúteos apoiados no banco",
            "Não afaste demais os cotovelos do tronco"
        ]
    },
    "dumbbell-incline-bench-press": {
        "nomePT": "Supino Inclinado com Halteres",
        "descricaoPT": "Supino inclinado com halteres, com maior amplitude e trabalho de estabilização.",
        "tipo": "compound",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Controle a descida — a amplitude maior aumenta o estresse no ombro",
            "Mantenha as costas apoiadas no banco inclinado",
            "Não estenda os cotovelos de forma brusca no topo"
        ]
    },
    "decline-barbell-bench-press": {
        "nomePT": "Supino Declinado com Barra",
        "descricaoPT": "Supino em banco declinado, que enfatiza a porção inferior do peitoral.",
        "tipo": "compound",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Prenda bem as pernas no apoio antes de iniciar",
            "Evite o exercício se tiver pressão alta ou tontura ao deitar",
            "Nunca execute sem parceiro em cargas altas"
        ]
    },
    "dumbbell-flys": {
        "nomePT": "Crucifixo com Halteres",
        "descricaoPT": "Exercício de isolamento do peitoral realizado deitado, com abertura ampla dos braços.",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha os cotovelos levemente flexionados durante todo o movimento",
            "Não desça além da linha do tronco para proteger o ombro",
            "Use carga moderada — o braço de alavanca é longo"
        ]
    },
    "incline-dumbbell-flys": {
        "nomePT": "Crucifixo Inclinado com Halteres",
        "descricaoPT": "Crucifixo em banco inclinado, com foco na porção superior do peitoral.",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha os cotovelos semiflexionados e fixos",
            "Não force a abertura além do confortável",
            "Suba os halteres em arco, sem empurrar"
        ]
    },
    "cable-crossover": {
        "nomePT": "Crossover no Cabo",
        "descricaoPT": "Cruzamento de cabos que mantém tensão constante no peitoral em toda a amplitude.",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha leve inclinação do tronco à frente e o core firme",
            "Cotovelos levemente flexionados e fixos",
            "Controle o retorno — não deixe os cabos puxarem os braços"
        ]
    },
    "butterfly-machine": {
        "nomePT": "Voador na Máquina",
        "descricaoPT": "Isolamento do peitoral na máquina voador, com trajetória guiada e risco reduzido.",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o assento para que as mãos fiquem na linha do peito",
            "Não force a abertura dos braços para trás",
            "Mantenha as costas apoiadas no encosto"
        ]
    },
    "push-ups": {
        "nomePT": "Flexão de Braço",
        "descricaoPT": "Exercício de peso corporal para peitoral, tríceps e estabilização do core.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.05,
        "cuidados": [
            "Mantenha o corpo alinhado da cabeça aos pés",
            "Não deixe a lombar afundar",
            "Desça até o peito ficar próximo ao chão, sem apoiar"
        ]
    },

    # ══ COSTAS ══════════════════════════════

    "wide-grip-lat-pull-down": {
        "nomePT": "Puxada Aberta no Pulley",
        "descricaoPT": "Puxada vertical com pegada aberta, principal exercício para a largura do dorsal.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Puxe a barra até a altura do queixo, sem levar atrás da cabeça",
            "Não use impulso do tronco para completar o movimento",
            "Inicie o movimento deprimindo as escápulas"
        ]
    },
    "underhand-pull-down": {
        "nomePT": "Puxada Supinada no Pulley",
        "descricaoPT": "Puxada vertical com pegada supinada, que aumenta a participação do bíceps.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os punhos alinhados com os antebraços",
            "Não jogue o tronco para trás",
            "Controle a subida da barra até a extensão completa"
        ]
    },
    "v-bar-pull-down": {
        "nomePT": "Puxada com Triângulo",
        "descricaoPT": "Puxada com pegada neutra no triângulo, com foco na espessura do dorsal.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha o tronco estável, sem balanço",
            "Puxe o triângulo até a parte alta do abdômen",
            "Não encolha os ombros durante a puxada"
        ]
    },
    "pull-ups": {
        "nomePT": "Barra Fixa Pronada",
        "descricaoPT": "Puxada vertical no peso corporal com pegada pronada, exigente e completa para as costas.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.92,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Evite balançar o corpo para ganhar impulso",
            "Não desça de forma brusca — controle a fase excêntrica",
            "Use elástico ou apoio se ainda não alcançar a amplitude completa"
        ]
    },
    "chin-ups": {
        "nomePT": "Barra Fixa Supinada",
        "descricaoPT": "Barra fixa com pegada supinada, que recruta fortemente dorsais e bíceps.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Mantenha os ombros ativos e as escápulas deprimidas",
            "Evite hiperextender os cotovelos na descida",
            "Não use impulso de pernas em treino de força"
        ]
    },
    "seated-cable-rows": {
        "nomePT": "Remada Sentada no Cabo",
        "descricaoPT": "Remada horizontal sentada, com tensão contínua e baixa sobrecarga na lombar.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha a coluna neutra — não curve as costas ao retornar",
            "Puxe com as costas, não apenas com os braços",
            "Evite inclinar muito o tronco para trás"
        ]
    },
    "reverse-grips-bent-over-barbell-rows": {
        "nomePT": "Remada Curvada Supinada com Barra",
        "descricaoPT": "Remada curvada com pegada supinada, de alta sobrecarga para dorsais e trapézio.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Mantenha a coluna neutra e o core contraído durante todo o movimento",
            "Não arredonde a lombar — reduza a carga se perder a postura",
            "Evite este exercício se tiver histórico de dor lombar"
        ]
    },
    "t-bar-rows": {
        "nomePT": "Remada Cavalinho",
        "descricaoPT": "Remada na barra T, que permite cargas altas com o tronco apoiado na inclinação.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha o peito apoiado quando o aparelho permitir",
            "Não puxe usando impulso de lombar",
            "Controle a descida sem deixar o peso cair"
        ]
    },
    "barbell-shrugs": {
        "nomePT": "Encolhimento com Barra",
        "descricaoPT": "Isolamento do trapézio superior pela elevação dos ombros com barra.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Suba os ombros em linha reta — não faça rotação",
            "Não use impulso de pernas",
            "Evite flexionar os cotovelos para ajudar no movimento"
        ]
    },
    "shoulder-shrugs": {
        "nomePT": "Encolhimento com Halteres",
        "descricaoPT": "Encolhimento com halteres, que permite trajetória mais natural dos ombros.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os braços estendidos e relaxados",
            "Não rotacione os ombros durante o movimento",
            "Controle a descida dos halteres"
        ]
    },

    # ══ OMBROS ══════════════════════════════

    "barbell-shoulder-press": {
        "nomePT": "Desenvolvimento com Barra em Pé",
        "descricaoPT": "Empurrar vertical em pé com barra, exercício base para os ombros.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Contraia o core e evite arquear a lombar",
            "Não leve a barra atrás da cabeça",
            "Exige boa mobilidade de ombro — progrida a carga devagar"
        ]
    },
    "seated-military-press": {
        "nomePT": "Desenvolvimento Militar Sentado",
        "descricaoPT": "Desenvolvimento sentado com barra, que reduz a compensação do tronco.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.91,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha as costas apoiadas no encosto",
            "Não desça a barra abaixo do queixo",
            "Evite o exercício se tiver lesão no manguito rotador"
        ]
    },
    "dumbbell-shoulder-press": {
        "nomePT": "Desenvolvimento com Halteres",
        "descricaoPT": "Desenvolvimento com halteres, com trajetória livre e maior demanda de estabilização.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha os punhos firmes e alinhados com os antebraços",
            "Não choque os halteres no topo do movimento",
            "Desça até a altura das orelhas, sem forçar"
        ]
    },
    "arnold-press": {
        "nomePT": "Desenvolvimento Arnold",
        "descricaoPT": "Desenvolvimento com rotação dos antebraços, que recruta as três porções do deltoide.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Faça a rotação de forma lenta e controlada",
            "Use carga menor que no desenvolvimento tradicional",
            "Evite se sentir desconforto na rotação do ombro"
        ]
    },
    "seated-shoulder-press-machine": {
        "nomePT": "Desenvolvimento na Máquina",
        "descricaoPT": "Desenvolvimento guiado na máquina, indicado para iniciantes e trabalho de volume.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o assento para que as mãos fiquem na linha dos ombros",
            "Mantenha as costas apoiadas no encosto",
            "Não estenda os cotovelos de forma brusca"
        ]
    },
    "lateral-dumbbell-raises": {
        "nomePT": "Elevação Lateral com Halteres",
        "descricaoPT": "Isolamento do deltoide medial, principal exercício para a largura dos ombros.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Suba até a altura dos ombros, sem passar",
            "Mantenha os cotovelos levemente flexionados",
            "Não use impulso do tronco — prefira carga leve"
        ]
    },
    "front-raises": {
        "nomePT": "Elevação Frontal com Haltere",
        "descricaoPT": "Isolamento do deltoide anterior pela elevação do braço à frente do corpo.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Suba apenas até a altura dos ombros",
            "Não arqueie a lombar para dar impulso",
            "Mantenha o movimento lento e controlado"
        ]
    },
    "upright-barbell-rows": {
        "nomePT": "Remada Alta com Barra",
        "descricaoPT": "Remada alta que trabalha deltoide medial e trapézio; exige cuidado com o ombro.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Não suba a barra acima da linha dos ombros",
            "Use pegada mais aberta para reduzir o impacto no ombro",
            "Evite o exercício se sentir dor ou pinçamento no ombro"
        ]
    },
    "rear-deltoid-row-dumbbell": {
        "nomePT": "Remada Aberta para Deltoide Posterior",
        "descricaoPT": "Remada aberta curvada com haltere, com foco no deltoide posterior e trapézio médio.",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha a coluna neutra com o tronco inclinado",
            "Abra os cotovelos na linha dos ombros",
            "Use carga leve — o deltoide posterior é um músculo pequeno"
        ]
    },
    "bent-over-lateral-cable-raises": {
        "nomePT": "Elevação Lateral Curvada no Cabo",
        "descricaoPT": "Elevação lateral curvada no cabo, isolando o deltoide posterior com tensão constante.",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha o tronco firme e a coluna neutra",
            "Não gire o tronco para acompanhar o braço",
            "Controle o retorno do cabo"
        ]
    },

    # ══ ABDÔMEN ═════════════════════════════

    "crunches": {
        "nomePT": "Abdominal Supra",
        "descricaoPT": "Flexão de tronco deitado, exercício base para o reto abdominal.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Não puxe a cabeça com as mãos",
            "Suba apenas até destacar as escápulas do chão",
            "Mantenha a lombar apoiada e o movimento lento"
        ]
    },
    "air-bike": {
        "nomePT": "Abdominal Bicicleta",
        "descricaoPT": "Flexão de tronco com rotação alternada, que soma reto abdominal e oblíquos.",
        "tipo": "compound",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Faça a rotação com o tronco, não apenas com os cotovelos",
            "Não puxe o pescoço com as mãos",
            "Mantenha a lombar próxima ao chão"
        ]
    },
    "flat-bench-leg-raises": {
        "nomePT": "Elevação de Pernas no Banco",
        "descricaoPT": "Elevação de pernas no banco, com foco na porção inferior do abdômen.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha a lombar apoiada no banco",
            "Não deixe as pernas puxarem a pelve e arquear as costas",
            "Desça as pernas de forma controlada"
        ]
    },
    "bent-knee-hip-raise": {
        "nomePT": "Elevação de Quadril com Joelhos Flexionados",
        "descricaoPT": "Elevação de quadril deitado, que trabalha o abdômen inferior com menor estresse lombar.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Eleve o quadril com o abdômen, sem impulso de pernas",
            "Mantenha a lombar neutra",
            "Faça o movimento curto e controlado"
        ]
    },
    "seated-ab-crunch-with-cable": {
        "nomePT": "Abdominal no Cabo Sentado",
        "descricaoPT": "Flexão de tronco no cabo, que permite progressão de carga no abdômen.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Flexione o tronco com o abdômen, sem puxar com os braços",
            "Mantenha o quadril fixo no banco",
            "Controle o retorno contra a tensão do cabo"
        ]
    },
    "crunches-with-legs-on-stability-ball": {
        "nomePT": "Abdominal com Pernas na Bola",
        "descricaoPT": "Abdominal com as pernas apoiadas na bola, que exige mais estabilização do core.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Estabilize a bola antes de iniciar o movimento",
            "Não puxe a cabeça com as mãos",
            "Mantenha a lombar apoiada"
        ]
    },
    "ab-rollout-on-knees-with-barbell": {
        "nomePT": "Rollout de Joelhos com Barra",
        "descricaoPT": "Exercício anti-extensão avançado, com grande demanda de todo o core.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.35,
        "cuidados": [
            "Exercício avançado — não role além do ponto em que controla a lombar",
            "Mantenha o abdômen contraído e a lombar neutra todo o tempo",
            "Evite se tiver dor lombar ou hérnia"
        ]
    },
    "side-plank": {
        "nomePT": "Prancha Lateral",
        "descricaoPT": "Isometria lateral que trabalha oblíquos e estabilizadores do quadril.",
        "tipo": "isometric",
        "vetorForca": "horizontal",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.82,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o corpo alinhado, sem deixar o quadril cair",
            "Apoie o cotovelo alinhado abaixo do ombro",
            "Interrompa se sentir dor no ombro de apoio"
        ]
    },
    "stationary-abdominal-draw-in": {
        "nomePT": "Ativação Abdominal",
        "descricaoPT": "Contração isométrica do abdômen profundo, usada para aprender a ativação do core.",
        "tipo": "isometric",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.70,
        "escoreRiscoLesao": 0.05,
        "cuidados": [
            "Respire normalmente durante a contração — não prenda o ar",
            "Puxe o abdômen para dentro sem mover a coluna",
            "Mantenha a contração por poucos segundos no início"
        ]
    },
    "side-bend-with-dumbbell": {
        "nomePT": "Flexão Lateral com Haltere",
        "descricaoPT": "Flexão lateral de tronco com haltere, com foco nos oblíquos.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Desça apenas até onde o movimento vem do tronco, sem rodar",
            "Use carga moderada — cargas altas sobrecarregam a lombar",
            "Faça o mesmo número de repetições nos dois lados"
        ]
    },

    # ══ LOMBAR ══════════════════════════════

    "barbell-dead-lifts": {
        "nomePT": "Levantamento Terra com Barra",
        "descricaoPT": "Exercício base de levantamento do solo, com alta demanda de toda a cadeia posterior.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.95,
        "escoreRiscoLesao": 0.45,
        "cuidados": [
            "Mantenha a coluna neutra do início ao fim — não arredonde a lombar",
            "Mantenha a barra próxima ao corpo durante toda a subida",
            "Aprenda a técnica com carga leve antes de progredir"
        ]
    },
    "dumbbell-dead-lifts": {
        "nomePT": "Levantamento Terra com Halteres",
        "descricaoPT": "Versão com halteres do levantamento terra, mais acessível para aprendizado.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha a coluna neutra e o core contraído",
            "Desça os halteres próximos às pernas",
            "Pare a descida quando a lombar começar a arredondar"
        ]
    },
    "smith-machine-dead-lifts": {
        "nomePT": "Levantamento Terra no Smith",
        "descricaoPT": "Levantamento terra na barra guiada, que reduz a exigência de equilíbrio.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Posicione os pés sob a barra antes de iniciar",
            "Mantenha a coluna neutra apesar da trajetória guiada",
            "Inicie o movimento com as pernas, não com a lombar"
        ]
    },
    "barbell-good-mornings": {
        "nomePT": "Bom Dia com Barra",
        "descricaoPT": "Dobradiça de quadril com barra nas costas, que fortalece lombar e isquiotibiais.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Use carga leve — a alavanca sobre a lombar é longa",
            "Mantenha a coluna neutra e os joelhos levemente flexionados",
            "Evite o exercício se tiver histórico de lesão lombar"
        ]
    },
    "smith-machine-good-mornings": {
        "nomePT": "Bom Dia no Smith",
        "descricaoPT": "Bom dia na barra guiada, com trajetória mais controlada que a versão livre.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.35,
        "cuidados": [
            "Use carga leve e amplitude moderada",
            "Mantenha a coluna neutra durante toda a flexão de quadril",
            "Interrompa ao primeiro sinal de desconforto lombar"
        ]
    },
    "hyperextensions": {
        "nomePT": "Extensão Lombar no Banco Romano",
        "descricaoPT": "Extensão de tronco no banco romano, exercício clássico para os eretores da espinha.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Não hiperextenda o tronco além da linha do corpo",
            "Ajuste o apoio na altura do quadril, não das costelas",
            "Comece sem carga adicional"
        ]
    },
    "back-extension-stability-ball": {
        "nomePT": "Extensão Lombar na Bola",
        "descricaoPT": "Extensão de tronco sobre a bola, com menor sobrecarga e mais estabilização.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Estabilize a bola e os pés antes de iniciar",
            "Suba apenas até o alinhamento do tronco",
            "Mantenha o movimento lento e sem impulso"
        ]
    },
    "supermans": {
        "nomePT": "Superman no Solo",
        "descricaoPT": "Extensão simultânea de braços e pernas no solo, de baixo impacto para a lombar.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.75,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Eleve apenas até onde não sentir desconforto na lombar",
            "Mantenha o pescoço alinhado com a coluna",
            "Não faça movimentos rápidos ou com impulso"
        ]
    },

    # ══ QUADRÍCEPS ══════════════════════════

    "barbell-squat": {
        "nomePT": "Agachamento Livre com Barra",
        "descricaoPT": "Principal exercício de membros inferiores, com alta demanda de força e estabilidade.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.95,
        "escoreRiscoLesao": 0.45,
        "cuidados": [
            "Mantenha a coluna neutra e o core contraído",
            "Desça com os joelhos alinhados aos pés, sem deixá-los cair para dentro",
            "Use os pinos de segurança do rack e aprenda a técnica com carga leve"
        ]
    },
    "front-squat-with-barbell": {
        "nomePT": "Agachamento Frontal com Barra",
        "descricaoPT": "Agachamento com a barra à frente, que aumenta a demanda de quadríceps e tronco ereto.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.92,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Mantenha os cotovelos altos para a barra não escorregar",
            "Exige boa mobilidade de punho e ombro",
            "Não deixe o tronco cair à frente"
        ]
    },
    "squats-using-dumbbells": {
        "nomePT": "Agachamento com Halteres",
        "descricaoPT": "Agachamento com halteres ao lado do corpo, mais simples de aprender que a versão com barra.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha o tronco ereto e o olhar à frente",
            "Não deixe os joelhos passarem muito à frente dos pés",
            "Desça até onde conseguir manter a lombar neutra"
        ]
    },
    "leg-press": {
        "nomePT": "Leg Press",
        "descricaoPT": "Empurrar de pernas na máquina, com trajetória guiada e pouca exigência de equilíbrio.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Não estenda os joelhos de forma travada no topo",
            "Mantenha a lombar apoiada — não deixe o quadril descolar",
            "Não desça além do ponto em que a lombar se mantém apoiada"
        ]
    },
    "narrow-stance-leg-press": {
        "nomePT": "Leg Press com Pernas Juntas",
        "descricaoPT": "Variação do leg press com os pés juntos, que enfatiza a porção lateral do quadríceps.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Mantenha os joelhos alinhados, sem deixá-los cair para fora",
            "Não trave os joelhos no final do movimento",
            "Use amplitude em que a lombar permaneça apoiada"
        ]
    },
    "hack-squat-machine": {
        "nomePT": "Agachamento Hack na Máquina",
        "descricaoPT": "Agachamento guiado na máquina hack, com grande sobrecarga no quadríceps.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.91,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Apoie bem as costas e os ombros no aparelho",
            "Não desça além de onde mantém o quadril apoiado",
            "Mantenha os pés firmes em toda a planta"
        ]
    },
    "leg-extensions": {
        "nomePT": "Cadeira Extensora",
        "descricaoPT": "Isolamento do quadríceps na cadeira extensora.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Alinhe o eixo da máquina com a articulação do joelho",
            "Não estenda de forma brusca nem use impulso",
            "Reduza a amplitude inicial se sentir desconforto no joelho"
        ]
    },
    "smith-machine-squats": {
        "nomePT": "Agachamento no Smith",
        "descricaoPT": "Agachamento na barra guiada do Smith, que reduz a exigência de equilíbrio.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Posicione os pés um pouco à frente para proteger os joelhos",
            "Mantenha a coluna neutra apesar da barra guiada",
            "Trave os ganchos de segurança antes de iniciar"
        ]
    },
    "rear-lunges-with-dumbbell": {
        "nomePT": "Afundo para Trás com Halteres",
        "descricaoPT": "Afundo com passada para trás, unilateral, com menor estresse no joelho da frente.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha o tronco ereto durante a passada",
            "Apoie o pé de trás na ponta, sem bater o joelho no chão",
            "Use apoio próximo se faltar equilíbrio"
        ]
    },
    "step-ups-with-dumbbells": {
        "nomePT": "Subida no Banco com Halteres",
        "descricaoPT": "Subida unilateral em banco ou caixa, com forte componente funcional.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Use altura em que o joelho não passe de 90 graus",
            "Apoie o pé inteiro na plataforma",
            "Suba com a perna de apoio, sem impulso da perna de trás"
        ]
    },

    # ══ POSTERIOR DE COXA ═══════════════════

    "lying-leg-curl-machine": {
        "nomePT": "Mesa Flexora",
        "descricaoPT": "Isolamento dos isquiotibiais na mesa flexora, deitado de bruços.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Ajuste o rolo acima do tendão de Aquiles, não sobre ele",
            "Mantenha o quadril apoiado — não eleve a pelve",
            "Controle a volta sem deixar o peso cair"
        ]
    },
    "seated-leg-curl": {
        "nomePT": "Cadeira Flexora",
        "descricaoPT": "Flexão de joelhos sentado, com os isquiotibiais sob maior alongamento.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Ajuste o encosto e o rolo antes de iniciar",
            "Mantenha as costas apoiadas",
            "Não use impulso de tronco para completar a repetição"
        ]
    },
    "standing-leg-curls": {
        "nomePT": "Flexora em Pé",
        "descricaoPT": "Flexão unilateral de joelho em pé, útil para corrigir assimetrias entre as pernas.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha o quadril estável, sem rodar o tronco",
            "Segure no apoio para não compensar com a lombar",
            "Use carga leve e amplitude completa"
        ]
    },
    "romanian-dead-lift": {
        "nomePT": "Levantamento Terra Romeno",
        "descricaoPT": "Dobradiça de quadril que é o principal exercício de alongamento sob carga dos isquiotibiais.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.92,
        "escoreRiscoLesao": 0.35,
        "cuidados": [
            "Mantenha a coluna neutra — o movimento vem do quadril, não da lombar",
            "Desça a barra deslizando pelas pernas, com joelhos levemente flexionados",
            "Pare a descida quando a lombar começar a arredondar"
        ]
    },
    "barbell-lunges": {
        "nomePT": "Afundo com Barra",
        "descricaoPT": "Afundo com barra nas costas, que soma carga alta ao trabalho unilateral.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Domine o afundo sem carga antes de usar a barra",
            "Mantenha o tronco ereto e o core contraído",
            "Não deixe o joelho da frente desalinhar para dentro"
        ]
    },
    "dumbbell-lunges": {
        "nomePT": "Afundo com Halteres",
        "descricaoPT": "Afundo com halteres ao lado do corpo, mais estável que a versão com barra.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha o tronco ereto durante todo o movimento",
            "Apoie o pé da frente por inteiro",
            "Use um apoio próximo se tiver dificuldade de equilíbrio"
        ]
    },
    "walking-lunges": {
        "nomePT": "Afundo Caminhando",
        "descricaoPT": "Afundo em deslocamento, com maior demanda de equilíbrio e coordenação.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Dê passos de comprimento confortável",
            "Não deixe o joelho de trás bater no chão",
            "Execute em espaço livre e piso não escorregadio"
        ]
    },
    "jefferson-squats-with-barbell": {
        "nomePT": "Agachamento Jefferson",
        "descricaoPT": "Agachamento com a barra entre as pernas e pegada alternada; movimento assimétrico avançado.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Exercício avançado e assimétrico — alterne o lado da pegada entre as séries",
            "Mantenha a coluna neutra, sem rodar o tronco",
            "Comece com carga leve para aprender o padrão de movimento"
        ]
    },

    # ══ GLÚTEOS ═════════════════════════════

    "bridging": {
        "nomePT": "Elevação de Pelve",
        "descricaoPT": "Extensão de quadril deitado, exercício base para ativação dos glúteos.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.82,
        "escoreRiscoLesao": 0.05,
        "cuidados": [
            "Suba o quadril contraindo os glúteos, sem forçar a lombar",
            "Mantenha o core contraído para não arquear as costas",
            "Pause no topo e desça de forma controlada"
        ]
    },
    "one-legged-cable-kickback": {
        "nomePT": "Coice de Glúteo no Cabo",
        "descricaoPT": "Extensão de quadril unilateral no cabo, com tensão constante no glúteo.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha o tronco estável, sem arquear a lombar",
            "Estenda o quadril sem rodar a pelve",
            "Use carga leve e foque na contração do glúteo"
        ]
    },
    "body-leg-lifts": {
        "nomePT": "Elevação de Perna em Quatro Apoios",
        "descricaoPT": "Extensão de quadril no peso corporal, indicada para ativação e para iniciantes.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.78,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o abdômen contraído e a lombar neutra",
            "Eleve a perna sem rodar o quadril",
            "Pare quando a lombar começar a arquear"
        ]
    },
    "thigh-abductor": {
        # Fonte classifica como "quadriceps"; é uma abdução de quadril (glúteo médio).
        "grupo": "GLUTEOS",
        "nomePT": "Cadeira Abdutora",
        "descricaoPT": "Abdução de quadril na máquina, com foco no glúteo médio.",
        "vetorForca": "angular",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha as costas apoiadas no encosto",
            "Abra as pernas de forma controlada, sem impulso",
            "Retorne devagar, sem deixar o peso bater"
        ]
    },

    # ══ PANTURRILHA ═════════════════════════

    "standing-calf-raises-using-machine": {
        "nomePT": "Panturrilha em Pé na Máquina",
        "descricaoPT": "Flexão plantar em pé na máquina, principal exercício para o gastrocnêmio.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Use amplitude completa, descendo o calcanhar abaixo do apoio",
            "Não flexione os joelhos para dar impulso",
            "Faça o movimento lento, com pausa no topo"
        ]
    },
    "standing-barbell-calf-raise": {
        "nomePT": "Panturrilha em Pé com Barra",
        "descricaoPT": "Flexão plantar em pé com barra nas costas, sem necessidade de máquina específica.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Execute próximo a um rack ou apoio para manter o equilíbrio",
            "Mantenha os joelhos estendidos, mas não travados",
            "Suba e desça devagar, sem balançar o tronco"
        ]
    },
    "seated-calf-raise-with-barbell": {
        "nomePT": "Panturrilha Sentado com Barra",
        "descricaoPT": "Flexão plantar sentado, com o joelho flexionado, que enfatiza o sóleo.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Apoie a barra sobre as coxas com proteção",
            "Mantenha os joelhos flexionados a cerca de 90 graus",
            "Use amplitude completa, alongando no final da descida"
        ]
    },
    "calves-press-on-leg-machine": {
        "nomePT": "Panturrilha no Leg Press",
        "descricaoPT": "Flexão plantar executada no leg press, com carga alta e trajetória guiada.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha os joelhos levemente flexionados, nunca travados",
            "Apoie a ponta dos pés na plataforma com firmeza",
            "Trave a segurança do aparelho antes de iniciar"
        ]
    },
    "donkey-calf-raises": {
        "nomePT": "Panturrilha Burro",
        "descricaoPT": "Flexão plantar com o tronco inclinado à frente, que aumenta o alongamento do gastrocnêmio.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha a coluna neutra com o tronco inclinado",
            "Apoie bem as mãos para estabilizar o tronco",
            "Não flexione os joelhos durante o movimento"
        ]
    },
    "rocking-standing-calf-raise-with-barbell": {
        "nomePT": "Panturrilha Alternada com Barra",
        "descricaoPT": "Variação em pé que alterna flexão plantar e dorsiflexão com barra nas costas.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Faça a transição devagar para não perder o equilíbrio",
            "Use carga leve — o movimento é instável",
            "Execute próximo a um apoio"
        ]
    },
    "smith-machine-reverse-calf-raises": {
        "nomePT": "Panturrilha Inversa no Smith",
        "descricaoPT": "Dorsiflexão com barra guiada, que trabalha o tibial anterior, antagonista da panturrilha.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.75,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Use carga leve — o tibial anterior é um músculo pequeno",
            "Mantenha os calcanhares firmes no apoio",
            "Não force a amplitude da dorsiflexão"
        ]
    },
}

# ─────────────────────────────────────────────
# Traduções
# ─────────────────────────────────────────────
EQUIPAMENTO_PT = {
    "barbell": "barra",
    "bar": "barra_fixa",
    "dumbbell": "haltere",
    "dumbbells": "haltere",
    "dumbell": "haltere",            # typo da fonte
    "cable": "cabo",
    "cable machine": "cabo",
    "machine": "maquina",
    "body": "peso_corporal",
    "bodyweight": "peso_corporal",
    "ez-bar": "barra_w",
    "bench": "banco",
    "flat bench": "banco_reto",
    "incline bench": "banco_inclinado",
    "decline bench": "banco_declinado",
    "hyperextension bench": "banco_romano",
    "smith machine": "smith",
    "pull-up bar": "barra_fixa",
    "parallel bars": "barras_paralelas",
    "rope": "corda",
    "band": "elastico",
    "bands": "elastico",
    "exercise band": "elastico",
    "exercise ball": "bola",
    "swiss ball": "bola",
    "stability ball": "bola",
    "bosu ball": "bosu",
    "balance board": "prancha_equilibrio",
    "medicine ball": "medicine_ball",
    "weight plate": "anilha",
    "weight": "peso",
    "t-bar machine": "maquina_t_bar",
    "butterfly machine": "maquina_voador",
    "chest machine": "maquina_peito",
    "bench press machine": "maquina_supino",
    "v-bar": "triangulo",
    # A fonte às vezes registra alternativas num único campo
    "barbell or dumbbell": ["barra", "haltere"],
}

MUSCULO_PT = {
    "biceps": "biceps",
    "bicpes": "biceps",              # typo da fonte
    "triceps": "triceps",
    "forearm": "antebraco",
    "forerm": "antebraco",           # typo da fonte
    "brachialis": "braquial",
    "brachioradialis": "braquiorradial",
    "chest": "peito",
    "shoulders": "ombros",
    "should": "ombros",              # typo da fonte
    "lateral deltoid": "deltoide_medial",
    "rear deltoid": "deltoide_posterior",
    "posterior deltoid": "deltoide_posterior",
    "back": "costas",
    "lats": "dorsais",
    "middle back": "costas_media",
    "upper back": "costas_superior",
    "lower back": "lombar",
    "trapezius": "trapezio",
    "core": "core",
    "abdominals": "abdomen",
    "lower abdominals": "abdomen_inferior",
    "obliques": "obliquos",
    "quadriceps": "quadriceps",
    "hamstrings": "posterior_coxa",
    "hamstring": "posterior_coxa",
    "gluts": "gluteos",
    "glutes": "gluteos",
    "hip abductors": "abdutores",
    "calves": "panturrilha",
    "neck": "cervical",
}


def traduzir_lista(lista, dicionario):
    """Traduz e achata a lista; uma entrada do mapa pode render vários termos."""
    saida = []
    for item in lista:
        traducao = dicionario.get(item, item)
        for termo in (traducao if isinstance(traducao, list) else [traducao]):
            if termo not in saida:
                saida.append(termo)
    return saida


def montar_frames(ex):
    """
    Alguns registros do Everkinetic vêm com `img` vazio mesmo tendo imagem
    publicada. Nesses casos o caminho é derivado do slug, que é o padrão de
    nomenclatura do dataset — o mesmo que a base beta v1 já usava.
    """
    img = ex.get("img") or []
    if len(img) >= 2:
        return img
    slug = ex.get("name", "")
    return [f"_images/web/{slug}-1.png", f"_images/web/{slug}-2.png"]


def limpar_steps(steps):
    """
    O dataset traz resíduo de HTML: passos só com `&nbsp;` e títulos em tag.
    O app mostra os steps como texto puro, então a tag apareceria literalmente.
    """
    limpos = []
    for s in steps:
        s = re.sub(r"<[^>]+>", "", s)
        s = s.replace("&nbsp;", " ").replace(" ", " ")
        s = re.sub(r"\s+", " ", s).strip()
        if s:
            limpos.append(s)
    return limpos


def carregar_steps_pt():
    """Traduções dos steps, por slug. Ausentes, os steps ficam em inglês."""
    try:
        with open(STEPS_PT, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"⚠️  {STEPS_PT} não encontrado — os steps sairão em inglês.")
        return {}


def processar_exercicio(ex, extras, steps_pt):
    primary = (ex.get("primary") or "").strip().lower()
    grupo = extras.get("grupo") or GRUPO_POR_PRIMARY.get(primary)
    slug = ex.get("name", "")

    # A tradução só entra se tiver a mesma quantidade de passos do original:
    # um descompasso significa que a fonte mudou e o texto está desalinhado.
    steps = limpar_steps(ex.get("steps") or [])
    traduzidos = limpar_steps(steps_pt.get(slug) or [])
    if traduzidos and len(traduzidos) == len(steps):
        steps = traduzidos

    return {
        "id": str(ex["id"]),
        "slug": ex.get("name", ""),
        "nome": extras.get("nomePT") or ex.get("title", ""),
        "descricao": extras.get("descricaoPT") or ex.get("primer", ""),
        "musculoPrimario": grupo,
        "musculoDetalhe": MUSCULO_PT.get(primary, primary),
        "musculoSecundario": traduzir_lista(ex.get("secondary") or [], MUSCULO_PT),
        "tipo": extras.get("tipo") or ex.get("type") or "",
        "equipamento": traduzir_lista(ex.get("equipment") or [], EQUIPAMENTO_PT),
        "frames": montar_frames(ex),
        "steps": steps,
        "cuidados": extras.get("cuidados", []),
        "vetorForca": extras["vetorForca"],
        "planoMovimento": extras["planoMovimento"],
        "ativacaoMuscular": extras["ativacaoMuscular"],
        "escoreRiscoLesao": extras["escoreRiscoLesao"],
        "fonte": "everkinetic",
        "versao": VERSAO
    }


def main():
    entrada = sys.argv[1] if len(sys.argv) > 1 else ENTRADA_PADRAO
    saida = sys.argv[2] if len(sys.argv) > 2 else SAIDA_PADRAO
    # Pastas opcionais onde conferir se os PNGs dos frames realmente existem
    pastas_img = sys.argv[3:]

    try:
        with open(entrada, "r", encoding="utf-8") as f:
            todos = json.load(f)
    except FileNotFoundError:
        print(f"❌ Dataset de origem não encontrado: {entrada}")
        print("   Informe o caminho: python gerar_base_appgym.py <exercises.json> [saida.json]")
        sys.exit(1)

    steps_pt = carregar_steps_pt()

    por_slug = {ex["name"]: ex for ex in todos}
    processados = []
    nao_encontrados = []
    sem_grupo = []
    sem_imagem = []
    sem_traducao = []

    for slug, extras in EXERCICIOS_SELECIONADOS.items():
        if slug not in por_slug:
            nao_encontrados.append(slug)
            continue

        registro = processar_exercicio(por_slug[slug], extras, steps_pt)

        if not registro["musculoPrimario"]:
            sem_grupo.append(slug)
            continue

        traduzido = limpar_steps(steps_pt.get(slug) or [])
        if not traduzido or len(traduzido) != len(limpar_steps(por_slug[slug].get("steps") or [])):
            sem_traducao.append(slug)

        faltando = [
            os.path.basename(f) for f in registro["frames"]
            if not any(os.path.exists(os.path.join(p, os.path.basename(f)))
                       for p in pastas_img)
        ]
        if pastas_img and faltando:
            sem_imagem.append(f"{slug}: {', '.join(faltando)}")

        processados.append(registro)

    # Ordena por grupo (ORDEM_GRUPOS) e, dentro do grupo, pelo nome em português
    ordem = {g: i for i, g in enumerate(ORDEM_GRUPOS)}
    processados.sort(key=lambda e: (ordem.get(e["musculoPrimario"], 99), e["nome"]))

    por_grupo = Counter(e["musculoPrimario"] for e in processados)
    grupos = [g for g in ORDEM_GRUPOS if por_grupo[g]]

    saida_json = {
        "versao": VERSAO,
        "escopo": ESCOPO,
        "grupos": grupos,
        "total": len(processados),
        "totalPorGrupo": {g: por_grupo[g] for g in grupos},
        "exercicios": processados
    }

    with open(saida, "w", encoding="utf-8") as f:
        json.dump(saida_json, f, ensure_ascii=False, indent=2)

    print(f"✅ Base gerada: {saida}")
    for g in grupos:
        print(f"   → {g:12} {por_grupo[g]:3} exercícios")
    print(f"   → {'TOTAL':12} {len(processados):3} exercícios")

    if nao_encontrados:
        print(f"\n⚠️  {len(nao_encontrados)} slug(s) não encontrado(s) no dataset de origem:")
        for s in nao_encontrados:
            print(f"   - {s}")

    if sem_grupo:
        print(f"\n⚠️  {len(sem_grupo)} exercício(s) sem grupo mapeado (descartados):")
        for s in sem_grupo:
            print(f"   - {s}")

    if sem_imagem:
        print(f"\n⚠️  {len(sem_imagem)} exercício(s) com PNG ausente nas pastas informadas:")
        for s in sem_imagem:
            print(f"   - {s}")

    traduzidos = len(processados) - len(sem_traducao)
    print(f"\n🌐 steps em português: {traduzidos}/{len(processados)}")
    if sem_traducao:
        print("   sem tradução (ou com número de passos divergente):")
        for s in sem_traducao:
            print(f"   - {s}")

    if not (nao_encontrados or sem_grupo or sem_imagem):
        print("\n✅ Todos os exercícios foram encontrados e processados!")


if __name__ == "__main__":
    main()
