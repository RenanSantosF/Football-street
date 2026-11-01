# Planejamento técnico

Nome provisório: **Rua 10** (ou *Football Street*). O nome aparece em um só lugar:
`project.godot` → `config/name`. Trocar depois custa uma linha.

Motor: **Godot 4.3** (renderizador *Mobile*, física Godot padrão), destino Android.

---

## 1. Arquitetura definitiva

### Princípios

1. **Organização por funcionalidade**: cada pasta em `src/` contém a cena (`.tscn`) e
   os scripts daquela parte do jogo. Fica mais fácil achar as coisas no editor do celular.
2. **Humano e IA usam a mesma interface.** Um `controller` (HumanInput ou AIController)
   preenche um `PlayerIntent` (direção, correr, ação + força). O `Player` só obedece ao
   intent. Por isso a IA nunca "trapaceia": anda, conduz e chuta pelas mesmas regras
   e animações do jogador humano.
3. **A bola é independente.** `Ball` é um RigidBody3D. Ninguém prende a bola ao pé:
   jogadores só alteram a velocidade dela por toques, chutes e desvios.
4. **Lógica separada da animação.** O `Player` decide *o que* acontece (estado, ação,
   instante do contato com a bola). O `PlayerAnimationController` só traduz isso para o
   AnimationTree. Trocar o modelo ou as animações não mexe nas regras.
5. **Eventos globais** (`GameEvents`, autoload): gol, bola fora, posse, chute, placar.
   Torcida, câmera, UI e áudio só escutam. Dá para adicionar a torcida sem tocar nas regras.
6. **Dados em um lugar só**: medidas do campo em `Field`, times em `Team`, aparência em
   `CharacterAppearance` (Resource).

### Diagrama

```
Main (main.tscn)
├── Street            StreetBuilder: rua, calçadas, casas, linhas, luz, céu
├── GoalLeft/Right    GoalController: trave de ferro + detecção de gol
├── Ball              Ball (RigidBody3D)
├── MatchCamera       MatchCamera: câmera elevada que segue a jogada
├── HumanInput        lê toque/teclado/controle → PlayerIntent
├── Players           (criados pelo MatchManager)
│   └── Player ×6     CharacterBody3D
│       ├── Visual                  modelo (Etapa 1: manequim; Etapa 2: humanoide)
│       ├── BallControl             domínio, condução, passe, chute, desarme
│       ├── AIController            IA (usada quando não é o jogador humano)
│       └── PlayerAnimationController  ponte para o AnimationTree
├── MatchManager      regras, placar, saída, reinícios, troca de jogador
│   └── BallOutSystem bola fora → (Etapa 6: busca da bola) → reinício
├── Spectators        (Etapa 6) torcida nas laterais + garotos atrás das traves
└── MobileUI          analógico, botões, placar, mensagens, barra de força
```

### Camadas de colisão

| Camada | Uso | Colide com |
|---|---|---|
| 1 `world` | chão, meio-fio, muros, traves, postes | — |
| 2 `players` | jogadores | world, players |
| 3 `ball` | bola | world |

Bola e jogador **não** colidem fisicamente (evita a bola "grudar"/tremer no corpo).
O contato bola↔corpo é tratado no `BallControl` (desvio realista com restituição).

---

## 2. Recursos 3D necessários

Tudo gratuito. Quantidades pensadas para um celular intermediário.

| Recurso | Quantidade | Orçamento | Fonte sugerida |
|---|---|---|---|
| Corpo humanoide base adolescente (masc.) | 1–2 bases | 8–15 mil triângulos | Quaternius *Universal Base Characters* (CC0) ou Mixamo |
| Cabeças/rostos variados | 4–6 | 1,5–3 mil | variações da base / blend shapes |
| Cabelos (malhas separadas) | 5–8 | 300–1.500 | Quaternius, Sketchfab CC0/CC-BY |
| Camisetas, bermudas, tênis (malhas separadas ou máscaras de textura) | 3–4 cada | — | junto da base |
| Texturas de pele (tons) | 1 textura + cor via material | 512–1024 px | gerada/ajustada no próprio Godot |
| Bola | 1 | 200 | já feita (procedural) |
| Trave de ferro | 1 | 300 | já feita (procedural) |
| Casas modulares (fachada, portão, janela, muro, telhado) | 8–12 peças | 200–800 cada | Kenney (CC0), Quaternius, modelagem simples |
| Objetos de bairro (poste, lixeira, bicicleta, carro parado, chinelo, tijolo) | 6–10 | 100–1.500 | Kenney, Quaternius, Poly Pizza (CC0) |
| Animações humanoides | ~45 clipes | — | Mixamo (gratuito) + vídeo→mocap |

