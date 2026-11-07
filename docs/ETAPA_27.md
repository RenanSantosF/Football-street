# Etapa 27: sons reais, ritmo mais lento e pesado, animação sem tremor, novos gestos

Tudo das etapas anteriores foi mantido; a suíte inteira de testes roda sem
erro de script. Cada mudança foi medida antes e depois.

Ferramentas novas de medição:
- `tests/locomotion_probe`: passada em linha reta (cadência, deslize do pé,
  tremor, braços, quadril).
- `tests/jitter_hunt`: partida IA × IA procurando tremor e "piscadas" quadro
  a quadro, separado por situação.

## 1. Pé tremendo e corpo vibrando: causas e correções

| Causa encontrada | Correção | Medido (partida IA × IA, eventos/s) |
|---|---|---|
| A altura do jogador oscilava ±1,8 mm **a cada quadro**: a gravidade afundava o corpo no chão, a colisão devolvia, e o código só corrigia o corpo acima do chão. O corpo inteiro vibrava a 30 Hz e os pés (presos pelo IK) tremiam junto. | O corpo fica exatamente em y = 0 fora do pulo. | corpo: **34,3 → 2,2** |
| Com a bola, o alinhamento lateral do corpo ligava/desligava em 8 cm, alternando a velocidade a cada quadro. | Entrada suave (sem degrau). | (incluído acima) |
| Os clipes de passada (andar 1,23 s, trote 0,83 s, sprint 0,53 s, laterais 0,67–0,93 s) eram misturados **sem casar a fase**: entre duas velocidades, uma perna de um clipe estava à frente enquanto a do outro estava atrás. | Cada clipe cíclico é reamostrado para o mesmo ciclo e alinhado pelo instante em que o pé direito pisa (medido no esqueleto). A cadência natural vem da escala de tempo. As poses não mudam. | pé na locomoção: 6,2 → 2,8 por jogador |
| Clipes a 30 quadros/s com interpolação linear: solavanco a cada 33 ms. | Interpolação cúbica nas trilhas, passando pelas mesmas poses. | carrinho/giro: 40–60 → ~0 |
| Marcando em velocidade (até 3,75 m/s), a mistura de passadas laterais só ia até 2,25 m/s. Além disso, o marcador girava 6 rad/s, arrastando os pés. | O marcador rápido corre de verdade (com histerese). Giro do marcador limitado a 3,4 rad/s. Corrida e sprint entram na marcação. | pé total: **52,7 → 25,5** |
| Botão de profundidade aparecia/sumia com a posse oscilando. | Retenção de 0,4 s. | — |

Em linha reta, o pé apoiado desliza ≤ 2 cm/s em todas as velocidades.

## 2. Mais lento e mais pesado
Os toques, passes e chutes saem com a mesma velocidade da bola; só o corpo
mudou.

| | antes | agora |
|---|---|---|
| trote | 2,60 m/s | 2,25 m/s |
| sprint / com bola | 4,35 / 4,25 m/s | 3,85 / 3,70 m/s |
| aceleração / frenagem | 7,8 / 7,2 m/s² | 5,8 / 6,0 m/s² |
| giro do corpo | 6,6 rad/s (máx. 9) | 5,4 rad/s (máx. 7,5) |
| aderência na curva | 13,5 / 8,0 | 11,5 / 6,8 (curva mais aberta em velocidade) |

- **Pés mais lentos:** a cadência acompanha a velocidade (trote ~144 passos/min,
  sprint ~195).
- **Peso na passada:** o quadril voltou a subir e descer com a passada. Fica
  45% da oscilação original do próprio clipe (2–4 cm); antes era achatada em
  ±0,6 cm e o corpo "flutuava".
- **Braços com inércia:** cada braço é um pêndulo amortecido (~1,6 Hz, até
  ±11°). Arrancando ele fica para trás, freando vai à frente, na curva abre
  para fora.
- **Parada sem "braços de zumbi":** o clipe "Run To Stop" terminava com os
  dois braços esticados na horizontal. Agora os braços vão para a posição
  relaxada da respiração parada.

## 3. Gestos novos
- **Calcanhar:** passe para trás com a bola à frente do corpo (e fora de
  cobrança). Em vez de girar com a bola, o pé passa por cima dela e toca de
  volta com o calcanhar (modo de IK novo). Mais fraco e menos preciso que a
  chapa.
