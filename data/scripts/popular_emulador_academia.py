"""
popular_emulador_academia.py — FitWise TCC UNISINOS

Cria no EMULADOR os usuários fictícios do modo academia (em teste), para ver
o app com cada papel sem tocar em produção. Nunca fala com o projeto real:
só com o emulador de login (porta 9099) e o do Firestore (porta 8080).

Uso (na raiz do repositório, com os emuladores rodando):
    firebase emulators:start --only auth,firestore
    python data/scripts/popular_emulador_academia.py
    cd app && flutter run -d chrome --dart-define=EMULADOR=true

Pode rodar de novo quando quiser: refaz só os dados das contas de teste
(uids começando com "teste-") e não mexe no resto. Se o catálogo de
exercícios ainda não estiver no emulador, carrega appgym_exercises.json.

Contas criadas (senha de todas: teste123):
    admin@fitwise.teste      dono do software (painel com os números)
    dono@fitwise.teste       Carla, dona e professora da Academia Ponto Fit
    professor@fitwise.teste  Rafael, professor da Ponto Fit
    aluno@fitwise.teste      Bruna, aluna do Rafael, com 4 semanas de histórico
    aluno2@fitwise.teste     Diego, aluno da Carla
    aluno3@fitwise.teste     Marina, aluna nova do Rafael (sem histórico)
    dono2@fitwise.teste      Paulo, dono de uma segunda academia, ainda vazia
    personal@fitwise.teste   Júlia, professora autônoma (sem academia)
    aluno4@fitwise.teste     Felipe, aluno da Júlia
    usuario@fitwise.teste    Lucas, usuário comum, sem academia

Convites fixos para testar o link (?convite=...):
    RAFA2026  vira aluno do Rafael
    PROF2026  vira professor da Ponto Fit
"""

import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJETO = "appgym-7f699"
# As variáveis permitem usar emuladores em outras portas
AUTH = os.environ.get("EMULADOR_AUTH", "localhost:9099")
FIRESTORE = os.environ.get("EMULADOR_FIRESTORE", "localhost:8080")
SENHA = "teste123"
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
BASE = os.path.join(RAIZ, "data", "appgym_exercises.json")
LOCAL = os.path.join(RAIZ, "app", "assets", "data", "catalogo_local.json")

ACADEMIA = "academia-teste"
ACADEMIA_2 = "academia-teste-2"
PERSONAL = "academia-teste-personal"

# uid, e-mail, nome, papel, academia, professor
USUARIOS = [
    ("teste-admin", "admin@fitwise.teste", "Dono do Software", None, None, None),
    ("teste-dono", "dono@fitwise.teste", "Carla Mendes", "dono", ACADEMIA, None),
    ("teste-professor", "professor@fitwise.teste", "Rafael Souza", "professor", ACADEMIA, None),
    ("teste-aluno", "aluno@fitwise.teste", "Bruna Lima", "aluno", ACADEMIA, "teste-professor"),
    ("teste-aluno2", "aluno2@fitwise.teste", "Diego Alves", "aluno", ACADEMIA, "teste-dono"),
    ("teste-aluno3", "aluno3@fitwise.teste", "Marina Costa", "aluno", ACADEMIA, "teste-professor"),
    ("teste-dono2", "dono2@fitwise.teste", "Paulo Rocha", "dono", ACADEMIA_2, None),
    ("teste-personal", "personal@fitwise.teste", "Júlia Ramos", "dono", PERSONAL, None),
    ("teste-aluno4", "aluno4@fitwise.teste", "Felipe Nunes", "aluno", PERSONAL, "teste-personal"),
    ("teste-usuario", "usuario@fitwise.teste", "Lucas Pereira", None, None, None),
]

ACADEMIAS = {
    ACADEMIA: {
        "nome": "Academia Ponto Fit",
        "tipo": "academia",
        "donoUid": "teste-dono",
        # Não tem Smith, kettlebell, bola nem roda; das máquinas, não tem hack,
        # leg press de pernas juntas, flexora em pé nem mergulho na máquina
        "equipamentosIndisponiveis": ["bola", "kettlebell", "roda_abdominal", "smith"],
        "exerciciosOcultos": ["hack-squat-machine", "narrow-stance-leg-press", "standing-leg-curls", "tricep-dips"],
    },
    ACADEMIA_2: {
        "nome": "Studio Bairro Forte",
        "tipo": "academia",
        "donoUid": "teste-dono2",
        "equipamentosIndisponiveis": [],
        "exerciciosOcultos": [],
    },
    # O professor autônomo é dono da própria "academia", do tipo autonomo
    PERSONAL: {
        "nome": "Júlia Ramos",
        "tipo": "autonomo",
        "donoUid": "teste-personal",
        "equipamentosIndisponiveis": [],
        "exerciciosOcultos": [],
    },
}