Regras de desempenho: texturas no máximo 1024 px (512 para objetos pequenos),
compressão ETC2/ASTC (já ativada), materiais compartilhados, uma única luz direcional
com sombra, sem sombras dinâmicas da torcida distante, LOD automático do Godot.

---

## 3. Estratégia para animações realistas (prioridade máxima)

1. **Animações capturadas de gente de verdade, não feitas por código.** Base em
   **Mixamo** (gratuito, conta Adobe gratuita), que tem centenas de clipes de mocap,
   incluindo uma família de futebol (busque por `soccer`: passes, chutes, carrinho,
   domínio, comemorações, goleiro). Locomoção: `Idle`, `Walking`, `Jog Forward`,
   `Running`, `Fast Run`, `Running Turn 180`, `Run To Stop`, `Standing Up`, `Falling`,
   `Out Of Breath`, `Angry`, `Cheering`, `Talking`, `Clapping` etc.
2. **O que não existir pronto (pedalada, cortes, finta de corpo) vem de vídeo → mocap**:
   grave você ou um amigo fazendo o drible com o celular e converta em animação FBX
   com ferramentas que têm plano gratuito e funcionam no navegador (ex.: Rokoko Vision,
   DeepMotion Animate 3D). É captura de movimento real a custo zero.
3. **Sem deslizar**: locomoção "In Place" + velocidade real do corpo dirigindo um
   `BlendSpace1D` (parado → andando → trotando → correndo). A velocidade da animação
   é ajustada para casar a passada com o deslocamento.
4. **Root motion** para ações que deslocam o corpo de forma característica (dribles,
   carrinho, queda, levantar): o deslocamento vem da própria animação
   (`AnimationTree.root_motion_track`), não de código.
5. **Sincronia pé↔bola**: cada animação de contato (passe, chute, toque de condução,
   drible) tem o instante do contato registrado numa tabela de eventos. O
   `Player._do_contact()` (já existe) é chamado nesse quadro exato pelo
   `PlayerAnimationController.on_animation_contact()`. A bola sai quando o pé encosta.
6. **Transições**: `AnimationNodeStateMachine` com cross-fade curto (0,1–0,2 s),
   estados dedicados para mudança de direção e parada brusca, `OneShot` para
   reações rápidas.
7. **IK apenas onde agrega**: cabeça/olhar acompanhando a bola (jogadores e torcida)
   com um `SkeletonModifier3D` próprio (recurso novo da 4.3), com limites de ângulo.
   Ajuste do pé na bola com `SkeletonIK3D` só se necessário. Nada de mexer ossos
   aleatoriamente.

### Árvore de animação planejada (AnimationTree → StateMachine)

```
Locomotion      BlendSpace1D: Idle | Walk | Jog | Run
LocomotionBall  BlendSpace1D: IdleBall | DribbleWalk | DribbleJog | DribbleRun
TurnBack        Running Turn 180            (mudança de direção)
SuddenStop      Run To Stop                 (parada brusca)
Shield          proteger a bola
Receive         domínio
PassShort / PassLong / Shoot / ShootPower
Dribble         (Etapa 4: Pedalada, CutLeft, CutRight, BodyFeint, QuickTurn, Beat)
Mark (BlendSpace2D strafe) / Tackle / Slide / Stumble
Fall / GetUp / Celebrate / Complain / Tired
GK_Idle / GK_Shuffle / GK_DiveLeft / GK_DiveRight / GK_Catch
```

Os nomes dos estados são o "contrato" com o código
(`PlayerAnimationController.ACTION_STATES`).

---

## 4. Como importar personagens e animações humanoides (fluxo pelo Android)

**Por que funciona sem computador:** o Godot 4.3 importa **FBX nativamente** (ufbx) e
tem **retargeting humanoide embutido** (`BoneMap` + `SkeletonProfileHumanoid`) na tela
*Advanced Import Settings*, que existe também no editor Android. Não precisa de Blender.

### Esqueleto compartilhado

Todo modelo e toda animação passam pelo mesmo perfil: **SkeletonProfileHumanoid** do
Godot (ossos com nomes padronizados: `Hips`, `Spine`, `Chest`, `Head`, `LeftUpperLeg`...).
Depois do retarget, qualquer animação toca em qualquer personagem.

