# Etapa 12 — Arquitetura de condução/posse/chute (DribblePoint, KickPoint, PickupArea)

Reescrita da física de posse, condução e chute seguindo a arquitetura de
referência enviada pelo autor, adaptada ao projeto.

## Onde ficam os nós (cena `src/player/player.tscn`)
```
Player (CharacterBody3D)          ← gira inteiro; FRENTE = -Z
├─ CollisionShape3D (cápsula)
├─ Visual (Node3D, humanoid_character.gd)   ← o modelo Mixamo (+Z) está girado 180° aqui dentro
│  ├─ DribblePoint  (Marker3D)  posição (0, 0, -0.55)   no chão, à frente
│  ├─ KickPoint     (Marker3D)  posição (0.13, 0, -0.45) à frente do pé DIREITO
│  ├─ KickPointLeft (Marker3D)  posição (-0.13, 0, -0.45) pé esquerdo (chute espelhado)
│  └─ PickupArea    (Area3D)    posição (0, 0.2, -0.2), layer 0, mask 4 (bola)
│     └─ CollisionShape3D (esfera r = 0,6)
├─ SelectionRing, BallControl, AIController, PlayerAnimationController
```
A bola (`src/ball/ball.tscn`) está no grupo **"ball"**, layer 4, mask 3 (chão +
jogadores: bola solta bate no corpo de verdade).

## Eixo de frente
O nó `Player` é que gira: `rotation.y = atan2(-x, -z)` → frente = **-Z**
(`-basis.z`). O FBX do Mixamo olha para +Z e por isso está girado 180°
(`model.rotation.y = PI`) dentro do `Visual`. Por isso os Markers ficam em **Z
negativo** e o ângulo usa `atan2(-x, -z)`.

## Posse
- `PickupArea` detecta a bola (body_entered + sobreposição a cada quadro).
- `grab_ball()`: `add_collision_exception_with(bola)` (não quica na canela) e
  `linear_damp = 2`.
- `release_ball()`: rolamento livre e a colisão com o corpo volta 0,25 s depois.
- A posse se perde a 1,7 m (`dribble_lose_distance`).

## Condução (`BallControl._process_ball_dribble`)
- Correndo: um toque a cada `dribble_tap_interval` (0,28 s) para
  `DribblePoint + frente·0,35` (`×11 + velocidade·0,45`). O toque é dado pelo
  PÉ (IK) e só aplicado no contato; durante uma virada pesada não empurra.
- Entre os toques: alinhamento suave ao DribblePoint (`×6,5 + vel·0,6`,
  lerp 8·dt). **Atenção:** esse alinhamento mexe a bola sem toque do pé (é o
  que a referência faz). Ajustável em `dribble_pull` (0 = desliga).
- Parado: a sola vai até a bola e a estabiliza perto do pé (`×9`).

## Chute (`iniciar_chute` / `executar_impacto_chute`)
- Ao apertar: a animação começa com o tempo certo até o contato; o corpo
  desacelera (25% do analógico) para firmar o pé de apoio.
- Durante a preparação a bola é alinhada no **KickPoint** (ou KickPointLeft)
  em 0,18 s (`kick_snap_time`) e fica ali.
- O impacto acontece no **quadro de contato do clipe** (tabela de contatos
  conferida quadro a quadro), não num timer fixo; o pé que chuta vai até a
  bola (IK). Sai com rotação de rolamento (18 rad/s) e 0,45 s sem poder dominar.

## Movimento
- Rotação com inércia por `lerp_angle`: 11 sem bola / **6,5 com bola**.
- Aceleração 10; velocidade máxima 5,5 (CORRER) e 4,3 conduzindo.
- Sem viradas "de clipe" com a bola (o peso vem da rotação lenta).
- AnimationTree mantido (BlendSpace2D em m/s reais — o pé não desliza).
