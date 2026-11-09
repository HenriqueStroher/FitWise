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
flutter build web --dart-define=ACADEMIAS=true   # como a CI publica (modo academia ligado)
```

`test/widget_test.dart` ainda é o teste de contador do template do Flutter e falha sempre. Essa falha não indica regressão.

O deploy roda na raiz do repositório. O Hosting publica `app/build/web`, então é preciso rodar `flutter build web` antes:

```bash
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

O deploy altera `.firebase/hosting.*.cache`, que é versionado.

## Arquitetura

Em `app/lib/`, as telas (`screens/`) instanciam os serviços (`services/`) diretamente e guardam o estado com `setState`. Não há biblioteca de estado nem de rotas. `main.dart` mantém as três abas em um `IndexedStack` e, a partir de 720 px de largura, troca a barra inferior por abas no topo. A aba ativa fica em `Navegacao.aba` (`navegacao.dart`), e não no estado do `MainScreen`, para que o botão de início das telas empilhadas (`BotaoInicio`, em `widgets/comuns.dart`) possa fechar tudo e voltar à aba Grupos.

`DetalheExercicioScreen` recebe a `sequencia` de onde foi aberto (a lista filtrada do grupo ou as variações, via `LinhaExercicio`) e troca de exercício na mesma tela, com os botões de anterior/próximo ou as setas do teclado. Por não empilhar telas, voltar continua levando à lista.

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

Só a aba "Meus Treinos" exige login; o catálogo é público. `MeusTreinosScreen` decide entre login, verificação de e-mail e painel da semana (no modo academia, o painel depende do papel).

A exigência de e-mail confirmado também vale em `firestore.rules`: o documento `usuarios/{uid}` pode ser gravado antes da confirmação (o cadastro depende disso), mas as subcoleções não. Depois da confirmação é preciso renovar o token (`AuthService.confirmouEmail`) para que as regras enxerguem `email_verified`.

Mudanças no modelo de dados do usuário podem exigir ajuste nas regras, que são publicadas separadamente do app. As subcoleções de `usuarios/{uid}` estão listadas uma a uma nas regras (`plano`, `semanas`); uma subcoleção nova precisa de regra própria.

### Modo academia

Versão B2B: a academia contrata o app, o dono convida professores, o professor convida alunos e monta o treino deles, e o aluno registra séries e cargas. Também há o **professor autônomo** (personal sem academia), que tem os próprios alunos. O modo liga com `--dart-define=ACADEMIAS=true` (a CI publica assim) ou `--dart-define=EMULADOR=true` (`Sessao.habilitada`). Para quem não tem papel nem abre um convite, o app é o mesmo de antes. Sem a flag, o modo some para todo mundo.

O dono do software é quem tem `admins/{uid}`. Esse documento só é criado pelo console do Firebase (Firestore > coleção `admins` > documento com o UID da conta, que aparece em Authentication).

- **Papéis** (`models/academia.dart`): `usuario` (sem academia, como sempre), `aluno`, `professor` e `dono` (professor que administra a academia). Ficam em `usuarios/{uid}` nos campos `papel`, `academiaId` e `professorUid`. O professor autônomo é um `dono` de uma academia com `tipo: autonomo`: usa as mesmas regras e telas, sem a parte de professores e equipamentos. Os totais do painel separam autônomos de donos contando as academias desse tipo.
- **Quem coloca quem:** só o dono do software cria academias e autônomos, e ele também pode pôr qualquer conta já cadastrada como professor de uma academia ou aluno de um professor (`AcademiaService.criarAcademia`, `adicionarProfessor`, `adicionarAluno`). O dono da academia convida os professores dela, e cada professor convida os próprios alunos.
- **`Sessao`** (`services/sessao.dart`) ouve o perfil e a academia do usuário logado. `ExercicioService` esconde do catálogo, do seletor e das sugestões o que a academia não tem (`Academia.visivel`): os equipamentos indisponíveis e os exercícios ocultos um a um. A academia guarda o que está **oculto**, para que exercícios novos do catálogo apareçam sozinhos. O equipamento sozinho não basta porque `maquina` cobre 17 exercícios (leg press, hack, extensora...).
- **Convites** (`convites/{codigo}`): o link é `?convite=CODIGO` e vale para várias pessoas por 7 dias. O de professor gera aluno; o do dono gera professor. As regras conferem o convite quando o usuário grava o próprio vínculo.
- **Telas** (`screens/academia/`): `PainelProfessorScreen` (alunos, convite e, para o dono, professores e equipamentos), `AlunoScreen`, `ProfessoresScreen`, `EquipamentosScreen`, `ConviteScreen` e `PainelSoftwareScreen` (totais, academias e autônomos, entradas recentes e "Adicionar pessoa"). `PainelSemana` (em `meus_treinos_screen.dart`) serve ao usuário comum, ao aluno e ao professor que abre um aluno; `TreinoDiaScreen` recebe um `ModoTreino`: `completo` (usuário comum), `registro` (aluno: só séries) ou `plano` (professor: só a estrutura, nunca a semana do aluno).
- **Regras:** o aluno não grava o próprio plano, o professor grava o plano e lê as semanas só dos próprios alunos (e perde o acesso se sair da academia), o dono mexe nos vínculos e nos equipamentos da própria academia, e o admin só vê contagens e nomes, nunca treinos. Ao remover um professor, os alunos dele passam para o dono.

