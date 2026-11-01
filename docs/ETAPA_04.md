# Etapa 4 — Animações e skins (pack do autor + personagem adolescente)

Foco 100% em animação e aparência, usando os 54 arquivos do Mixamo enviados.

## Personagem adolescente (skin base)

O arquivo com textura (*Goalkeeper Idle parado na zaga…*) virou o **corpo base**
de todos os jogadores: `assets/characters/teen_01/teen_01.fbx`.

Correções automáticas (valem para qualquer personagem novo do mesmo tipo):
- **Esqueleto deslocado da malha**: o FBX veio com a pose de descanso 0,49 m
  abaixo e 0,56 m à frente da malha. O `HumanoidCharacter` compara a pose de
  *bind* da malha com o esqueleto e corrige o descanso e o `motion_scale`.
- **Altura**: o modelo tem 1 m; todo corpo base é normalizado para 1,64 m
  (com variação individual de 0,94–1,05).
- **Animações gravadas nesse esqueleto**: a trilha do quadril vinha normalizada
  pela altura errada (0,03 m em vez de 0,53 m). O `AnimationCatalog` calcula a
  altura real pela própria pose (quadril → ponta do pé) e corrige.

### Variação de cada jogador (uma malha só)
| O que varia | Como |
|---|---|
| Tom de pele (7 tons) | shader troca o tom pela luminância, preservando sombras e detalhes |
| Cor do cabelo | pixels escuros da cabeça recebem a cor escolhida |
| Camiseta (ou sem camisa) | máscara por **pesos de skin** (tronco + meia manga), funciona em qualquer pose |
| Bermuda | jeans original da textura **ou** cor nova |
| Tênis + meia, ou **descalço** | 25% jogam descalços, como na rua |
| Sujeira | manchas na roupa e no tênis |
| Altura e porte | escala do modelo + ombros/tronco |

## Animações em uso

| Situação | Clipes |
|---|---|
| Parado / andar / trote / corrida / sprint | Soccer Idle, Walk (UAL), Slow Jog, Standard Run, Sprint |
| Arrancada (parado → sprint) | Idle To Sprint |
| **Condução** | Offensive Idle (parado com bola), **Dribble**, Standard Run, Sprint |
| **Marcação** (encara quem conduz, anda de lado/de costas) | *Goalkeeper Idle parado na zaga* (postura), Jog/Left/Right Strafe, Left Strafe Walking, Run Backward, Jog Forward Diagonal (2) |
| Passe curto / longo | Soccer Pass toque (pé em 0,50 s) / Kick Soccerball (0,20 s) |
| Chute / chute forte | Strike Foward Jog (0,45 s) / Soccer Penalty Kick (0,79 s) |
| Domínio | Stall Soccerball (1) (sola na bola em 0,29 s) |
| **Giro (roleta)** | Soccer Spin — botão DRIBLE para a frente; bola acompanha o pé e sai no fim |
| **Carrinho** | Soccer Tackle (2) — chute sem a bola a 1,3–3,2 m de quem conduz |
| **Pular o carrinho** | Running Jump — quem conduz pode pular (IA 35%, humano 25%) |
| **Tropeçar e cair** | Soccer Trip → Fallen Idle (caído) |
| Goleiro | marcação sempre (postura + passos laterais), Goalkeeper Catch (defesa), Goalkeeper Pass (rola a bola com a mão) |
| Gol | quem marcou: Samba ou Victory; companheiros: Victory → Victory Idle; quem sofreu: Defeated |

**Root motion**: carrinho, queda, pulo e giro movem o corpo pela curva de
deslocamento gravada no próprio clipe (a física segue a animação).

Reservados para a Etapa 6 (adolescentes esperando atrás das traves e na
calçada): Kick Up Soccerball, Kneeing Soccerball, Header Soccerball,
Offensive Idle aquecimento, Goalkeeper Placing Ball.

## Pedidos ao autor (Mixamo)

Baixar **no mesmo personagem**, *FBX Binary*, *Without Skin*, 30 fps, e colocar em
`assets/animations/mixamo/pack/` com estes nomes exatos (a importação já está pronta):

1. **`Standing Up.fbx`** — levantar do chão (fim do carrinho e da queda). Hoje o
   jogador "levanta" por uma transição curta.
2. **`Goalkeeper Diving Save.fbx`** — goleiro se jogando (defesa de canto).

Para **mais variedade de skins**: gere mais 3–5 adolescentes diferentes (rosto,
cabelo, corpo, roupa) do mesmo jeito que o primeiro, rigue no Mixamo e baixe
cada um **com skin** (qualquer animação). Cada um vira mais um corpo base com
todas as animações funcionando.

## Arquivos no celular

O repositório é **público**, então seus arquivos do Mixamo e o personagem **não**
vão para o GitHub (estão no `.gitignore`). No celular, copie:
- os 53 `.fbx` de animação para `assets/animations/mixamo/pack/` (nomes como vieram);
- o personagem (*Goalkeeper Idle parado na zaga…fbx*) para
  `assets/characters/teen_01/` **renomeado para `teen_01.fbx`**.

Sem esses arquivos o projeto continua abrindo (usa o corpo e as animações CC0).

> Recomendação: deixe o repositório **privado** (GitHub → Settings → General →
> Danger Zone → Change visibility). Aí eu posso versionar os arquivos e o APK
> pode ser gerado automaticamente no GitHub.

## Testar
- **APK**: instale e jogue.
- `tests/skills_lab.tscn`: carrinho × pulo, carrinho × queda, giro.
- `tests/kick_lab.tscn`: passes e chutes com o pé na bola.
- `tests/character_lab.tscn`: locomoção.