- **Voleio:** a bola chega no ar entre o joelho e a cintura (0,4–1,15 m) com
  CHUTE ou PASSE apertado → batida de primeira com o peito do pé na altura da
  bola (IK com alcance maior). Se o domínio de coxa/peito já começou e o botão
  chega a tempo, ele vira voleio. Mais torto que o chute com a bola no chão.
- **Profundidade arrastada = por cima:** arrastar o dedo no botão
  PROFUNDIDADE manda a bola pelo alto (tecla Y no teclado).
- **Inversão logo depois de um toque** (problema da Etapa 26): se a bola
  ainda foge à frente, o corpo acompanha 1–2 passos até a sola alcançar e só
  então puxa. Resultado: 10/10 rodadas com a bola à frente na nova direção
  (antes ~8/10).

Medido (`tests/skills27`):
- calcanhar sai sem girar o corpo e chega no companheiro;
- voleio de chute a 15 m/s rumo ao gol;
- voleio de passe chega no companheiro;
- profundidade arrastada sobe a 4–6 m/s na vertical.

## 4. Sons
Tudo posicional (3D), com:
- atenuação pela distância e perda de agudos com a distância;
- reverberação curta de rua;
- compressor e limitador (sem estourar no celular).

Detalhes em `src/audio/game_audio.gd`; origem e licença de cada som em
`CREDITS.md`.

- **Bola (sintetizada por modelo físico):** não existe gravação livre
  acessível de bola de futebol. Cada som é um pulso de força com o tempo de
  contato real (pé 9–16 ms, chão ~5 ms, ferro ~3 ms) passando pelos modos de
  vibração da casca e da cavidade de ar de uma bola de 11 cm (~1,0 / 1,7 /
  2,2 kHz). Contato longo (pé) quase não excita a cavidade ("tum"); contato
  curto (chão) excita ("póc"). Sons:
  - toque, passe e chute, com volume e timbre pela variação real de
    velocidade da bola;
  - quique, meio-fio;
  - cerca de madeira, alambrado, portão de ferro, muro de bloco (cada
    colisão da rua foi marcada com o material);
  - trave (modos de um tubo de ferro);
  - bola no corpo e na cabeça;
  - bola rolando (contínuo, pela velocidade).
- **Passos (gravações reais):** disparados quando o pé chega ao chão na pose
  final da animação. Andar e correr pela velocidade, com uma camada grave de
  peso do corpo. Derrapada em freada brusca.
- **Corpo:** trombada, queda, carrinho, pouso do pulo.
- **Apito** (sintetizado, tom de 3,2 kHz com o trinado da bolinha): falta e
  saída.
- **Vizinhos e crianças comemorando o gol; ambiência da rua:** pássaros,
  cidade ao longe.

Medido (`tests/audio_test`, partida de 1 min): todos os bancos carregam e cada
tipo de evento toca, em taxa realista (ex.: ~11 trombadas audíveis/min, ~2
derrapadas a cada 10 s).

## 5. Pedestres e crianças na calçada
Adultos andando e crianças correndo (às vezes em dupla, rindo e conversando)
nas duas calçadas:
- mesmo corpo e passada dos jogadores, em escala de adulto (1,72–1,85 m) ou
  de criança (1,25–1,40 m);
- cadência casada com a velocidade;
- alguns adultos param para olhar o jogo;
- passos e vozes posicionais.

Medido (`tests/pedestrians`): ficam na calçada, o pé apoia na altura dela e
somem no fim da rua.

## Limitações conhecidas
- Os sons foram escolhidos e sintetizados por **análise** (espectro,
  envelope), sem audição humana. A demo enviada serve para avaliar. Trocar
  um som é simples: basta substituir o `.ogg` em `assets/audio/` mantendo o
  nome.
- O freesound.org e o kenney.nl bloqueiam acesso automatizado; com sons
  baixados manualmente de lá dá para melhorar ainda mais a bola e as vozes.
- Não há clipe de calcanhar nem de voleio nas animações disponíveis. Os dois
  usam IK sobre a locomoção e o clipe de chute.
- `virada_leve_puxou_com_sola` continua `false` como antes (inalterado).