### Modelo de treino

`TreinoService` guarda duas estruturas separadas em `usuarios/{uid}`:
- `plano/{1..7}`: os exercícios de cada dia da semana (1 = segunda, como em `DateTime.weekday`).
- `semanas/{AAAA-MM-DD}`: o que foi feito, com a segunda-feira como id. Só a semana atual é gravada, com merge por dia, então as semanas passadas não mudam.

Para comparar um exercício entre semanas, use `ExercicioTreino.chave` (slug ou nome normalizado), não o `id`, que muda se o exercício for removido e adicionado de novo.

`Exercicio.registro` define o `TipoRegistro` e quais campos de `SerieRegistro` são usados: `forca` (reps e carga), `distancia` e `intervalado` (km e tempo), `tempo` (segundos). Na musculação, só as isometrias (Prancha, Prancha Lateral) usam `tempo`; nos documentos do Firestore o campo só aparece quando não é `forca`.

### Interface

Cores e estilos de texto vêm de `theme/app_theme.dart` (`AppCores`, `AppTexto`), sem valores soltos nas telas. Os componentes compartilhados estão em `widgets/comuns.dart` e `widgets/treino_comuns.dart`.

### Testes e Firebase

Os testes não inicializam o Firebase, e os serviços acessam `FirebaseFirestore.instance` ao serem criados. Por isso, testes de tela só funcionam quando o serviço é injetado: `TreinoDiaScreen` recebe `service` no construtor e `treino_dia_test.dart` usa um `_ServicoFalso`. Telas que criam o próprio serviço, como `ListaExerciciosScreen`, não podem ser montadas em teste sem refatoração.

As regras do Firestore são testadas fora do Flutter, por `data/scripts/testar_regras_academia.py` contra o emulador (ver abaixo). Rode-o sempre que mexer em `firestore.rules`.

## Pipeline de dados (`data/`)

Os scripts Python são independentes do app. Os de imagem exigem Pillow.

O dataset do Everkinetic (CC BY-SA 4.0, crédito na tela inicial) não está no repositório. Um clone raso basta: `git clone --depth 1 https://github.com/everkinetic/data everkinetic-data`.

- `scripts/gerar_base_appgym.py <clone>/exercises.json <saída>`: gera `appgym_exercises.json`. Os exercícios incluídos, os campos da recomendação e os textos em português são curados no próprio script (`EXERCICIOS_SELECIONADOS`) e em `steps_pt.json`. Uma tradução só é usada se tiver o mesmo número de passos da fonte. Campos opcionais `primary`, `secundarios` e `equipamento` corrigem a fonte quando ela não bate com a ilustração.
- `scripts/baixar_imagens_everkinetic.py <clone> [slug ...] [--substituir] [--aplicar]`: copia as ilustrações para `app/assets/images` já em WebP. Usa `src/images-web` por padrão e o redesenho de `src/exercises` nos casos de `USAR_SRC`, onde a versão web está errada (algumas mostram outro exercício). Sem slugs, processa os exercícios que ainda não têm imagem.
- O clone também tem ilustrações no mesmo traço que não estão ligadas a nenhum exercício (`src/images-png-unknown`). Os exercícios que as usam ficam em `EXERCICIOS_SEM_REGISTRO` (gerador, com passos já em português) e `IMAGENS_SEM_REGISTRO` (script de imagens). Para um exercício que não existe em nenhum lugar no Everkinetic, a ilustração precisa ser feita à parte.
- `scripts/importar_firestore.py <chave.json> [--aplicar]`: publica a base na coleção `exercicios`. Exige uma chave de conta de serviço (fora do repositório). Sem `--aplicar`, só compara com o Firestore. Nunca apaga documentos.
- `scripts/gerar_ilustracoes_extra.py`: desenha as ilustrações de Corrida e Alongamentos em `app/assets/images`.
- `scripts/converter_imagens_webp.py <pasta> [--aplicar]`: converte PNG para WebP. Sem `--aplicar`, só relata o que faria.

