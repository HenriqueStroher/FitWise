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

O exercises.json é o da raiz de https://github.com/everkinetic/data
(licença CC BY-SA 4.0). Um clone raso basta:
    git clone --depth 1 https://github.com/everkinetic/data everkinetic-data

As imagens são baixadas à parte, por baixar_imagens_everkinetic.py.
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
    "hip abductors": "GLUTEOS",
    # Sem grupo próprio; ficam em Quadríceps, como na fonte. Não vão para
    # Glúteos porque lá a recomendação os trocaria pela cadeira abdutora,
    # que faz o movimento oposto.
    "adductors": "QUADRICEPS",
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
#   primary      — sobrepõe o `primary` da fonte (em inglês, como na fonte);
#                  muda o grupo (se `grupo` não vier) e o `musculoDetalhe`
#   secundarios  — lista final de `musculoSecundario` (códigos do app)
#   equipamento  — lista final de `equipamento` (códigos do app), para quando
#                  a fonte está vazia ou não bate com a ilustração
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
    "biceps-hammer-curl-with-dumbbell": {
        "nomePT": "Rosca Martelo com Halteres",
        "descricaoPT": "Rosca com as palmas voltadas uma para a outra, que trabalha bíceps, braquial e antebraço.",
        "secundarios": ["braquial", "antebraco"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha as palmas voltadas uma para a outra durante todo o movimento",
            "Cotovelos fixos ao lado do corpo",
            "Não balance o tronco para subir o peso"
        ]
    },
    "cross-body-hammer-curl-with-dumbbell": {
        "nomePT": "Rosca Martelo Cruzada",
        "descricaoPT": "Rosca martelo levando o haltere em direção ao ombro oposto, com ênfase no braquial.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Não gire o punho: a palma fica voltada para o corpo",
            "Mantenha o cotovelo próximo ao tronco",
            "Alterne os braços sem balançar o corpo"
        ]
    },
    "biceps-curl-reverse-with-dumbbells": {
        "nomePT": "Rosca Inversa com Halteres",
        "descricaoPT": "Rosca com as palmas voltadas para baixo, que transfere boa parte do esforço para o braquiorradial e o antebraço.",
        "secundarios": ["braquiorradial", "antebraco"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Use carga menor que na rosca tradicional",
            "Mantenha os punhos alinhados com os antebraços",
            "Cotovelos fixos ao lado do corpo"
        ]
    },
    "preacher-curl-with-machine": {
        "nomePT": "Rosca Scott na Máquina",
        "descricaoPT": "Rosca Scott com trajetória guiada, boa para iniciantes e para isolar o bíceps com segurança.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o banco para que as axilas fiquem apoiadas no topo do apoio",
            "Não estenda o cotovelo de forma brusca no final da descida",
            "Mantenha os braços apoiados o tempo todo"
        ]
    },
    "one-arm-preacher-curl-with-dumbbell": {
        "nomePT": "Rosca Scott Unilateral com Haltere",
        "descricaoPT": "Rosca Scott com um braço de cada vez, que permite corrigir diferenças de força entre os lados.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.91,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha o braço apoiado no banco durante toda a repetição",
            "Não estenda totalmente o cotovelo com carga alta",
            "Faça o mesmo número de repetições com os dois braços"
        ]
    },
    "preacher-curl-with-cable": {
        "nomePT": "Rosca Scott no Cabo",
        "descricaoPT": "Rosca Scott com a polia baixa, que mantém tensão no bíceps também no fim da subida.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Posicione o banco Scott alinhado com a polia",
            "Mantenha os braços apoiados no banco",
            "Controle o retorno do cabo, sem deixar o peso bater"
        ]
    },
    "spider-curl-with-barbell": {
        "nomePT": "Rosca Spider com Barra",
        "descricaoPT": "Rosca feita com o peito apoiado no lado reto do banco Scott, com os braços na vertical.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Comece com carga leve para se acostumar à posição",
            "Mantenha o peito apoiado no banco",
            "Não balance os braços para frente para subir a barra"
        ]
    },
    "biceps-curl-with-machine": {
        "nomePT": "Rosca Bíceps na Máquina",
        "descricaoPT": "Rosca sentada na máquina, com os braços apoiados e trajetória guiada.",
        "equipamento": ["maquina"],
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Alinhe o cotovelo com o eixo de giro da máquina",
            "Mantenha os braços apoiados nas almofadas",
            "Desça devagar, sem deixar o peso bater"
        ]
    },

    # ══ TRÍCEPS ═════════════════════════════

    "triceps-pushdown-with-cable": {
        "nomePT": "Tríceps Pulley com Barra",
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
        # O slug e os passos da fonte falam em haltere, mas a ilustração mostra
        # uma barra atrás da cabeça. Nome, equipamento e passos (steps_pt.json)
        # seguem a ilustração, que é o que o usuário vê.
        "nomePT": "Tríceps Francês Sentado com Barra",
        "descricaoPT": "Extensão de tríceps sentado, com a barra descendo atrás da cabeça, focando na cabeça longa do tríceps.",
        "equipamento": ["barra", "banco"],
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
        "nomePT": "Tríceps Corda",
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
        "nomePT": "Tríceps Pulley com Pegada Inversa",
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
        # A ilustração própria deste slug mostra um cabo; os passos falam em
        # haltere. As imagens vêm de standing-triceps-extension-2, que é o
        # mesmo exercício com haltere (ver baixar_imagens_everkinetic.py).
        "nomePT": "Tríceps Francês com Haltere",
        "descricaoPT": "Extensão de tríceps em pé, com um haltere seguro pelas duas mãos atrás da cabeça.",
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
    "lying-triceps-press-with-barbell": {
        "nomePT": "Tríceps Testa com Barra",
        "descricaoPT": "Extensão de tríceps deitado, descendo a barra em direção à testa; um dos exercícios de tríceps mais usados.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha os cotovelos apontados para o teto e próximos entre si",
            "Desça a barra devagar — o erro de controle aqui vai em direção ao rosto",
            "Prefira a barra W se sentir desconforto nos punhos"
        ]
    },
    "lying-triceps-extension-with-dumbbells": {
        "nomePT": "Tríceps Testa com Haltere",
        "descricaoPT": "Extensão de tríceps deitado com um haltere seguro pelas duas mãos, descendo atrás da cabeça.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Segure o haltere com firmeza pela anilha de cima",
            "Mexa só os cotovelos; os braços ficam parados",
            "Não desça além do ponto em que mantém o controle"
        ]
    },
    "standing-one-arm-triceps-extension-with-dumbbell": {
        "nomePT": "Tríceps Francês Unilateral com Haltere",
        "descricaoPT": "Extensão de tríceps em pé com um braço de cada vez, com o haltere descendo atrás da cabeça.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha o cotovelo apontado para cima e próximo à cabeça",
            "Contraia o abdômen para não arquear a lombar",
            "Use carga leve e faça o mesmo volume nos dois braços"
        ]
    },
    "triceps-pushdown-with-v-bar-and-cable": {
        "nomePT": "Tríceps Pulley com Barra V",
        "descricaoPT": "Tríceps no pulley com a barra em V, que deixa os punhos numa posição mais confortável que a barra reta.",
        "equipamento": ["cabo", "barra_v"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os cotovelos fixos ao lado do corpo",
            "Estenda os braços por completo embaixo, sem inclinar o tronco",
            "Controle a subida da barra"
        ]
    },
    "one-arm-tricep-extension-with-cable": {
        "nomePT": "Tríceps Unilateral no Cabo",
        "descricaoPT": "Tríceps no pulley com um braço e pegada supinada, que ajuda a equilibrar a força entre os lados.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o cotovelo colado ao corpo",
            "Não gire o tronco para ajudar o braço",
            "Use carga leve — o movimento é unilateral"
        ]
    },
    "triceps-extensions-using-machine": {
        "nomePT": "Tríceps na Máquina",
        "descricaoPT": "Extensão de tríceps sentado na máquina, com os braços apoiados e trajetória guiada.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o banco para os braços ficarem apoiados por inteiro na almofada",
            "Mantenha as costas retas e os pés no chão",
            "Volte devagar, sem deixar o peso bater"
        ]
    },
    "close-grip-barbell-bench-press": {
        # A fonte rotula como peito; no treino ele é usado como exercício de tríceps.
        "grupo": "TRICEPS",
        "primary": "triceps",
        "secundarios": ["peito", "ombros"],
        "nomePT": "Supino Fechado",
        "descricaoPT": "Supino com a pegada na largura dos ombros, que desloca o esforço para o tríceps.",
        "tipo": "compound",
        "equipamento": ["barra", "banco_reto"],
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Não feche demais a pegada — na largura dos ombros já basta",
            "Mantenha os cotovelos próximos ao tronco na descida",
            "Use parceiro ou suporte de segurança em cargas altas"
        ]
    },
    "bench-dips": {
        "nomePT": "Tríceps Banco",
        "descricaoPT": "Mergulho com as mãos em um banco atrás do corpo e os pés apoiados à frente, no peso do corpo.",
        "tipo": "compound",
        "equipamento": ["peso_corporal", "banco"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.82,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Não desça além de 90 graus no cotovelo",
            "Mantenha o quadril próximo ao banco",
            "Evite se sentir dor na frente do ombro"
        ]
    },
    "close-triceps-pushup": {
        "nomePT": "Flexão Fechada (Tríceps)",
        "descricaoPT": "Flexão de braço com as mãos juntas, que enfatiza o tríceps.",
        "tipo": "compound",
        "secundarios": ["peito", "ombros", "core"],
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o corpo alinhado da cabeça aos pés",
            "Cotovelos próximos ao tronco na descida",
            "Apoie os joelhos no chão se não conseguir manter a postura"
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
        "nomePT": "Voador (Peck Deck)",
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
    "machine-bench-press": {
        "nomePT": "Supino na Máquina",
        "descricaoPT": "Supino sentado na máquina, com trajetória guiada; bom para iniciantes e para treinar perto da falha com segurança.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o banco para as pegadas ficarem na linha do meio do peito",
            "Mantenha as costas e a cabeça apoiadas no encosto",
            "Não estenda os cotovelos de forma brusca no final"
        ]
    },
    "incline-chest-press": {
        "nomePT": "Supino Inclinado na Máquina",
        "descricaoPT": "Supino inclinado guiado na máquina, com foco na porção superior do peitoral.",
        "tipo": "compound",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o banco para as pegadas ficarem na parte alta do peito",
            "Não trave os cotovelos no final",
            "Mantenha as escápulas apoiadas no encosto"
        ]
    },
    "smith-machine-bench-press": {
        "nomePT": "Supino Reto no Smith",
        "descricaoPT": "Supino reto na barra guiada, que dispensa o equilíbrio da barra e facilita treinar sem parceiro.",
        "tipo": "compound",
        "equipamento": ["smith", "banco_reto"],
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Posicione o banco para a barra descer na linha do meio do peito",
            "Ajuste as travas de segurança antes de começar",
            "Não deixe a barra quicar no peito"
        ]
    },
    "smith-machine-incline-bench-press": {
        "nomePT": "Supino Inclinado no Smith",
        "descricaoPT": "Supino inclinado na barra guiada, com foco na porção superior do peitoral.",
        "tipo": "compound",
        "equipamento": ["smith", "banco_inclinado"],
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Posicione o banco para a barra descer na parte alta do peito",
            "Use inclinação entre 30 e 45 graus",
            "Ajuste as travas de segurança antes de começar"
        ]
    },
    "decline-dumbbell-bench-press": {
        "nomePT": "Supino Declinado com Halteres",
        "descricaoPT": "Supino com halteres em banco declinado, com ênfase na porção inferior do peitoral.",
        "tipo": "compound",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Prenda bem as pernas no apoio antes de pegar os halteres",
            "Desça os halteres na linha da parte baixa do peito",
            "Evite o exercício se sentir tontura de cabeça para baixo"
        ]
    },
    "flat-bench-cable-flys": {
        "nomePT": "Crucifixo no Cabo",
        "descricaoPT": "Crucifixo deitado entre duas polias baixas, com tensão no peitoral em toda a amplitude.",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha os cotovelos levemente flexionados e fixos",
            "Não desça os braços abaixo da linha do banco",
            "Mantenha costas e quadril apoiados no banco"
        ]
    },
    "incline-cable-flys": {
        "nomePT": "Crucifixo Inclinado no Cabo",
        "descricaoPT": "Crucifixo em banco inclinado entre duas polias, com foco na porção superior do peitoral.",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "secundarios": ["ombros"],
        "cuidados": [
            "Cotovelos levemente flexionados durante todo o arco",
            "Una as mãos acima do peito sem bater as pegadas",
            "Volte devagar pelo mesmo arco"
        ]
    },
    "straight-arm-dumbbell-pullover": {
        "nomePT": "Pullover com Haltere",
        "descricaoPT": "Arco com o haltere por trás da cabeça, deitado no banco, que trabalha peitoral e dorsais.",
        "secundarios": ["dorsais", "triceps", "ombros"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha os cotovelos levemente flexionados e fixos",
            "Desça atrás da cabeça só até onde o ombro permite sem dor",
            "Segure o haltere com firmeza com as duas mãos"
        ]
    },
    "chest-dips": {
        "nomePT": "Mergulho nas Paralelas",
        "descricaoPT": "Mergulho com o tronco inclinado à frente, que trabalha peitoral inferior, tríceps e ombros.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.35,
        "cuidados": [
            "Incline o tronco à frente para enfatizar o peitoral",
            "Desça só até os ombros ficarem na altura dos cotovelos",
            "Evite se sentir dor na frente do ombro"
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
        "nomePT": "Remada Baixa no Cabo",
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
    "rear-deltoid-row-barbell": {
        # A fonte rotula como deltoide posterior, mas é a remada curvada pronada.
        "grupo": "COSTAS",
        "primary": "middle back",
        "secundarios": ["dorsais", "deltoide_posterior", "biceps"],
        "nomePT": "Remada Curvada com Barra",
        "descricaoPT": "Remada curvada com pegada pronada, um dos exercícios base para a espessura das costas.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.40,
        "cuidados": [
            "Mantenha a coluna neutra e o core contraído durante todo o movimento",
            "Puxe a barra até a parte baixa do peito, sem dar tranco com o tronco",
            "Reduza a carga se a lombar começar a arredondar"
        ]
    },
    "smith-machine-rear-deltoid-row": {
        "grupo": "COSTAS",
        "primary": "middle back",
        "secundarios": ["deltoide_posterior", "biceps"],
        "nomePT": "Remada Curvada no Smith",
        "descricaoPT": "Remada curvada na barra guiada, que dispensa o equilíbrio da barra livre.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Coloque a barra na altura mais baixa antes de se posicionar",
            "Mantenha a coluna neutra com o tronco inclinado",
            "Leve os cotovelos para trás e para cima, sem puxar com a lombar"
        ]
    },
    "straight-arm-push-down": {
        "nomePT": "Pulldown com Braços Estendidos",
        "descricaoPT": "Puxada no cabo com os braços quase retos, que isola o dorsal sem envolver o bíceps.",
        "secundarios": ["triceps", "core"],
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.82,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha os cotovelos levemente flexionados e fixos",
            "Leve a barra até as coxas sem inclinar o tronco à frente",
            "Volte devagar até a altura dos olhos"
        ]
    },
    "body-row": {
        # A fonte rotula como peito; é uma remada no peso corporal.
        "grupo": "COSTAS",
        "primary": "middle back",
        "secundarios": ["biceps", "core"],
        "nomePT": "Remada Invertida",
        "descricaoPT": "Remada no peso do corpo, deitado sob uma barra; boa porta de entrada para a barra fixa.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o corpo reto, sem deixar o quadril cair",
            "Puxe o peito até a barra juntando as escápulas",
            "Dobre os joelhos para facilitar, se precisar"
        ]
    },

    # ══ OMBROS ══════════════════════════════

    "barbell-shoulder-press": {
        # O título da fonte é "Seated Barbell Shoulder Press": a ilustração e
        # os passos são sentados, apesar do slug.
        "nomePT": "Desenvolvimento com Barra Sentado",
        "descricaoPT": "Desenvolvimento sentado em banco com suporte para a barra, exercício base para os ombros.",
        "tipo": "compound",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Mantenha as costas apoiadas e o core contraído, sem arquear a lombar",
            "Não leve a barra atrás da cabeça",
            "Retire e devolva a barra ao suporte com os braços estendidos"
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
        # A fonte rotula como deltoide posterior, mas a ilustração e os passos
        # são a remada unilateral apoiada no banco (serrote), um exercício de costas.
        "grupo": "COSTAS",
        "primary": "middle back",
        "secundarios": ["biceps", "deltoide_posterior"],
        "nomePT": "Remada Unilateral com Haltere (Serrote)",
        "descricaoPT": "Remada com um braço de cada vez, com joelho e mão apoiados no banco; uma das remadas mais usadas para as costas.",
        "tipo": "compound",
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.87,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha a coluna neutra, com o tronco quase paralelo ao chão",
            "Puxe o cotovelo para trás junto ao corpo, sem girar o tronco",
            "Desça o haltere até estender o braço, de forma controlada"
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
    "bent-over-rear-deltoid-raise-with-head-on-bench": {
        "primary": "rear deltoid",
        "secundarios": ["trapezio", "costas_media"],
        "nomePT": "Crucifixo Inverso Curvado com Halteres",
        "descricaoPT": "Abertura dos braços com o tronco inclinado e a testa apoiada no banco, isolando o deltoide posterior.",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Apoie a testa no banco para não usar impulso do tronco",
            "Mantenha os cotovelos levemente flexionados",
            "Suba só até a altura dos ombros, com carga leve"
        ]
    },
    "lying-rear-lateral-raise": {
        "primary": "rear deltoid",
        "secundarios": ["trapezio", "costas_media"],
        "nomePT": "Crucifixo Inverso Deitado com Halteres",
        "descricaoPT": "Crucifixo inverso deitado de bruços no banco, que elimina o balanço do tronco.",
        "vetorForca": "horizontal",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Use um banco alto o bastante para os braços descerem livres",
            "Mantenha os cotovelos com leve flexão fixa",
            "Suba até a linha dos ombros, sem encolher o pescoço"
        ]
    },
    "seated-rear-lateral-cable-raise": {
        "primary": "rear deltoid",
        "secundarios": ["trapezio", "costas_media"],
        "nomePT": "Crucifixo Inverso no Cabo",
        "descricaoPT": "Crucifixo inverso sentado com os cabos cruzados, com tensão constante no deltoide posterior.",
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.85,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Segure cada cabo com a mão do lado oposto",
            "Mantenha o peito apoiado nas coxas e a coluna reta",
            "Controle a volta dos cabos"
        ]
    },
    "front-barbell-raises": {
        "nomePT": "Elevação Frontal com Barra",
        "descricaoPT": "Elevação dos braços à frente segurando a barra, com foco no deltoide anterior.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Suba apenas até a altura dos ombros",
            "Não jogue o tronco para trás para subir a barra",
            "Mantenha os joelhos levemente flexionados e o abdômen firme"
        ]
    },
    "front-cable-raises": {
        "nomePT": "Elevação Frontal no Cabo",
        "descricaoPT": "Elevação frontal unilateral com a polia baixa, com tensão em toda a amplitude.",
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha o braço estendido, com leve flexão no cotovelo",
            "Suba até a altura do ombro e pause",
            "Não gire o tronco para ajudar o braço"
        ]
    },
    "dumbbell-upright-rows": {
        "nomePT": "Remada Alta com Halteres",
        "descricaoPT": "Remada alta com halteres, que trabalha deltoide medial e trapézio com trajetória mais livre que a barra.",
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Não suba os cotovelos acima da linha dos ombros",
            "Mantenha os halteres próximos ao corpo",
            "Evite o exercício se sentir pinçamento no ombro"
        ]
    },
    "upright-cable-row": {
        "nomePT": "Remada Alta no Cabo",
        "descricaoPT": "Remada alta com barra na polia baixa, com tensão constante em deltoide medial e trapézio.",
        "vetorForca": "angular",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.83,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Não suba os cotovelos acima da linha dos ombros",
            "Mantenha a barra próxima ao corpo",
            "Use pegada um pouco mais aberta que os ombros"
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
        "nomePT": "Abdominal Infra",
        "descricaoPT": "Elevação do quadril deitado, com os joelhos flexionados, que trabalha o abdômen inferior com menor estresse lombar.",
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
        "registro": "tempo",
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
    "decline-crunch": {
        "nomePT": "Abdominal Declinado",
        "descricaoPT": "Abdominal no banco declinado, com amplitude e carga maiores que o abdominal no solo.",
        "equipamento": ["banco_declinado"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Prenda bem os pés nos apoios",
            "Não puxe o pescoço com as mãos",
            "Desça devagar, sem cair no banco"
        ]
    },
    "stability-ball-abdominal-crunch": {
        "nomePT": "Abdominal na Bola",
        "descricaoPT": "Abdominal com a lombar apoiada na bola suíça, que aumenta a amplitude do movimento.",
        "equipamento": ["bola"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha os pés afastados e firmes no chão para não rolar",
            "Centralize a lombar no meio da bola",
            "Não puxe a cabeça com as mãos"
        ]
    },
    "cross-body-crunch": {
        "nomePT": "Abdominal Oblíquo Cruzado",
        "descricaoPT": "Abdominal levando o cotovelo em direção ao joelho oposto, com foco nos oblíquos.",
        "secundarios": ["obliquos"],
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Faça a rotação com o tronco, não só com o cotovelo",
            "Não puxe o pescoço com as mãos",
            "Alterne os lados de forma controlada"
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
    "one-leg-squat-with-barbell": {
        "nomePT": "Agachamento Búlgaro com Barra",
        "descricaoPT": "Agachamento unilateral com o pé de trás apoiado num banco, de alta exigência para quadríceps e glúteos.",
        "secundarios": ["gluteos", "posterior_coxa", "panturrilha"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.30,
        "cuidados": [
            "Aprenda o movimento sem carga ou com halteres antes de usar a barra",
            "Desça na vertical, sem deixar o joelho da frente cair para dentro",
            "Apoie só o peito do pé de trás no banco"
        ]
    },
    "pile-squat-with-dumbbell": {
        "nomePT": "Agachamento Sumô com Haltere",
        "descricaoPT": "Agachamento com base larga e pontas dos pés para fora, segurando um haltere; enfatiza adutores e glúteos.",
        "secundarios": ["adutores", "gluteos", "posterior_coxa"],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.20,
        "cuidados": [
            "Mantenha os joelhos na direção das pontas dos pés",
            "Desça com o tronco ereto, sem curvar as costas",
            "Mantenha os pés inteiros apoiados no chão"
        ]
    },
    "thigh-adductor": {
        "primary": "adductors",
        "secundarios": [],
        "nomePT": "Cadeira Adutora",
        "descricaoPT": "Adução de quadril na máquina: as pernas se fecham contra a resistência, trabalhando a parte interna da coxa.",
        "vetorForca": "horizontal",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.82,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste a abertura inicial para uma amplitude confortável",
            "Mantenha as costas apoiadas no encosto",
            "Volte devagar, sem deixar as placas baterem"
        ]
    },
    "hip-adduction": {
        "primary": "adductors",
        "secundarios": [],
        "nomePT": "Adução de Quadril no Cabo",
        "descricaoPT": "Adução em pé com a caneleira presa à polia baixa, uma perna de cada vez.",
        "vetorForca": "horizontal",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.78,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Segure na máquina para manter o equilíbrio",
            "Leve a perna à frente da perna de apoio sem girar o quadril",
            "Use carga leve e faça os dois lados"
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
        "descricaoPT": "Dobradiça de quadril que é o principal exercício de alongamento sob carga dos isquiotibiais. Parecido com o stiff, que mantém os joelhos mais estendidos.",
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
        # Flexão e extensão de joelho e quadril, como nos outros agachamentos.
        # Estava "frontal", o que o fazia ser sugerido no lugar da cadeira adutora.
        "planoMovimento": "sagital",
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
        # "Elevação pélvica" costuma designar a versão com banco e barra (hip thrust).
        "nomePT": "Ponte de Glúteo",
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
        # A ilustração e os passos são em pé, com apoio na parede; não em quatro apoios.
        "nomePT": "Coice em Pé no Peso Corporal",
        "descricaoPT": "Extensão de quadril em pé, sem carga, indicada para ativação dos glúteos e para iniciantes.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.78,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Segure em um apoio para manter o equilíbrio",
            "Leve a perna para trás sem arquear a lombar",
            "Contraia o glúteo no fim do movimento"
        ]
    },
    "thigh-abductor": {
        # Fonte classifica como "quadriceps"; é uma abdução de quadril (glúteo médio).
        "grupo": "GLUTEOS",
        "primary": "hip abductors",
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
    "seated-calf-raise-using-machine": {
        "nomePT": "Panturrilha Sentado na Máquina",
        "descricaoPT": "Flexão plantar sentado na máquina, com os joelhos flexionados, que enfatiza o sóleo.",
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Ajuste o apoio logo acima dos joelhos",
            "Desça o calcanhar até sentir o alongamento",
            "Faça o movimento lento, com pausa no topo"
        ]
    },
}

