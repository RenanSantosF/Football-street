# Etapa 19: movimento natural (pé sem torção, sem deslizar, sem "teleporte")

Feito com **medição**, não no olho. Dois detectores novos:
- `tests/anim_probe.tscn`: roda uma partida e mede, por animação, quanto o pé
  apoiado desliza e quantas vezes o quadril "pula" de um quadro para o outro.
- `tests/walk_probe.tscn`: anda reto em várias velocidades, com e sem bola,
  e mede o deslize do pé apoiado.

## Pé contorcido: acabou a IK da perna
- A IK que puxava a perna até a bola era o que torcia o pé e o joelho. Foi
  **desligada**: a perna é sempre exatamente a da animação.
- O toque só acontece quando o **pé da passada chega na bola**. Até lá, o
  **corpo inteiro** dá o ajuste: um deslocamento pequeno do jogador, que a
  passada acompanha. Se o pé não chegar, a bola não é tocada; o jogo não finge
  o toque.
- Sem o "empurrão" do Visual que existia antes (ele deslizava o corpo sobre os
  pés).

## Pé deslizando ("flutuando")
- **Causa principal**: entre 1,8 e 4 m/s o jogo misturava duas animações de
  corrida com ritmos diferentes. Os pés ficavam fora de fase e o pé apoiado
  andava até 1,3 m/s.
- Agora toca **uma animação de passada por vez** (andar, trote, corrida,
  sprint). A velocidade do clipe é ajustada para bater **exatamente** com a do
  corpo, e a troca entre clipes leva ~0,2 s.
- A velocidade real de cada clipe foi medida:
  - o "Slow Jog" vinha com o quadril torto 40° e foi trocado pelo "Jog
    Forward";
  - a condução com bola é 2,1 m/s, não 2,56.
- Resultado reto, sem bola, de 0,5 a 3,2 m/s: o pé apoiado desliza **< 1 cm/s**
  (antes até 127 cm/s). Na partida, a média na corrida caiu de 38 para
  22–24 cm/s, por causa das curvas e das paradas.
- Andando devagar a caminhada fica mais lenta (até 12% da velocidade), em vez
  de o boneco ficar parado deslizando.
- Parado, o corpo não gira mais "no eixo" com os pés colados: giro lento, e
  giros grandes usam os clipes de virada.
- Comemoração/lamento só começam depois que o jogador para. Andando de volta
  para a posição, ele anda de verdade.
- Passes e chutes: os passos de aproximação são os da animação; o corpo só
  corrige a diferença até a bola.

## "Teleporte" entre animações
- **Viradas** (90°, 180°, corte, giro com a sola): o corpo dava um salto de
  50–95° no último quadro. Agora o giro sai da própria animação, quadro a
  quadro, e não há salto no fim.
- O corpo nunca gira mais rápido que 9 rad/s (7 com a bola).
- Marcação: o "Run Backward" vinha com o corpo virado 180° e, misturado aos
  outros passos, o quadril "estalava" 70–130°. Foi tirado. Recuando rápido, o
  jogador vira e corre.
- O passo de marcação muda de direção suavemente.
- No detector, os saltos de pose foram de ~230 por minuto de partida para 2.

## Condução
- Correndo e invertendo: freia a bola com a sola antes de virar. A virada
  correndo só acontece com a bola parada no pé.
- Bola entre os pés esperando o toque: o corpo não passa da bola.
- "No pé" agora é só a bola na frente, perto da linha dos pés; senão o jogador
  se posiciona atrás dela.
- Sprint com bola chega a 3,5–3,9 m/s (antes travava em ~3).