- `scripts/popular_emulador_academia.py`: cria no **emulador** as contas fictícias do modo academia (senha `teste123`): `admin@`, `dono@`, `professor@`, `aluno@`, `aluno2@`, `aluno3@`, `dono2@`, `personal@` (professora autônoma), `aluno4@` e `usuario@fitwise.teste`, com academias, planos, semanas de histórico e os convites fixos `RAFA2026` e `PROF2026`. Só refaz o que é de teste (uids `teste-...`) e carrega o catálogo se o emulador estiver vazio.
- `scripts/testar_regras_academia.py`: entra com cada conta de teste e confere o que cada papel pode e não pode ler e gravar. Altera alguns dados; rode o script de popular antes de repetir.
- Os dois scripts usam as portas de `firebase.json`; as variáveis `EMULADOR_AUTH` e `EMULADOR_FIRESTORE` (ex.: `localhost:9098`) apontam para emuladores em outras portas. Um emulador que fica rodando sem o `firebase` que o abriu pode travar ou ficar muito lento; feche-o antes de testar.

Para testar uma base nova ou o modo academia sem publicar nada, use os emuladores:

```bash
firebase emulators:start --only auth,firestore                  # na raiz; portas 9099 e 8080, UI em 4000
python data/scripts/importar_firestore.py --emulador --aplicar  # carrega a base no emulador
python data/scripts/popular_emulador_academia.py                # contas fictícias do modo academia
flutter run -d chrome --dart-define=EMULADOR=true               # em app/

# Teste das regras, com os emuladores subindo e descendo sozinhos:
firebase emulators:exec --only auth,firestore "python data/scripts/popular_emulador_academia.py && python data/scripts/testar_regras_academia.py"
```

Com `EMULADOR=true`, o Firestore **e o login** vão para os emuladores, e o modo academia liga. A sua conta real não existe no emulador: entre com uma das contas fictícias ou crie uma nova pelo app. Tudo o que for gravado nesse modo fica só no emulador e some ao fechá-lo.

Alterar `appgym_exercises.json` não muda o app: é preciso rodar o importador. Publique o app (com as imagens novas) antes de importar, senão os exercícios novos aparecem sem ilustração. As ilustrações erradas não são detectadas por teste: ao incluir exercícios, confira as imagens a olho.

`planning/` contém os diagramas UML e o fluxograma da recomendação, em PDF.

## Registro de mudanças

Entradas da mais recente para a mais antiga, no formato `AAAA-MM-DD [rumo|alteração]: o que mudou e por quê`.

- 2026-11-09 [rumo]: modo academia publicado em produção (`ACADEMIAS=true` na CI e regras novas no Firestore). Para quem não tem papel o app continua igual; só quem tem `admins/{uid}` cria academias.
- 2026-11-09 [alteração]: o painel do dono do software ganhou "Adicionar pessoa" (dono de academia, professor autônomo, professor de academia ou aluno), totais separados de autônomos e a lista de entradas recentes, para acompanhar quem está entrando. Novo papel de professor autônomo (academia `tipo: autonomo`), com convite e telas próprios. Teste das regras com 76 casos.

- 2026-11-09 [rumo]: começo do modo academia (B2B), em teste: o app passa a poder ser vendido para academias, com dono, professores e alunos. Fica atrás de `Sessao.habilitada` (emulador ou `ACADEMIAS=true`) para que o app publicado continue igual para quem o usa hoje. Ver "Modo academia (em teste)".
- 2026-11-09 [alteração]: papéis, convites por link, painel do professor, tela de equipamentos do dono (o catálogo, o seletor e as sugestões escondem o que a academia não tem) e painel do dono do software com os totais de academias, donos, professores e alunos. `TreinoDiaScreen` ganhou `ModoTreino` (o aluno só registra séries; o professor só monta o plano e vê as cargas da semana do aluno) e, na academia, a opção "Como executar" no menu do exercício. O painel da semana virou o componente `PainelSemana`, reaproveitado pelo professor.
- 2026-11-09 [alteração]: `firestore.rules` reescrito para os papéis da academia, com as subcoleções `plano` e `semanas` listadas uma a uma (antes um curinga liberava qualquer subcoleção ao dono da conta). Para o usuário comum nada muda.
- 2026-11-09 [alteração]: emulador de login (porta 9099) em `firebase.json`; com `EMULADOR=true`, o app usa os dois emuladores, para que as contas fictícias não toquem o projeto real. Novos scripts `popular_emulador_academia.py` e `testar_regras_academia.py`, e novo teste `academia_test.dart`, também na CI.

