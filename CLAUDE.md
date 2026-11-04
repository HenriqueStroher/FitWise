# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão geral

FitWise (também chamado de AppGym nos scripts) é o protótipo de um TCC em Análise e Desenvolvimento de Sistemas: um app Flutter educativo de treino que sugere trocas de exercício por similaridade biomecânica quando um equipamento está ocupado. Usa Firebase (projeto `appgym-7f699`) para Firestore, Auth e Hosting. Publicado em https://appgym-7f699.web.app/.

O código, os comentários e os identificadores são em português. Mantenha esse padrão.

## Regra: registrar toda mudança

**Toda mudança no projeto, seja de rumo ou uma pequena alteração, deve ser sinalizada e brevemente explicada na seção [Registro de mudanças](#registro-de-mudanças), no mesmo trabalho em que for feita.** Cada entrada diz o que mudou e por quê. Se a mudança deixar alguma outra seção deste arquivo desatualizada, atualize essa seção também.

## Comandos

Os comandos Flutter rodam dentro de `app/`:

```bash
flutter pub get
flutter run                          # ou: flutter run -d chrome
flutter analyze
flutter test                         # toda a suíte
flutter test test/treino_test.dart   # um arquivo
flutter test test/treino_dia_test.dart --plain-name "nome do teste"   # um teste
flutter build web
```

`test/widget_test.dart` ainda é o teste de contador do template do Flutter e falha sempre. Essa falha não indica regressão.

O deploy roda na raiz do repositório. O Hosting publica `app/build/web`, então é preciso rodar `flutter build web` antes:

```bash
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

O deploy altera `.firebase/hosting.*.cache`, que é versionado.

## Arquitetura

Em `app/lib/`, as telas (`screens/`) instanciam os serviços (`services/`) diretamente e guardam o estado com `setState`. Não há biblioteca de estado nem de rotas. `main.dart` mantém as três abas em um `IndexedStack` e, a partir de 720 px de largura, troca a barra inferior por abas no topo.

### Catálogo com duas fontes

`ExercicioService` junta duas origens para que as telas não precisem distingui-las:
- **Musculação:** coleção `exercicios` do Firestore, somente leitura para o app (o id do documento é o slug).
- **Corrida e Alongamentos:** `app/assets/data/catalogo_local.json`, editado à mão. Esses grupos têm `local: true` em `GrupoMuscular.todos`.

`musculoPrimario` guarda o **grupo** (`PEITO`, `COSTAS`...), não o músculo. Esses códigos precisam coincidir entre `GrupoMuscular.todos` e `GRUPO_POR_PRIMARY`/`ORDEM_GRUPOS` em `gerar_base_appgym.py`. Os códigos de equipamento e músculo são convertidos em texto por `Rotulos`.

As imagens são localizadas por convenção de nome, `assets/images/<slug>-<n>.webp`, com `n` começando em 1. O campo `frames` só define quantos quadros existem. Um exercício novo precisa desses arquivos, e `catalogo_local_test.dart` confere isso para o catálogo local.

### Recomendação (o diferencial do TCC)

`RecomendacaoService` é Dart puro: filtragem baseada em conteúdo, sem modelo treinado. Só considera exercícios do mesmo grupo e soma os pesos abaixo, com limiar de 0,60:

| Critério | Peso |
|---|---|
| Mesmo músculo primário (sempre verdadeiro após o filtro) | 0,40 |
| Mesmo vetor de força | 0,25 |
| Mesmo plano de movimento | 0,20 |
| **Sem** equipamento em comum | 0,15 |

O equipamento pontua quando é diferente, porque a ideia é oferecer uma alternativa ao aparelho ocupado. Só o equipamento diferente não basta (0,55): o candidato precisa coincidir em vetor de força ou plano de movimento.

### Autenticação e dados do usuário

Só a aba "Meus Treinos" exige login; o catálogo é público. `MeusTreinosScreen` decide entre login, verificação de e-mail e painel da semana.

A exigência de e-mail confirmado também vale em `firestore.rules`: o documento `usuarios/{uid}` pode ser gravado antes da confirmação (o cadastro depende disso), mas as subcoleções não. Depois da confirmação é preciso renovar o token (`AuthService.confirmouEmail`) para que as regras enxerguem `email_verified`.

Mudanças no modelo de dados do usuário podem exigir ajuste nas regras, que são publicadas separadamente do app.

### Modelo de treino

`TreinoService` guarda duas estruturas separadas em `usuarios/{uid}`:
- `plano/{1..7}`: os exercícios de cada dia da semana (1 = segunda, como em `DateTime.weekday`).
- `semanas/{AAAA-MM-DD}`: o que foi feito, com a segunda-feira como id. Só a semana atual é gravada, com merge por dia, então as semanas passadas não mudam.

Para comparar um exercício entre semanas, use `ExercicioTreino.chave` (slug ou nome normalizado), não o `id`, que muda se o exercício for removido e adicionado de novo.

`Exercicio.registro` define o `TipoRegistro` e quais campos de `SerieRegistro` são usados: `forca` (reps e carga), `distancia` e `intervalado` (km e tempo), `tempo` (segundos). Só o catálogo local define um valor diferente de `forca`.

### Interface

Cores e estilos de texto vêm de `theme/app_theme.dart` (`AppCores`, `AppTexto`), sem valores soltos nas telas. Os componentes compartilhados estão em `widgets/comuns.dart` e `widgets/treino_comuns.dart`.

### Testes e Firebase

Os testes não inicializam o Firebase, e os serviços acessam `FirebaseFirestore.instance` ao serem criados. Por isso, testes de tela só funcionam quando o serviço é injetado: `TreinoDiaScreen` recebe `service` no construtor e `treino_dia_test.dart` usa um `_ServicoFalso`. Telas que criam o próprio serviço, como `ListaExerciciosScreen`, não podem ser montadas em teste sem refatoração.

## Pipeline de dados (`data/`)

Os scripts Python são independentes do app. Os de imagem exigem Pillow.

- `scripts/gerar_base_appgym.py`: gera `appgym_exercises.json` a partir do dataset bruto do Everkinetic (`exercises.json`, que não está no repositório). Os campos da recomendação e os textos em português são curados no próprio script e em `steps_pt.json`.
- `scripts/gerar_ilustracoes_extra.py`: desenha as ilustrações de Corrida e Alongamentos em `app/assets/images`.
- `scripts/converter_imagens_webp.py <pasta> [--aplicar]`: converte PNG para WebP. Sem `--aplicar`, só relata o que faria.

Alterar `appgym_exercises.json` não muda o app: os dados precisam ser importados para o Firestore. O importador (`importar_firestore.py`) não está no repositório; a pasta `firebase-import/`, que está no `.gitignore`, é provavelmente onde ele fica.

`planning/` contém os diagramas UML e o fluxograma da recomendação, em PDF.

## Registro de mudanças

Entradas da mais recente para a mais antiga, no formato `AAAA-MM-DD [rumo|alteração]: o que mudou e por quê`.

- 2026-11-03 [rumo]: adotada a regra de registrar toda mudança neste arquivo, para manter o histórico de decisões do projeto em um só lugar.
- 2026-11-03 [alteração]: criado este `CLAUDE.md`, para orientar as próximas sessões do Claude Code.
