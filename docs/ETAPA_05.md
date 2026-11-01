# Etapa 5 — Jogo mais lento e realista, nova rua, regras de pelada, câmera e placar

## Jogabilidade
- **Condução que acompanha o jogador**: se você virar para o lado oposto da
  bola, ele vai até ela (correndo mais que a bola se ela estiver fugindo),
  contorna, puxa com a sola e sai conduzindo na nova direção.
- **Ritmo mais lento**: trote 3,9 m/s, sprint 5,6 m/s, aceleração e giro mais
  suaves; a bola rola menos nos bloquinhos (1,45 m/s²).
- **Chute com mira**: segurando CHUTE, o analógico deixa de andar e passa a
  **mirar** (seta no chão; o tamanho mostra a força). A bola vai para onde você
  mirou — sem mira automática; tem que mirar no gol. Velocidade 8–17 m/s.
- **Giro parado com passinhos**: girar parado alimenta a animação de passos.

## Regras da pelada
- **Sem goleiro**, 3 contra 3 na linha, **gol menor** (1,6 m × 0,95 m).
- **Lateral só por cima do meio-fio**: bola rasteira bate no meio-fio e volta;
  só sai se passar por cima e cair na calçada.
- **Saída, lateral, escanteio e tiro de meta**: quem bate fica parado com a
  bola e é **obrigado a tocar para um companheiro** (não sai andando).
  O analógico só gira o corpo para mirar o passe.
- **Escanteio**: bola pela linha de fundo tocada por último pela defesa.

## Câmera e interface
- Câmera **bem mais próxima** do jogador (não mostra a rua toda).
- **Minimapa** no canto superior esquerdo: campo, traves, jogadores e bola.
- **Placar novo** com as cores dos times; o número **salta e brilha** no gol.
- Faixa **"GOOOL!"** animada.
- **Câmera de cinegrafista** no gol: chega perto de quem marcou, na altura dos
  ombros, gira em volta da comemoração com leve balanço de câmera na mão.
- Times: **RUA DE CIMA** (laranja) × **RUA DE BAIXO** (azul). Como todos usam a
  mesma skin, há um disco discreto na cor do time sob os pés.

## Rua nova (15h da tarde)
- Rua de **10 m**, chão de **bloquete gasto**: blocos de tons diferentes,
  quinas gastas, juntas com terra e mato, blocos afundados e faltando, sujeira,
  manchas de óleo e poças rasas (com reflexo leve do céu e das cercas).
- **Sem casas**: cercas de **tábua velha** (tábuas tortas, faltando, base suja
  de barro), cercas de **arame** com mourões tortos, **portão de ferro**
  enferrujado, pedaço de **muro de bloco sem reboco** (obra parada).
- **Quintais** com mangueiras e bananeira aparecendo por cima das cercas
  (só tronco, galhos e parte da copa), **postes de madeira** com fios caídos.
- Calçada de concreto quebrado com faixa de terra e mato junto da cerca;
  **cadeira de plástico branca**, pneu velho, bicicleta encostada, saco de lixo.
- **Sol das 15h**: sol alto e claro, sombras das cercas, árvores e postes
  sobre a rua; céu limpo; tonalização ACES, brilho leve e sonda de reflexo.
- **Pedestres** passando nas calçadas (mesma skin por enquanto), às vezes param
  para olhar o jogo.

## Testes
- `tests/rules_test.tscn` (PC): virar com a bola, chute mirado, reinício
  travado, meio-fio devolvendo a bola — todos passando.