- 2026-11-09 [alteração]: `.gitignore` passou a ignorar os logs do emulador (`*-debug.log`) e o `__pycache__` dos scripts.
- 2026-11-09 [alteração]: no detalhe do exercício, botões de anterior/próximo (e setas do teclado) que percorrem a lista de onde ele foi aberto, para não precisar voltar à lista a cada exercício; no detalhe e nas variações, botão de início que fecha as telas empilhadas e volta à aba Grupos, no lugar de vários toques em voltar. Novo teste `navegacao_test.dart`, também na CI.
- 2026-11-09 [alteração]: modo de teste com o emulador do Firestore (`emulators` em `firebase.json`, `--dart-define=EMULADOR=true` em `main.dart`, `--emulador` no importador), para conferir a base nova no app antes de publicá-la em produção.
- 2026-11-09 [alteração]: mais 9 exercícios (151 no total) usando ilustrações do Everkinetic que não têm registro no dataset, para manter o mesmo traço: Face Pull, Prancha, Elevação de Joelhos e de Pernas na Barra Fixa, Roda Abdominal, Abdominal na Polia Alta, Lenhador no Cabo, Abdução de Quadril Deitado e Agachamento Goblet. Prancha e Prancha Lateral passaram a registrar tempo, não reps e carga. Crucifixo inverso na máquina e elevação pélvica com barra continuam fora: não há ilustração deles no Everkinetic.
- 2026-11-09 [alteração]: revisão do catálogo de musculação, de 97 para 142 exercícios. O "Levantamento Terra no Smith" e a "Remada Cavalinho" mostravam uma flexão com os pés na bola: as imagens web do Everkinetic para esses slugs estão erradas na fonte; passaram a usar o redesenho de `src/exercises`. Pelo mesmo motivo foram trocadas as imagens de crucifixo e supino reto com halteres (mostravam banco inclinado), rosca inclinada, rosca concentrada (mostrava a rosca sentada comum), agachamento hack (quadros iguais), leg press com pernas juntas (repetia o leg press) e tríceps francês com haltere (mostrava um cabo).
- 2026-11-09 [alteração]: nomes e dados que não batiam com a ilustração: "Desenvolvimento com Barra em Pé" é sentado; "Elevação de Perna em Quatro Apoios" é em pé (virou "Coice em Pé no Peso Corporal"); a "Remada Aberta para Deltoide Posterior" é a remada serrote e foi para Costas; o tríceps sentado é com barra, não haltere. Nomes trocados pelos mais usados nas academias: Tríceps Pulley, Tríceps Corda, Tríceps Francês, Voador (Peck Deck), Remada Baixa, Abdominal Infra, Ponte de Glúteo.
- 2026-11-09 [alteração]: 45 exercícios novos, escolhidos entre os mais comuns em academia e que têm ilustração no Everkinetic: crucifixo inverso (curvado, deitado e no cabo), cadeira adutora, adução no cabo, tríceps testa, supino fechado, supino na máquina e no Smith, remada curvada, rosca martelo, Scott na máquina, agachamento búlgaro e sumô, panturrilha sentado, entre outros. Adutores ficam em Quadríceps (como na fonte), não em Glúteos, para a recomendação não trocar a adutora pela abdutora.
- 2026-11-09 [alteração]: Agachamento Jefferson passou de plano frontal para sagital e o crucifixo inverso com halteres usa vetor horizontal, para a recomendação não sugerir o Jefferson no lugar da adutora nem o Desenvolvimento Arnold no lugar do crucifixo inverso.
- 2026-11-09 [alteração]: `limpar_steps` descarta títulos soltos da fonte ("Steps", "Tip"); a barra fixa e a rosca alternada mostravam "Dica" e "Passos" como passos.
- 2026-11-09 [alteração]: novos scripts `baixar_imagens_everkinetic.py` e `importar_firestore.py`, para que a base e as imagens possam ser refeitas a partir do repositório; `Rotulos` ganhou os rótulos que faltavam (ex.: "Abdômen" aparecia sem acento); novo teste `catalogo_base_test.dart`, também na CI, confere grupo e imagens de cada exercício da base.
- 2026-11-03 [rumo]: adotada a regra de registrar toda mudança neste arquivo, para manter o histórico de decisões do projeto em um só lugar.
- 2026-11-03 [alteração]: criado este `CLAUDE.md`, para orientar as próximas sessões do Claude Code.
