# Etapa 10 — Passe rasteiro com seta, condução assistida, animações mais suaves

## Passe e chute
- **Segurar PASSE = passe RASTEIRO mais forte** (9,5 a 15 m/s). A bola só sobe
  se você **arrastar o dedo** (passe por cima / cavadinha). Mesmo no chute.
- **Seta do passe** enquanto segura PASSE: **azul** = assistido (vai no
  companheiro mais perto da direção do analógico, cone de 45°); **branca** =
  em profundidade (ninguém na direção: a bola vai para o espaço).
- O passe sai exatamente para quem a seta mostrou.
- A mira (passe e chute) usa o analógico sem suavização: sem atraso.
- Chute mais baixo e preciso (sem subir à toa).

## Condução
- Corrigido o bug do print: com a bola **atrás** do corpo, o jogador ficava
  empurrando a bola junto atrás dele. Agora ele volta por fora, contorna a bola
  e segue com ela na frente.
- **Assistência de condução**: entre os toques a bola fica num corredor à
  frente do pé (não escapa para o lado nem dispara à frente).
- Na virada correndo, o toque considera a inércia do corpo (a bola não sai
  para um lado que o jogador ainda não alcança).

## Animações
- Fim do "deslizando com o pé esticado": se a ação já acabou e o jogador está
  correndo, a animação volta para a corrida na hora.
- Transições mais longas (0,25–0,3 s) e ações em velocidade normal.
- Jogadores um pouco mais lentos e com giro mais suave (trote 3,2 m/s, sprint 4,8).

## Time
- Apoio inteligente: um companheiro abre **à frente no lado oposto** de quem
  conduz e o outro dá opção **na diagonal de trás**; os dois se mexem
  (desmarque). Nunca mais os dois juntos do mesmo lado.

## Câmera
- Sem árvores do lado da câmera (ela entrava na copa).

## Testes
- `dribble_test` ganhou bola atrás / atrás de lado / atrás longe.