CONVITES = {
    "RAFA2026": ("aluno", ACADEMIA, "teste-professor", "Rafael Souza"),
    "PROF2026": ("professor", ACADEMIA, "teste-dono", "Carla Mendes"),
}

# Plano por dia (1 = segunda): (slug, carga inicial em kg). Carga None é
# exercício sem carga (corrida, prancha).
PLANOS = {
    "teste-aluno": {
        1: [("bench-press", 30), ("dumbbell-incline-bench-press", 12), ("butterfly-machine", 25),
            ("triceps-pushdown-with-rope-and-cable", 15), ("lying-triceps-press-with-barbell", 15)],
        2: [("wide-grip-lat-pull-down", 35), ("seated-cable-rows", 30), ("rear-deltoid-row-dumbbell", 12),
            ("biceps-curls-with-barbell", 15), ("biceps-hammer-curl-with-dumbbell", 8)],
        3: [("barbell-squat", 40), ("leg-press", 100), ("leg-extensions", 30),
            ("seated-leg-curl", 25), ("standing-calf-raises-using-machine", 40)],
        4: [("corrida", None)],
        5: [("dumbbell-shoulder-press", 10), ("lateral-dumbbell-raises", 5), ("face-pull", 15),
            ("romanian-dead-lift", 30), ("bridging", 20), ("plank", None)],
    },
    "teste-aluno2": {
        1: [("barbell-squat", 60), ("bench-press", 50), ("seated-cable-rows", 45)],
        3: [("leg-press", 160), ("dumbbell-shoulder-press", 16), ("wide-grip-lat-pull-down", 50)],
        5: [("romanian-dead-lift", 60), ("dumbbell-incline-bench-press", 20), ("biceps-curls-with-barbell", 25)],
    },
    "teste-aluno3": {
        1: [("leg-press", 60), ("leg-extensions", 20), ("seated-leg-curl", 15)],
        3: [("wide-grip-lat-pull-down", 25), ("machine-bench-press", 15), ("lateral-dumbbell-raises", 3)],
    },
    "teste-aluno4": {
        2: [("squats-using-dumbbells", 14), ("dumbbell-lunges", 8), ("corrida", None)],
        5: [("push-ups", 0), ("rear-deltoid-row-dumbbell", 14), ("plank", None)],
    },
    "teste-usuario": {
        2: [("bench-press", 40), ("seated-cable-rows", 40)],
        4: [("barbell-squat", 50), ("leg-press", 120)],
    },
}

# Semanas de histórico antes da atual
HISTORICO = {"teste-aluno": 4, "teste-aluno2": 2, "teste-aluno4": 2, "teste-usuario": 1}


def requisicao(metodo, url, corpo=None):
    dados = None if corpo is None else json.dumps(corpo).encode()
    req = urllib.request.Request(url, data=dados, method=metodo, headers={
        "Content-Type": "application/json",
        # No emulador, este token dá permissão de administrador
        "Authorization": "Bearer owner",
    })
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or b"{}")


def recriar_conta(uid, email, nome):
    base = f"http://{AUTH}/identitytoolkit.googleapis.com/v1/projects/{PROJETO}"
    try:
        requisicao("POST", f"{base}/accounts:delete", {"localId": uid})
    except urllib.error.HTTPError:
        pass  # ainda não existia
    requisicao("POST", f"{base}/accounts", {
        "localId": uid, "email": email, "password": SENHA, "displayName": nome, "emailVerified": True,
    })


def catalogo():
    with open(BASE, encoding="utf-8") as f:
        base = json.load(f)["exercicios"]
    with open(LOCAL, encoding="utf-8") as f:
        locais = json.load(f)["exercicios"]
    return base, {e["slug"]: e for e in base + locais}


def exercicio_treino(slug, catalogo_por_slug, dia):
    e = catalogo_por_slug[slug]
    item = {"id": f"{slug}-{dia}", "nome": e["nome"], "slug": slug}
    if e.get("registro", "forca") != "forca":
        item["registro"] = e["registro"]
    return item


def series(slug, carga, registro, semana):
    """Séries de uma semana; a carga sobe um pouco a cada semana."""
    if registro == "distancia":
        km = 4 + semana * 0.5
        return [{"distancia": km, "tempo": int(km * (390 - semana * 8))}]
    if registro == "tempo":
        return [{"tempo": 30 + semana * 10} for _ in range(3)]
    if not carga:
        return [{"reps": 15 + semana} for _ in range(3)]
    passo = 2.5 if carga < 20 else 5
    atual = carga + passo * semana
    return [{"reps": r, "carga": atual} for r in (12, 10, 10, 8)]


