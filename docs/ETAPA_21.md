# Etapa 21: domínio de bola nos detalhes (puxada, toque de lado, arrancada)

Tudo medido nos testes (`tests/dribble_test`, `tests/walk_probe`).

## Inverter a direção: puxada de sola
- Antes: frear conduzindo e depois virar. Levava 0,9–2 s (pior no jogo).
- Agora:
  1. ele **pisa na bola** com a sola;
  2. o corpo crava o pé de apoio e freia firme;
  3. gira por cima da bola (a sola leva a bola junto no giro);
  4. no fim solta a bola na frente da nova direção, já saindo.
- **~0,57 s** do comando até estar correndo de volta com a bola à frente,
  em todas as rodadas do teste.
- Os clipes de virada (180° correndo/andando, corte de 40°) não são mais usados
  com a bola: eram eles que giravam o corpo antes da bola.

## Toque de lado: primeiro o pé, depois o corpo
- Correndo e pedindo a esquerda, o corpo **segue reto** até o pé encostar na
  bola. O toque é com a parte de dentro do pé de fora: para a esquerda, o pé
  direito no lado direito da bola.
- Só depois do toque o corpo acompanha a bola.
- Toque de lado em ~0,05–0,5 s.

## Arrancada com bola
- Sem bola, ele chegava a 90% da velocidade em 0,25 s; com bola, levava
  **1–2,3 s**. Cada toque só deixava a bola 0,8 m/s mais rápida que o corpo.
- Agora o toque já leva a bola no ritmo da arrancada: **0,35–0,7 s** com bola.

## Bola presa no pé
- **Bola "na grama"**: com a bola no pé de alguém, ela rola 1,6× menos (mais
  atrito). Não foge entre os toques. Passes e chutes rolam normal.
- O corpo mantém a bola **~0,3–0,45 m à frente**, a distância da passada.
  Antes ela chegava a ficar debaixo do corpo, a 10 cm.
- O ajuste do corpo até o pé quase não empurra mais para a frente; era ele que
  fazia o jogador atropelar a bola e "perder o jeito" (cair de 2,9 para
  0,5 m/s).
- A bola não ziguezagueia de um pé para o outro: o lado de cada toque varia
  só 2,5 cm.

## Troca automática de jogador
- Bola solta (passe errado, rebote) que um companheiro alcança bem antes: o
  **controle vai para ele**. Não troca enquanto você está buscando com CORRER.

## Postura
- Na corrida, o tronco (4°) e a cabeça (5°) ficam um pouco menos inclinados
  para a frente, proporcional à velocidade. A cabeça não fica tão à frente do
  corpo.