# ─────────────────────────────────────────────
# Exercícios sem registro no exercises.json
#
# O Everkinetic tem ilustrações, no mesmo traço das outras, que não estão
# ligadas a nenhum exercício (src/images-png-unknown). Estes exercícios usam
# essas ilustrações (ver IMAGENS_SEM_REGISTRO em baixar_imagens_everkinetic.py)
# e têm todo o resto curado aqui, inclusive os passos, já em português.
#
# Campos além dos de EXERCICIOS_SELECIONADOS: grupo, musculoDetalhe,
# secundarios, equipamento, tipo, quadros (quantas imagens) e steps.
# `registro` (opcional) muda o que se anota no treino: "tempo" para isometria.
# ─────────────────────────────────────────────
EXERCICIOS_SEM_REGISTRO = {
    "face-pull": {
        "grupo": "OMBROS",
        "musculoDetalhe": "deltoide_posterior",
        "secundarios": ["trapezio", "costas_media"],
        "equipamento": ["cabo", "corda"],
        "tipo": "isolation",
        "quadros": 2,
        "nomePT": "Face Pull",
        "descricaoPT": "Puxada da corda na polia alta em direção ao rosto, com os cotovelos altos; trabalha deltoide posterior e a musculatura que estabiliza os ombros.",
        "steps": [
            "Ajuste a polia acima da altura da cabeça e prenda a corda.",
            "Segure as pontas da corda com as palmas voltadas uma para a outra e dê um passo para trás, com os braços estendidos à frente.",
            "Puxe a corda em direção ao rosto, abrindo as mãos e levando os cotovelos para os lados, na altura dos ombros.",
            "No fim do movimento, aproxime as escápulas e faça uma pausa.",
            "Volte devagar à posição inicial, sem deixar o peso puxar os braços."
        ],
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.10,
        "cuidados": [
            "Mantenha os cotovelos na altura dos ombros ou acima",
            "Use carga leve: o objetivo é controle, não força máxima",
            "Não incline o tronco para trás para puxar"
        ]
    },
    "plank": {
        "grupo": "ABDOMEN",
        "musculoDetalhe": "abdomen",
        "secundarios": ["core", "ombros", "gluteos"],
        "equipamento": ["peso_corporal"],
        "tipo": "isometric",
        "registro": "tempo",
        "quadros": 1,
        "nomePT": "Prancha",
        "descricaoPT": "Isometria apoiada nos antebraços e nas pontas dos pés, base para a estabilidade do core.",
        "steps": [
            "Deite de bruços e apoie os antebraços no chão, com os cotovelos abaixo dos ombros.",
            "Eleve o corpo apoiando-se nos antebraços e nas pontas dos pés.",
            "Alinhe cabeça, tronco, quadril e pernas, contraindo o abdômen e os glúteos.",
            "Mantenha a posição pelo tempo planejado, respirando normalmente."
        ],
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.80,
        "escoreRiscoLesao": 0.05,
        "cuidados": [
            "Não deixe o quadril cair nem subir demais",
            "Não prenda a respiração",
            "Pare quando não conseguir mais manter o alinhamento"
        ]
    },
    "hanging-knee-raise": {
        "grupo": "ABDOMEN",
        "musculoDetalhe": "abdomen_inferior",
        "secundarios": ["flexores_quadril", "antebraco"],
        "equipamento": ["barra_fixa"],
        "tipo": "isolation",
        "quadros": 2,
        "nomePT": "Elevação de Joelhos na Barra Fixa",
        "descricaoPT": "Elevação dos joelhos pendurado na barra, com foco no abdômen inferior.",
        "steps": [
            "Segure a barra fixa com as mãos na largura dos ombros e fique pendurado, com as pernas estendidas.",
            "Contraia o abdômen para estabilizar o corpo e evitar balanço.",
            "Eleve os joelhos em direção ao peito, enrolando levemente o quadril.",
            "Desça as pernas devagar até a posição inicial."
        ],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.88,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Não use balanço para subir as pernas",
            "Desça controlando, sem soltar o corpo",
            "Pare se a pegada falhar antes do abdômen"
        ]
    },
    "hanging-leg-raise": {
        "grupo": "ABDOMEN",
        "musculoDetalhe": "abdomen_inferior",
        "secundarios": ["flexores_quadril", "antebraco"],
        "equipamento": ["barra_fixa"],
        "tipo": "isolation",
        "quadros": 2,
        "nomePT": "Elevação de Pernas na Barra Fixa",
        "descricaoPT": "Elevação das pernas estendidas até a barra, pendurado; variação avançada da elevação de joelhos.",
        "steps": [
            "Segure a barra fixa com as mãos na largura dos ombros e fique pendurado, com as pernas estendidas.",
            "Contraia o abdômen para estabilizar o corpo.",
            "Com as pernas estendidas, eleve os pés até perto da barra.",
            "Desça as pernas devagar até a posição inicial."
        ],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.92,
        "escoreRiscoLesao": 0.25,
        "cuidados": [
            "Domine a elevação de joelhos antes desta versão",
            "Não use balanço para subir as pernas",
            "Desça de forma controlada"
        ]
    },
    "ab-wheel-rollout": {
        "grupo": "ABDOMEN",
        "musculoDetalhe": "abdomen",
        "secundarios": ["core", "ombros", "dorsais"],
        "equipamento": ["roda_abdominal"],
        "tipo": "compound",
        "quadros": 2,
        "nomePT": "Roda Abdominal",
        "descricaoPT": "Rolamento de joelhos com a roda, um exercício anti-extensão de alta exigência para o core.",
        "steps": [
            "Ajoelhe no chão ou num colchonete e segure a roda com as duas mãos, abaixo dos ombros.",
            "Contraia o abdômen e os glúteos, mantendo a lombar neutra.",
            "Role a roda à frente devagar, estendendo o corpo até onde conseguir sem arquear a lombar.",
            "Puxe a roda de volta com o abdômen até a posição inicial."
        ],
        "vetorForca": "horizontal",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.90,
        "escoreRiscoLesao": 0.35,
        "cuidados": [
            "Não role além do ponto em que controla a lombar",
            "Comece com amplitude curta e aumente aos poucos",
            "Evite se tiver dor lombar"
        ]
    },
    "kneeling-cable-crunch": {
        "grupo": "ABDOMEN",
        "musculoDetalhe": "abdomen",
        "secundarios": ["obliquos"],
        "equipamento": ["cabo", "corda"],
        "tipo": "isolation",
        "quadros": 2,
        "nomePT": "Abdominal na Polia Alta",
        "descricaoPT": "Flexão de tronco ajoelhado, puxando a corda da polia alta; permite aumentar a carga no abdômen.",
        "steps": [
            "Prenda a corda na polia alta e ajoelhe de frente para a máquina.",
            "Segure a corda ao lado da cabeça, com os cotovelos dobrados.",
            "Flexione o tronco levando os cotovelos em direção às coxas, contraindo o abdômen.",
            "Volte devagar à posição inicial, sem deixar o peso puxar o tronco."
        ],
        "vetorForca": "angular",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.89,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "O movimento vem do abdômen, não dos braços nem do quadril",
            "Mantenha o quadril parado durante a flexão",
            "Controle a volta da carga"
        ]
    },
    "cable-woodchop": {
        "grupo": "ABDOMEN",
        "musculoDetalhe": "obliquos",
        "secundarios": ["core", "ombros"],
        "equipamento": ["cabo"],
        "tipo": "compound",
        "quadros": 2,
        "nomePT": "Lenhador no Cabo",
        "descricaoPT": "Rotação do tronco puxando o cabo da polia alta na diagonal, com foco nos oblíquos.",
        "steps": [
            "Ajuste a polia no alto e fique de lado para a máquina, com os pés afastados.",
            "Segure a pegada com as duas mãos, acima do ombro do lado da máquina.",
            "Puxe o cabo na diagonal, para baixo e através do corpo, girando o tronco até o quadril do lado oposto.",
            "Volte devagar pelo mesmo caminho e, ao terminar a série, troque de lado."
        ],
        "vetorForca": "angular",
        "planoMovimento": "transversal",
        "ativacaoMuscular": 0.84,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "A rotação vem do tronco; os braços só conduzem o cabo",
            "Gire o pé de trás junto com o quadril",
            "Use carga moderada e movimento controlado"
        ]
    },
    "side-lying-hip-abduction": {
        "grupo": "GLUTEOS",
        "musculoDetalhe": "abdutores",
        "secundarios": ["gluteos"],
        "equipamento": ["peso_corporal"],
        "tipo": "isolation",
        "quadros": 2,
        "nomePT": "Abdução de Quadril Deitado",
        "descricaoPT": "Elevação lateral da perna deitado de lado, que trabalha o glúteo médio sem equipamento.",
        "steps": [
            "Deite de lado com as pernas estendidas e apoie a cabeça no braço de baixo.",
            "Mantenha o quadril alinhado, sem rolar para trás.",
            "Eleve a perna de cima, com o joelho estendido e a ponta do pé para a frente.",
            "Desça devagar e, ao terminar a série, troque de lado."
        ],
        "vetorForca": "vertical",
        "planoMovimento": "frontal",
        "ativacaoMuscular": 0.78,
        "escoreRiscoLesao": 0.05,
        "cuidados": [
            "Não gire a ponta do pé para cima",
            "Suba só até onde o quadril não sai do lugar",
            "Use caneleira para progredir a carga"
        ]
    },
    "kettlebell-goblet-squat": {
        "grupo": "QUADRICEPS",
        "musculoDetalhe": "quadriceps",
        "secundarios": ["gluteos", "core"],
        "equipamento": ["kettlebell"],
        "tipo": "compound",
        "quadros": 2,
        "nomePT": "Agachamento Goblet",
        "descricaoPT": "Agachamento segurando o kettlebell junto ao peito, que ajuda a manter o tronco ereto; bom para aprender o movimento.",
        "steps": [
            "Segure o kettlebell pelas alças, junto ao peito, com os cotovelos apontados para baixo.",
            "Fique com os pés um pouco mais afastados que os ombros e as pontas levemente para fora.",
            "Agache levando o quadril para trás e para baixo, com o tronco ereto e os cotovelos entre os joelhos.",
            "Suba empurrando o chão até estender as pernas."
        ],
        "vetorForca": "vertical",
        "planoMovimento": "sagital",
        "ativacaoMuscular": 0.86,
        "escoreRiscoLesao": 0.15,
        "cuidados": [
            "Mantenha o kettlebell encostado no peito",
            "Joelhos na direção das pontas dos pés",
            "Desça até onde mantém a lombar neutra"
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
    "adductors": "adutores",
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

    A extensão vira .webp: os assets do app foram convertidos para esse
    formato (ver converter_imagens_webp.py). O app monta o caminho a partir
    do slug e usa `frames` só para contar os quadros, mas manter a extensão
    certa evita que alguém use `frames[i]` e caia num arquivo inexistente.
    """
    img = ex.get("img") or []
    if len(img) < 2:
        slug = ex.get("name", "")
        img = [f"_images/web/{slug}-1.png", f"_images/web/{slug}-2.png"]
    return [re.sub(r"\.png$", ".webp", caminho) for caminho in img]


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
        # Sobra de título de seção ("<h3>Steps</h3>", "Tip"), não é um passo
        if s and s.lower() not in TITULOS_SOLTOS:
            limpos.append(s)
    return limpos


TITULOS_SOLTOS = {"steps", "tip", "tips", "passos", "dica", "dicas"}


def carregar_steps_pt():
    """Traduções dos steps, por slug. Ausentes, os steps ficam em inglês."""
    try:
        with open(STEPS_PT, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"⚠️  {STEPS_PT} não encontrado — os steps sairão em inglês.")
        return {}


def processar_exercicio(ex, extras, steps_pt):
    primary = (extras.get("primary") or ex.get("primary") or "").strip().lower()
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
        # `in` em vez de `or`: uma lista vazia na curadoria é intencional
        "musculoSecundario": extras["secundarios"] if "secundarios" in extras
                             else traduzir_lista(ex.get("secondary") or [], MUSCULO_PT),
        "tipo": extras.get("tipo") or ex.get("type") or "",
        "equipamento": extras["equipamento"] if "equipamento" in extras
                       else traduzir_lista(ex.get("equipment") or [], EQUIPAMENTO_PT),
        "frames": montar_frames(ex),
        "steps": steps,
        "cuidados": extras.get("cuidados", []),
        "vetorForca": extras["vetorForca"],
        "planoMovimento": extras["planoMovimento"],
        "ativacaoMuscular": extras["ativacaoMuscular"],
        "escoreRiscoLesao": extras["escoreRiscoLesao"],
        **campo_registro(extras),
        "fonte": "everkinetic",
        "versao": VERSAO
    }


def campo_registro(extras):
    """`registro` só vai para o documento quando não é o padrão (força)."""
    return {"registro": extras["registro"]} if extras.get("registro") else {}


def montar_sem_registro(slug, d):
    """Exercício de EXERCICIOS_SEM_REGISTRO: tudo vem da curadoria."""
    return {
        "id": slug,
        "slug": slug,
        "nome": d["nomePT"],
        "descricao": d["descricaoPT"],
        "musculoPrimario": d["grupo"],
        "musculoDetalhe": d["musculoDetalhe"],
        "musculoSecundario": d["secundarios"],
        "tipo": d["tipo"],
        "equipamento": d["equipamento"],
        "frames": [f"_images/web/{slug}-{n}.webp" for n in range(1, d["quadros"] + 1)],
        "steps": d["steps"],
        "cuidados": d["cuidados"],
        "vetorForca": d["vetorForca"],
        "planoMovimento": d["planoMovimento"],
        "ativacaoMuscular": d["ativacaoMuscular"],
        "escoreRiscoLesao": d["escoreRiscoLesao"],
        **campo_registro(d),
        # Ilustração do Everkinetic; texto e campos da curadoria deste projeto
        "fonte": "everkinetic-ilustracao",
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

    for slug, dados in EXERCICIOS_SEM_REGISTRO.items():
        if slug in por_slug or slug in EXERCICIOS_SELECIONADOS:
            print(f"❌ {slug} existe no dataset; mova-o para EXERCICIOS_SELECIONADOS")
            sys.exit(1)
        processados.append(montar_sem_registro(slug, dados))

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