def apagar_colecao(colecao):
    for doc in colecao.stream():
        doc.reference.delete()


def main():
    os.environ["FIRESTORE_EMULATOR_HOST"] = FIRESTORE
    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore

    try:
        urllib.request.urlopen(f"http://{AUTH}/", timeout=3)
    except urllib.error.HTTPError:
        pass
    except OSError:
        print("❌ Emulador de login fora do ar. Rode antes: firebase emulators:start --only auth,firestore")
        sys.exit(1)

    db = firestore.Client(project=PROJETO, credentials=AnonymousCredentials())
    base, por_slug = catalogo()

    if not list(db.collection("exercicios").limit(1).stream()):
        lote = db.batch()
        for e in base:
            lote.set(db.collection("exercicios").document(e["slug"]), e)
        lote.commit()
        print(f"📚 Catálogo carregado no emulador ({len(base)} exercícios)")

    hoje = dt.date.today()
    segunda = hoje - dt.timedelta(days=hoje.weekday())

    agora = dt.datetime.now(dt.timezone.utc)
    for i, (uid, email, nome, papel, academia, professor) in enumerate(USUARIOS):
        recriar_conta(uid, email, nome)
        ref = db.collection("usuarios").document(uid)
        apagar_colecao(ref.collection("plano"))
        apagar_colecao(ref.collection("semanas"))
        # Cadastros em dias diferentes, para a lista de entradas recentes
        criado = agora - dt.timedelta(days=len(USUARIOS) - i)
        perfil = {"nome": nome, "email": email, "criadoEm": criado}
        if papel:
            perfil.update({"papel": papel, "academiaId": academia})
        if professor:
            perfil["professorUid"] = professor
        ref.set(perfil)

        plano = PLANOS.get(uid, {})
        for dia, itens in plano.items():
            ref.collection("plano").document(str(dia)).set({
                "exercicios": [exercicio_treino(s, por_slug, dia) for s, _ in itens],
                "atualizadoEm": firestore.SERVER_TIMESTAMP,
            })

        semanas = HISTORICO.get(uid, 0)
        for n in range(semanas):
            inicio = segunda - dt.timedelta(weeks=semanas - n)
            dias = {}
            for dia, itens in plano.items():
                dias[str(dia)] = []
                for slug, carga in itens:
                    item = exercicio_treino(slug, por_slug, dia)
                    item["series"] = series(slug, carga, item.get("registro", "forca"), n)
                    dias[str(dia)].append(item)
            ref.collection("semanas").document(inicio.isoformat()).set({
                "inicio": dt.datetime(inicio.year, inicio.month, inicio.day),
                "atualizadoEm": firestore.SERVER_TIMESTAMP,
                "dias": dias,
            })

    db.collection("admins").document("teste-admin").set({"nome": "Dono do Software"})

    # Academias criadas em testes anteriores (pelo app ou pelo teste das regras)
    for doc in db.collection("academias").stream():
        if doc.id.startswith("academia-teste") or doc.to_dict().get("donoUid", "").startswith("teste-"):
            doc.reference.delete()
    for id_, dados in ACADEMIAS.items():
        db.collection("academias").document(id_).set({**dados, "criadoEm": firestore.SERVER_TIMESTAMP})

    for doc in db.collection("convites").stream():
        if doc.to_dict().get("autorUid", "").startswith("teste-"):
            doc.reference.delete()
    validade = dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=365)
    for codigo, (tipo, academia, autor, autor_nome) in CONVITES.items():
        db.collection("convites").document(codigo).set({
            "tipo": tipo, "academiaId": academia, "academiaNome": ACADEMIAS[academia]["nome"],
            "autorUid": autor, "autorNome": autor_nome,
            "criadoEm": firestore.SERVER_TIMESTAMP, "expiraEm": validade,
        })

    print("✅ Contas de teste prontas no emulador (senha de todas: teste123)\n")
    for uid, email, nome, papel, _, _ in USUARIOS:
        rotulo = ("dono do software" if uid == "teste-admin"
                  else "professor autônomo" if uid == "teste-personal"
                  else papel or "usuário comum")
        print(f"   {email:<26} {nome:<18} {rotulo}")
    print("\n   Convites: ?convite=RAFA2026 (aluno do Rafael), ?convite=PROF2026 (professor)")


if __name__ == "__main__":
    main()
