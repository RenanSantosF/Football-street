# Etapa 22: condução por contato real do pé ("tapas")

## O que mudou
Antes, o jogo **agendava** cada toque: esperava o pé chegar num ponto
calculado e segurava o corpo esperando. Isso dava a bola colada, o jogador
"bugado" e toques que não saíam.

Agora o toque acontece quando o **pé da passada encosta de verdade na bola**.
- O pé (tornozelo até a ponta dos dedos, em 3D, da própria animação) precisa
  tocar a bola e estar indo na direção dela. Pé apoiado parado não toca;
  pé passando por cima não toca.
- Sem IK: a perna é sempre a da animação.
- Render dos quadros exatos de cada toque: o pé está na bola em todos.

## O tapa
- A cada contato, a bola sai na direção pedida, na velocidade da corrida mais
  um "tapa" que a leva à frente:
  - andando: ~0,1 m além do pé;
  - correndo: ~0,4 m;
  - sprint: ~0,6 m.
- A bola vai e volta entre ~0,3 e ~0,9 m à frente no trote, e ~1,0–1,4 m no
  sprint. O jogador corre **livre** atrás dela: não freia nem trava esperando
  o toque.
- O corpo se alinha com a bola (acompanha o deslize lateral dela), para a bola
  ficar na linha da passada.
- Bola "na grama": rola 1,25× menos com dono (antes 1,6×), para o tapa ir mais
  longe.

## Arrancada e mudança de direção
- **Arrancada com bola**: 90% da velocidade em ~0,2 s, igual a sem bola. Antes
  levava 0,35–2,3 s.
- **Toque de lado**: no próximo contato o pé manda a bola para o novo lado
  (até 70° por toque com o pé de fora; o outro pé só dá um toquinho de fora,
  até 28°). O corpo segue reto até esse toque e depois acompanha. ~0,2 s.
- **Inverter com a bola à frente**: um pique curto até a bola, pisa (puxada de
  sola) e volta: ~0,8 s. Antes, com a bola longe, 1,65 s.

## Testes
- Condução: todos os casos passam e o resultado é igual em toda rodada.
- Domínio: 12/12 em todas as variações. Recebendo em sprint, ele sai
  conduzindo com a bola até ~1,4 m à frente (o teste aceita até 1,7 m em
  movimento).
- Zigue-zague: 100% de posse.
