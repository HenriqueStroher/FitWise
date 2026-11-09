"""
testar_regras_academia.py — FitWise TCC UNISINOS

Confere as regras do Firestore (firestore.rules) do modo academia: entra no
emulador com cada conta de teste e tenta ler e gravar o que deve e o que não
deve. Cada caso diz se a operação precisa ser permitida ou negada.

Uso (na raiz do repositório):
    firebase emulators:exec --only auth,firestore \
        "python data/scripts/popular_emulador_academia.py && python data/scripts/testar_regras_academia.py"

Ou, com os emuladores já rodando, só os dois scripts em sequência. O teste
grava e desfaz algumas coisas; rode o script de popular de novo antes de
repetir, para começar do mesmo estado.
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
DOCS = f"http://{FIRESTORE}/v1/projects/{PROJETO}/databases/(default)/documents"
SENHA = "teste123"
ACADEMIA = "academia-teste"

_tokens = {}


def token(conta):
    if conta not in _tokens:
        url = f"http://{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulador"
        corpo = json.dumps({"email": f"{conta}@fitwise.teste", "password": SENHA, "returnSecureToken": True})
        req = urllib.request.Request(url, data=corpo.encode(), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as r:
            _tokens[conta] = json.loads(r.read())["idToken"]
    return _tokens[conta]


def valor(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, dt.datetime):
        return {"timestampValue": v.strftime("%Y-%m-%dT%H:%M:%SZ")}
    if isinstance(v, list):
        return {"arrayValue": {"values": [valor(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: valor(x) for k, x in v.items()}}}
    raise TypeError(v)


def chamar(conta, metodo, url, corpo=None):
    """Devolve True se o Firestore permitiu, False se negou por permissão."""
    dados = None if corpo is None else json.dumps(corpo).encode()
    req = urllib.request.Request(url, data=dados, method=metodo, headers={
        "Content-Type": "application/json", "Authorization": f"Bearer {token(conta)}",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            resposta = json.loads(r.read() or b"{}")
        # runQuery responde 200 mesmo com erro dentro da lista
        if isinstance(resposta, list) and any("error" in x for x in resposta):
            return False
        return True
    except urllib.error.HTTPError as e:
        if e.code == 403:
            return False
        raise RuntimeError(f"{metodo} {url}: {e.code} {e.read().decode()[:300]}")


def ler(conta, caminho):
    return chamar(conta, "GET", f"{DOCS}/{caminho}")


def gravar(conta, caminho, campos, mascara=None):
    """Sem máscara substitui o documento; com máscara, só os campos dela
    (um campo da máscara que não está em `campos` é apagado)."""
    url = f"{DOCS}/{caminho}"
    if mascara:
        url += "?" + "&".join(f"updateMask.fieldPaths={c}" for c in mascara)
    return chamar(conta, "PATCH", url, {"fields": {k: valor(v) for k, v in campos.items()}})


def apagar(conta, caminho):
    return chamar(conta, "DELETE", f"{DOCS}/{caminho}")


def filtro(campo, v):
    return {"fieldFilter": {"field": {"fieldPath": campo}, "op": "EQUAL", "value": valor(v)}}


def consulta(colecao, *filtros):
    q = {"from": [{"collectionId": colecao}]}
    if len(filtros) == 1:
        q["where"] = filtros[0]
    elif filtros:
        q["where"] = {"compositeFilter": {"op": "AND", "filters": list(filtros)}}
    return q


def listar(conta, colecao, *filtros):
    return chamar(conta, "POST", f"{DOCS}:runQuery", {"structuredQuery": consulta(colecao, *filtros)})


def contar(conta, colecao, *filtros):
    return chamar(conta, "POST", f"{DOCS}:runAggregationQuery", {"structuredAggregationQuery": {
        "structuredQuery": consulta(colecao, *filtros), "aggregations": [{"alias": "n", "count": {}}],
    }})


def criar_academia(conta, academia_id, dono_uid):
    """Lote igual ao do app (AcademiaService.criarAcademia)."""
    nome = f"projects/{PROJETO}/databases/(default)/documents"
    return chamar(conta, "POST", f"{DOCS}:commit", {"writes": [
        {"update": {"name": f"{nome}/academias/{academia_id}",
                    "fields": {k: valor(v) for k, v in {"nome": "Nova", "donoUid": dono_uid}.items()}},
         "currentDocument": {"exists": False}},
        {"update": {"name": f"{nome}/usuarios/{dono_uid}",
                    "fields": {k: valor(v) for k, v in {"papel": "dono", "academiaId": academia_id}.items()}},
         "updateMask": {"fieldPaths": ["papel", "academiaId"]}},
    ]})


PLANO_TESTE = {"exercicios": [{"id": "x", "nome": "Teste", "slug": None}]}
SEMANA_TESTE = {"inicio": dt.datetime(1999, 1, 4), "dias": {}}
VALIDADE = dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7)

CASOS = [
    # ── Usuário comum: igual a antes ──
    ("usuário comum lê o próprio plano", True, lambda: ler("usuario", "usuarios/teste-usuario/plano/2")),
    ("usuário comum grava o próprio plano", True,
     lambda: gravar("usuario", "usuarios/teste-usuario/plano/7", PLANO_TESTE)),
    ("usuário comum apaga o dia de teste", True, lambda: apagar("usuario", "usuarios/teste-usuario/plano/7")),
    ("usuário comum grava a própria semana", True,
     lambda: gravar("usuario", "usuarios/teste-usuario/semanas/1999-01-04", SEMANA_TESTE)),
    ("usuário comum lê o perfil de um aluno", False, lambda: ler("usuario", "usuarios/teste-aluno")),
    ("usuário comum lê o plano de um aluno", False, lambda: ler("usuario", "usuarios/teste-aluno/plano/1")),
    ("usuário comum lista todos os usuários", False, lambda: listar("usuario", "usuarios")),
    ("usuário comum se torna dono sozinho", False,
     lambda: gravar("usuario", "usuarios/teste-usuario", {"papel": "dono", "academiaId": ACADEMIA},
                    ["papel", "academiaId"])),
    ("usuário comum lê uma academia", False, lambda: ler("usuario", f"academias/{ACADEMIA}")),
    ("usuário comum cria convite", False,
     lambda: gravar("usuario", "convites/FALSO001", {"tipo": "aluno", "academiaId": ACADEMIA,
                                                    "autorUid": "teste-usuario", "expiraEm": VALIDADE})),
    ("usuário comum lê um convite pelo código", True, lambda: ler("usuario", "convites/RAFA2026")),
    ("cadastro novo já com papel", False,
     lambda: gravar("usuario", "usuarios/teste-usuario-novo", {"nome": "X", "papel": "dono"})),

    # ── Aluno ──
    ("aluno lê o próprio plano", True, lambda: ler("aluno", "usuarios/teste-aluno/plano/1")),
    ("aluno grava o próprio plano", False, lambda: gravar("aluno", "usuarios/teste-aluno/plano/7", PLANO_TESTE)),
    ("aluno grava a própria semana", True,
     lambda: gravar("aluno", "usuarios/teste-aluno/semanas/1999-01-04", SEMANA_TESTE)),
    ("aluno apaga a semana de teste", True, lambda: apagar("aluno", "usuarios/teste-aluno/semanas/1999-01-04")),
    ("aluno lê a academia dele", True, lambda: ler("aluno", f"academias/{ACADEMIA}")),
    ("aluno lê o perfil do professor", True, lambda: ler("aluno", "usuarios/teste-professor")),
    ("aluno lê o perfil de outro aluno", False, lambda: ler("aluno", "usuarios/teste-aluno3")),
    ("aluno troca de professor sem convite", False,
     lambda: gravar("aluno", "usuarios/teste-aluno", {"professorUid": "teste-dono"}, ["professorUid"])),
    ("aluno vira professor sozinho", False,
     lambda: gravar("aluno", "usuarios/teste-aluno", {"papel": "professor"}, ["papel"])),
    ("aluno muda o próprio nome", True,
     lambda: gravar("aluno", "usuarios/teste-aluno", {"nome": "Bruna Lima"}, ["nome"])),
    ("aluno oculta exercícios da academia", False,
     lambda: gravar("aluno", f"academias/{ACADEMIA}", {"exerciciosOcultos": []}, ["exerciciosOcultos"])),

    # ── Professor ──
    ("professor lê o plano do aluno dele", True, lambda: ler("professor", "usuarios/teste-aluno/plano/1")),
    ("professor grava o plano do aluno dele", True,
     lambda: gravar("professor", "usuarios/teste-aluno/plano/7", PLANO_TESTE)),
    ("professor apaga o dia de teste do aluno", True, lambda: apagar("professor", "usuarios/teste-aluno/plano/7")),
    ("professor lê as semanas do aluno dele", True,
     lambda: chamar("professor", "POST", f"{DOCS}/usuarios/teste-aluno:runQuery",
                    {"structuredQuery": {"from": [{"collectionId": "semanas"}]}})),
    ("professor grava a semana do aluno", False,
     lambda: gravar("professor", "usuarios/teste-aluno/semanas/1999-01-04", SEMANA_TESTE)),
    ("professor lê o plano do aluno da Carla", False, lambda: ler("professor", "usuarios/teste-aluno2/plano/1")),
    ("professor lê o plano de um usuário comum", False, lambda: ler("professor", "usuarios/teste-usuario/plano/2")),
    ("professor lista os próprios alunos", True,
     lambda: listar("professor", "usuarios", filtro("academiaId", ACADEMIA), filtro("professorUid", "teste-professor"))),
    ("professor lista todos os usuários da academia", False,
     lambda: listar("professor", "usuarios", filtro("academiaId", ACADEMIA))),
    ("professor cria convite de aluno", True,
     lambda: gravar("professor", "convites/TESTEPR1", {"tipo": "aluno", "academiaId": ACADEMIA,
                                                      "autorUid": "teste-professor", "expiraEm": VALIDADE})),
    ("professor lista os próprios convites", True,
     lambda: listar("professor", "convites", filtro("autorUid", "teste-professor"))),
    ("professor apaga o convite dele", True, lambda: apagar("professor", "convites/TESTEPR1")),
    ("professor cria convite de professor", False,
     lambda: gravar("professor", "convites/TESTEPR2", {"tipo": "professor", "academiaId": ACADEMIA,
                                                      "autorUid": "teste-professor", "expiraEm": VALIDADE})),
    ("professor oculta exercícios", False,
     lambda: gravar("professor", f"academias/{ACADEMIA}", {"exerciciosOcultos": []}, ["exerciciosOcultos"])),

    # ── Dono da academia ──
    ("dono lista os professores da academia", True,
     lambda: listar("dono", "usuarios", filtro("academiaId", ACADEMIA), filtro("papel", "professor"))),
    ("dono conta os alunos de um professor", True,
     lambda: contar("dono", "usuarios", filtro("academiaId", ACADEMIA), filtro("professorUid", "teste-professor"))),
    ("dono lista usuários de outra academia", False,
     lambda: listar("dono", "usuarios", filtro("academiaId", "academia-teste-2"))),
    ("dono oculta exercícios da academia dele", True,
     lambda: gravar("dono", f"academias/{ACADEMIA}",
                    {"exerciciosOcultos": ["hack-squat-machine", "narrow-stance-leg-press",
                                           "standing-leg-curls", "tricep-dips"]}, ["exerciciosOcultos"])),
    ("dono troca o dono da academia", False,
     lambda: gravar("dono", f"academias/{ACADEMIA}", {"donoUid": "teste-professor"}, ["donoUid"])),
    ("dono edita a outra academia", False,
     lambda: gravar("dono", "academias/academia-teste-2", {"exerciciosOcultos": []}, ["exerciciosOcultos"])),
    ("dono lê o treino do aluno dele", True, lambda: ler("dono", "usuarios/teste-aluno2/plano/1")),
    ("dono lê o treino do aluno do Rafael", False, lambda: ler("dono", "usuarios/teste-aluno/plano/1")),
    ("dono cria convite de professor", True,
     lambda: gravar("dono", "convites/TESTEDN1", {"tipo": "professor", "academiaId": ACADEMIA,
                                                 "autorUid": "teste-dono", "expiraEm": VALIDADE})),
    ("dono apaga o convite dele", True, lambda: apagar("dono", "convites/TESTEDN1")),
    ("dono sai da própria academia", False,
     lambda: gravar("dono", "usuarios/teste-dono", {}, ["papel", "academiaId"])),

    # ── Dono do software ──
    ("admin conta os alunos de todas as academias", True,
     lambda: contar("admin", "usuarios", filtro("papel", "aluno"))),
    ("admin lista as academias", True, lambda: listar("admin", "academias")),
    ("admin lê o treino de um aluno", False, lambda: ler("admin", "usuarios/teste-aluno/plano/1")),
    ("admin lê as semanas de um aluno", False, lambda: ler("admin", "usuarios/teste-aluno/semanas/1999-01-04")),
    ("não admin conta usuários", False, lambda: contar("dono", "usuarios", filtro("papel", "aluno"))),

    # ── Convite e saída (alteram o estado; ficam por último) ──
    ("usuário comum entra com convite de outra academia", False,
     lambda: gravar("usuario", "usuarios/teste-usuario",
                    {"papel": "aluno", "academiaId": "academia-teste-2", "professorUid": "teste-professor",
                     "convite": "RAFA2026"}, ["papel", "academiaId", "professorUid", "convite"])),
    ("usuário comum entra como aluno de outro professor", False,
     lambda: gravar("usuario", "usuarios/teste-usuario",
                    {"papel": "aluno", "academiaId": ACADEMIA, "professorUid": "teste-dono", "convite": "RAFA2026"},
                    ["papel", "academiaId", "professorUid", "convite"])),
    ("usuário comum entra pelo convite RAFA2026", True,
     lambda: gravar("usuario", "usuarios/teste-usuario",
                    {"papel": "aluno", "academiaId": ACADEMIA, "professorUid": "teste-professor",
                     "convite": "RAFA2026"}, ["papel", "academiaId", "professorUid", "convite"])),
    ("novo aluno não grava mais o próprio plano", False,
     lambda: gravar("usuario", "usuarios/teste-usuario/plano/7", PLANO_TESTE)),
    ("professor desvincula o novo aluno", True,
     lambda: gravar("professor", "usuarios/teste-usuario", {}, ["papel", "academiaId", "professorUid", "convite"])),
    ("ex-aluno volta a gravar o próprio plano", True,
     lambda: gravar("usuario", "usuarios/teste-usuario/plano/7", PLANO_TESTE)),
    ("ex-aluno apaga o dia de teste", True, lambda: apagar("usuario", "usuarios/teste-usuario/plano/7")),
    ("usuário comum vira professor pelo PROF2026", True,
     lambda: gravar("usuario", "usuarios/teste-usuario",
                    {"papel": "professor", "academiaId": ACADEMIA, "convite": "PROF2026"},
                    ["papel", "academiaId", "convite"])),
    ("dono remove o novo professor", True,
     lambda: gravar("dono", "usuarios/teste-usuario", {}, ["papel", "academiaId", "professorUid", "convite"])),
    ("dono passa a aluna do Rafael para si", True,
     lambda: gravar("dono", "usuarios/teste-aluno3", {"professorUid": "teste-dono"}, ["professorUid"])),
    ("dono passa a aluna para outro professor", False,
     lambda: gravar("dono", "usuarios/teste-aluno3", {"professorUid": "teste-professor"}, ["professorUid"])),
    ("Rafael perdeu o acesso à aluna que foi para a Carla", False,
     lambda: ler("professor", "usuarios/teste-aluno3/plano/1")),
    ("dono cria uma academia nova para alguém", False,
     lambda: criar_academia("dono", "academia-teste-3", "teste-usuario")),
    ("admin cria uma academia com o Lucas de dono", True,
     lambda: criar_academia("admin", "academia-teste-3", "teste-usuario")),
    ("Lucas, agora dono, oculta exercícios da academia nova", True,
     lambda: gravar("usuario", "academias/academia-teste-3", {"exerciciosOcultos": []}, ["exerciciosOcultos"])),
    ("professora autônoma lê o plano do aluno dela", True,
     lambda: ler("personal", "usuarios/teste-aluno4/plano/2")),
    ("professora autônoma cria convite de aluno", True,
     lambda: gravar("personal", "convites/TESTEPS1", {"tipo": "aluno", "academiaId": "academia-teste-personal",
                                                     "autorUid": "teste-personal", "expiraEm": VALIDADE})),
    ("professora autônoma lê o plano de aluno da Ponto Fit", False,
     lambda: ler("personal", "usuarios/teste-aluno/plano/1")),
    ("admin coloca o Lucas como aluno da Júlia", True,
     lambda: gravar("admin", "usuarios/teste-usuario",
                    {"papel": "aluno", "academiaId": "academia-teste-personal", "professorUid": "teste-personal"},
                    ["papel", "academiaId", "professorUid"])),
    ("Júlia passa a ler o plano do Lucas", True, lambda: ler("personal", "usuarios/teste-usuario/plano/2")),
    ("admin vê as entradas recentes", True,
     lambda: chamar("admin", "POST", f"{DOCS}:runQuery", {"structuredQuery": {
         "from": [{"collectionId": "usuarios"}],
         "orderBy": [{"field": {"fieldPath": "criadoEm"}, "direction": "DESCENDING"}], "limit": 15}})),
    ("dono vê as entradas recentes do app todo", False,
     lambda: chamar("dono", "POST", f"{DOCS}:runQuery", {"structuredQuery": {
         "from": [{"collectionId": "usuarios"}],
         "orderBy": [{"field": {"fieldPath": "criadoEm"}, "direction": "DESCENDING"}], "limit": 15}})),
    ("aluna sai da academia sozinha", True,
     lambda: gravar("aluno3", "usuarios/teste-aluno3", {}, ["papel", "academiaId", "professorUid", "convite"])),
]


def main():
    falhas = 0
    for nome, esperado, acao in CASOS:
        obtido = acao()
        ok = obtido == esperado
        falhas += not ok
        marca = "✅" if ok else "❌"
        print(f"{marca} {nome}: {'permitido' if obtido else 'negado'}"
              + ("" if ok else f" (esperado: {'permitido' if esperado else 'negado'})"))
    print(f"\n{len(CASOS) - falhas}/{len(CASOS)} casos como esperado")
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
