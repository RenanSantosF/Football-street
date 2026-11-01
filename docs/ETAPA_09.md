# Etapa 9 — Condução, domínio e animações de jogabilidade

## Condução (reescrita)
- **Soltou o analógico = para a bola**: o jogador vai até a bola (se ela rolou à
  frente) e pisa nela; correndo forte, faz a parada brusca ("Run To Stop")
  com a bola junto.
- **Inverter a direção = puxada de sola**: a bola é puxada para trás por baixo do
  corpo e o jogador vira e segue com ela (ou a virada de 180° correndo).
- **Mudou de direção com a bola longe** (passada longa): primeiro ele alcança a
  bola, chega por trás dela em relação à nova direção e só então dá o toque.
  Nunca mais volta e deixa a bola abandonada.
- **Toque de lado com o pé certo**: indo para a direita, o pé bate no lado
  esquerdo da bola (e vice-versa) — o toque espera o pé certo chegar na bola.
- Bola mais perto do pé (toques curtos).
- **Analógico suavizado**: chacoalhar de um lado para o outro não deixa o
  jogador perdido; uma inversão clara (segurada um instante) vira puxada.
- Comandos apertados durante uma parada/virada não se perdem mais.

## Animações e transições
- Corrida com e sem bola agora é UMA mistura só (BlendSpace2D sincronizado):
  ganhar/perder a bola não "pula" a pose.
- Ações (passe, chute, domínio, viradas) voltam para a corrida no fim do clipe
  ou na hora em que o jogador sai andando.

## Domínio e recepção
- O recebedor vai sozinho até a bola (o analógico só ajusta um pouco) e não dá
  para trocar de jogador com o passe a caminho; os botões mostram
  **PASSE/CHUTE de primeira**.
- Primeiro toque amortece: a bola morre no pé (ou já sai para onde o analógico aponta).
- **Pela altura da bola**: coxa (Kneeing Soccerball), peito (Receive),
  cabeça (Header Soccerball). Com PASSE/CHUTE apertado antes: **cabeceio de
  primeira** (Header) para o companheiro ou para o gol. Bola muito alta:
  cabeceio com salto (Soccer Header).
- Só quem vai receber pode pegar o passe (o passador não "rouba" o próprio passe).

## Passe e chute
- **Pé esquerdo**: bola à esquerda do corpo ou chute/passe para a esquerda →
  pé esquerdo (os clipes são espelhados com precisão; o esqueleto é simétrico).
- **Passe para trás**: o jogador gira com a bola na sola e toca de frente
  (preciso, sem "cair").
- Toque curto mais forte e preciso (9,5–12 m/s, desvio 0,25–1°); chute mais
  preciso; passe por cima e cavadinha mais altos; passe em profundidade morre
  perto do ponto (não sai do campo).
- **Barra de força no anel do jogador** (verde → vermelho, enche no sentido horário).

## Reinícios
- Saída, lateral, escanteio, tiro de meta e falta: a bola fica **travada no
  lugar** até o passe. O analógico só gira o jogador em volta dela (mira).

## Buscar / desarme
- BUSCAR corre em sprint e aceita o analógico para escolher por onde chegar
  (ex.: dar a volta e pegar de frente). Chegando no adversário, dá o bote
  sozinho; bote de frente tem mais chance, por trás menos.

## Testes (PC)
- `tests/dribble_test.tscn` (parar, inverter, virar com a bola longe,
  chacoalhar, passe para trás), `tests/aerial_test.tscn` (coxa, peito, cabeça,
  cabeceio de primeira), além de rules, gameplay, human_input e autoplay.
