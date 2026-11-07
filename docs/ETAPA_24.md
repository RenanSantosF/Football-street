# Etapa 24: física de futebol — condução híbrida, corpo a corpo e peso

## Diagnóstico (antes de mexer)
- **Bola "grudada"**: `BallControl._conduct` reescrevia a velocidade da bola
  a cada quadro rumo a um "bolso" à frente do jogador (ímã), e
  `_keep_ball_outside_body_and_feet` teletransportava a bola para fora do
  corpo/pés.
- **Toques reais nunca rodavam**: `_foot_contact_touch` abortava todo quadro
  com `SCRIPT ERROR` (atribuição `Array` → `Array[float]`, linha 575). No
  teste de contato, só 2 toques de pé em 520 quadros.
- **Colisão entre jogadores**: as cápsulas dos `CharacterBody3D` colidiam
  entre si (uma subia na outra → micro-saltos; travavam lado a lado) e, por
  cima, cada jogador se teletransportava 52% da sobreposição (104% no
  total → tremor).
- **Movimento**: um único `move_toward` linear — virar correndo não tinha
  inércia lateral, o corpo "deslizava" para a nova direção.

## 1. Locomoção com peso (`Player._locomote`)
- A velocidade é separada em **na direção desejada** e **lateral**.
- A lateral (inércia da curva) só cai pela **aderência do pé**
  (`lateral_grip` 13,5 m/s² devagar → `lateral_grip_sprint` 8 m/s² no sprint):
  curvas em velocidade abrem naturalmente.
- Aceleração com **curva força-velocidade**: arranque forte, fim suave.
- Inverter o sentido = **plantar o pé** (freada 25% mais forte).
- O **equilíbrio** (`balance`, 0..1) reduz aceleração e aderência depois de
  uma trombada e se recupera em ~1,3 s.

## 2. Corpo a corpo (`src/physics/player_contact_solver.gd`)
- As cápsulas agora só colidem com o cenário; o contato entre jogadores é
  resolvido uma vez por par, depois que todos se moveram:
  - **impulso** na normal do contato (quase inelástico), com a massa de cada
    um (`body_mass` 54 kg);
  - **atrito tangencial** leve (ombro a ombro);
  - **separação suave** por `move_and_collide` (respeita paredes), sem
    teletransporte e sem grudar.
- **Massa efetiva**: protegendo a bola (lenta, bola do lado oposto ao
  marcador) ×1,35; parado ×1,15; chutando (num pé só) ×0,8; desequilibrado
  menos.
- **Disputa de espaço**: quem empurra outro jogador acelera bem menos
  (empurrar quem conduz é ainda mais difícil).
- **Desequilíbrio / trombada**: o impulso recebido tira equilíbrio; passou do
  limite → tropeço (`stumble`). Com a bola: trombada leve deixa o próximo
  toque torto; forte faz a bola **espirrar do pé**. Trombada forte por trás em
  quem conduz = falta.
- Carrinho, queda e pulo continuam "fantasmas" (passam por baixo/por cima);
  viradas e paradas agora são sólidas (antes também atravessavam).

## 3. Condução automática e inteligente (híbrida)
O jogador só mexe o corpo; o sistema controla a bola:
- **Quando tocar**: a cada quadro o sistema prevê onde corpo e bola vão estar
  em 0,07 s. Toque quando o corpo alcança a bola, quando a bola sai da direção
  pedida (curva/corte) ou quando a arrancada a deixaria para trás.
- **Com qual pé**: o pé que está vindo para a frente na passada da animação
  (alternância natural); em cortes, o pé anatomicamente certo (chapa do
  esquerdo para cortar à direita etc.); protegendo, o pé longe do marcador.
- **O impulso**: no instante em que o pé (IK) encosta, a bola recebe a
  velocidade exata para voltar ao alcance do pé uma passada depois, onde o
  corpo vai estar (com a inércia atual) e com o atrito real do piso.
  - andando: toque a cada ~0,36 s, bola bem perto;
  - trote: ~0,5 s;
  - sprint: ~0,74 s, bola correndo até ~0,6–0,75 m à frente.
- **Desacelerar / parar**: o jogador dá mais uma ou duas passadas até a bola
  (no ritmo dela), amortece e pisa — os dois param juntos.
- **Inverter**: puxada de sola; a bola volta mansa ao lado do pé de apoio, o
  corpo segura em cima dela, gira e arranca.
- **Bola atrás/de lado**: o corpo contorna por fora, sem atravessar a bola.
- **Entre os toques** a bola rola livre; só existe uma correção lateral com
  aceleração limitada (2,2 m/s², o "jeito" do pé) — nunca um ímã.
- Corpo e pés são superfícies físicas para quem conduz: a bola que entra na
  canela é empurrada para fora por velocidade; o pé da passada que roça a
  bola a afasta de leve.
- **Erros de domínio**: bola forte, marcador colado ou corpo desequilibrado
  deixam o primeiro toque mais longo e torto.

## 4. Passes e chutes
- Passe fraco mínimo 6 m/s (antes 7,2), passe forte até 13 m/s; chute 10,5 →
  18,8 m/s (antes 9,5 → 16,2) — as faixas não se sobrepõem mais.

## Testes (headless, `--fixed-fps 60`)
- `dribble_test`: todos os casos passam (parar com a bola, inverter, virar
  longe, chacoalhar, passe para trás, bola atrás/lado/longe, virada leve,
  toque de lado em 0,13 s).
- `contact_test`: 24 toques de pé reais medidos (antes 2).
- `receive_test`: 12/12 domínios. `aerial_test`: igual ao original.
- **Novo** `body_contact_test`: trombada de frente (distância mínima 0,52 m,
  sem pulo, os dois se desequilibram), empurrar parado (0,4 m, sem grudar),
  ombro a ombro (sem atravessar, seguem correndo), proteção (quem conduz
  segura a carga: 0,18 m, mantém a bola).
- **Novo** `dribble_probe_test` (diagnóstico): `CEN=stop|run|behind|turn|reverse`
  imprime corpo, bola e pé quadro a quadro.
- CI: reprova o build se qualquer teste tiver `SCRIPT ERROR`.