### Passo a passo (detalhado na Etapa 2)

1. Baixar o personagem (FBX ou GLB) e as animações (Mixamo: *FBX Binary*, *Without
   Skin* para as animações, *In Place* para locomoção).
2. Copiar para `assets/characters/` e `assets/animations/` (gerenciador de arquivos
   do Android).
3. No Godot: duplo toque no arquivo → *Advanced…* → nó `Skeleton3D` →
   *Retarget → Bone Map* → **New BoneMap** → perfil **SkeletonProfileHumanoid**
   (o Godot mapeia sozinho ossos do Mixamo/Quaternius). Ativar *Rest Fixer*:
   *Overwrite Axis*, *Fix Silhouette*; *Remove Tracks → Unmapped Bones*.
4. Nas animações: aba *Animation* → *Save to File* → uma **AnimationLibrary**
   `assets/animations/street_moves.res` compartilhada por todos.
5. O modelo vira a cena `Visual` do jogador com `AnimationPlayer` (usando a biblioteca)
   + `AnimationTree` (a máquina de estados acima).
6. Roupas/cabelos são malhas separadas presas ao mesmo `Skeleton3D`; cor da pele,
   sujeira e cores das roupas são parâmetros de material aplicados por
   `CharacterAppearance`. Um personagem novo = uma nova "receita", não um novo modelo.

---

## 5. Organização das cenas e scripts

```
res://
├── project.godot
├── assets/               (modelos, animações, texturas, áudio — a partir da Etapa 2)
├── docs/                 planejamento e guias por etapa
├── tests/                testes automáticos (rodam no PC/servidor; opcionais)
└── src/
    ├── autoload/   game_events.gd, input_setup.gd
    ├── core/       field.gd (medidas), team.gd
    ├── main/       main.tscn
    ├── street/     street.tscn, street_builder.gd
    ├── goal/       goal.tscn, goal_controller.gd
    ├── ball/       ball.tscn, ball_controller.gd
    ├── player/     player.tscn, player_controller.gd, ball_control.gd,
    │               player_intent.gd, human_input.gd, character_appearance.gd,
    │               placeholder_body.gd, player_animation_controller.gd
    │               (Etapa 4: dribble_system.gd)
    ├── ai/         ai_controller.gd  (Etapa 5: goalkeeper_ai.gd, táticas)
    ├── match/      match_manager.gd, ball_out_system.gd
    │               (Etapa 6: ball_fetch_sequence.gd)
    ├── spectators/ (Etapa 6) spectator.tscn, spectator_controller.gd
    ├── camera/     match_camera.gd
    ├── ui/         mobile_ui.tscn, mobile_ui.gd, virtual_joystick.gd, touch_button.gd
    └── shaders/    noise.gdshaderinc, street_surface, paint_line, old_iron, street_ball
```

Correspondência com a sua lista: PlayerController = `player_controller.gd`;
PlayerAnimationController = `player_animation_controller.gd`; BallController =
`ball_controller.gd`; DribbleSystem = Etapa 4 (hoje o drible básico está em
`ball_control.gd`); MatchManager, AIController, GoalController, BallOutSystem
mantidos; SpectatorController na Etapa 6.

---

## Etapas

| # | Etapa | Entrega |
|---|---|---|
| **1** | **Fundação jogável** | projeto Android, rua graybox, traves, física da bola, condução por toques, passe/chute/desarme, câmera, controles de toque, regras básicas, IA simples 3×3 |
| 2 | Personagem + pipeline de animação | modelo humanoide, retarget, biblioteca de animações, locomoção com BlendSpace sem deslizar, sistema de skins/roupas |
| 3 | Animações de futebol | passe, chute, domínio e condução sincronizados com o contato na bola; root motion |
| 4 | Dribles e defesa | DribbleSystem (pedalada, cortes, finta, mudança rápida, drible de ultrapassagem), marcação, desarme, carrinho, quedas, recuperação |
| 5 | IA completa + goleiro | espaços, linhas de passe, coberturas, goleiro com defesas animadas |
| 6 | Torcida e busca da bola | adolescentes nas laterais (olhar seguindo a bola, conversa, reações) e garotos atrás das traves buscando a bola como parte das regras |
| 7 | Arte final e desempenho | casas modulares, objetos, iluminação, áudio, otimização |
| 8 | Publicação | menus, APK gerado automaticamente via GitHub Actions (sem computador) |
