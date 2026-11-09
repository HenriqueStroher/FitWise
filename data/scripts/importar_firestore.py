"""
importar_firestore.py — FitWise TCC UNISINOS

Publica a base gerada (appgym_exercises.json) na coleção `exercicios` do
Firestore, um documento por exercício, com o slug como id. É o passo que
faltava entre gerar_base_appgym.py e o app: o app lê o catálogo de
musculação do Firestore, não deste arquivo.

As regras do Firestore proíbem escrita em `exercicios` pelo app; este script
usa o Admin SDK, que não passa pelas regras. Por isso precisa de uma chave de
conta de serviço do projeto:
    Console do Firebase > Configurações do projeto > Contas de serviço >
    Gerar nova chave privada.
A chave dá acesso total ao projeto: não a coloque no repositório.

Uso:
    pip install firebase-admin
    python importar_firestore.py <chave.json> [appgym_exercises.json] [--aplicar]
    python importar_firestore.py --emulador [appgym_exercises.json] [--aplicar]

Sem --aplicar, só compara a base com o Firestore e relata o que mudaria.
Com --emulador, grava no emulador local (firebase emulators:start --only
firestore, porta 8080) e não precisa de chave: serve para testar a base no
app (flutter run --dart-define=EMULADOR=true) antes de publicá-la.
Documentos que estão no Firestore mas não na base são listados, nunca
apagados: o histórico de treino dos usuários pode apontar para eles.
"""

import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJETO = "appgym-7f699"
COLECAO = "exercicios"
BASE_PADRAO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "appgym_exercises.json")
LOTE = 400  # o Firestore aceita até 500 escritas por batch
EMULADOR = "localhost:8080"  # mesma porta de firebase.json


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    emulador = "--emulador" in sys.argv
    aplicar = "--aplicar" in sys.argv
    if not args and not emulador:
        print(__doc__)
        sys.exit(1)

    if emulador:
        # O cliente do Firestore detecta a variável e fala com o emulador,
        # com permissão de administrador e sem credencial
        os.environ["FIRESTORE_EMULATOR_HOST"] = EMULADOR
        from google.auth.credentials import AnonymousCredentials
        from google.cloud import firestore as gfirestore
        db = gfirestore.Client(project=PROJETO, credentials=AnonymousCredentials())
        caminho_base = args[0] if args else BASE_PADRAO
    else:
        import firebase_admin
        from firebase_admin import credentials, firestore
        firebase_admin.initialize_app(credentials.Certificate(args[0]), {"projectId": PROJETO})
        db = firestore.client()
        caminho_base = args[1] if len(args) > 1 else BASE_PADRAO

    with open(caminho_base, encoding="utf-8") as f:
        exercicios = json.load(f)["exercicios"]

    atuais = {doc.id: doc.to_dict() for doc in db.collection(COLECAO).stream()}
    novos = [e for e in exercicios if e["slug"] not in atuais]
    alterados = [e for e in exercicios if e["slug"] in atuais and atuais[e["slug"]] != e]
    fora_da_base = sorted(set(atuais) - {e["slug"] for e in exercicios})

    destino = f"EMULADOR {EMULADOR}" if emulador else f"Projeto {PROJETO}"
    print(f"{destino}, coleção '{COLECAO}': {len(atuais)} documento(s) hoje")
    print(f"Base {os.path.basename(caminho_base)}: {len(exercicios)} exercício(s)")
    print(f"   novos:     {len(novos)}")
    for e in novos:
        print(f"      + {e['slug']}  ({e['nome']})")
    print(f"   alterados: {len(alterados)}")
    for e in alterados:
        campos = sorted(k for k in set(e) | set(atuais[e["slug"]])
                        if e.get(k) != atuais[e["slug"]].get(k))
        print(f"      ~ {e['slug']}: {', '.join(campos)}")
    print(f"   iguais:    {len(exercicios) - len(novos) - len(alterados)}")
    if fora_da_base:
        print(f"\n⚠️  No Firestore mas não na base (não serão apagados): {', '.join(fora_da_base)}")

    gravar = novos + alterados
    if not aplicar:
        print("\nℹ️  Simulação — nada foi gravado. Para aplicar: adicione --aplicar")
        return
    for i in range(0, len(gravar), LOTE):
        batch = db.batch()
        for e in gravar[i:i + LOTE]:
            batch.set(db.collection(COLECAO).document(e["slug"]), e)
        batch.commit()
    print(f"\n✅ {len(gravar)} documento(s) gravado(s)")


if __name__ == "__main__":
    main()
