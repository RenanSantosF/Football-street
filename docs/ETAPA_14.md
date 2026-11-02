# Etapa 14 — Passos, condução, virada com a sola e domínio

## Bugs encontrados (reproduzidos em teste)
- **Bola "morrendo" embaixo do jogador na corrida**: tinha ficado um
  `linear_damp = 2` na bola enquanto conduzia (da arquitetura da Etapa 12).
  A bola freava forte entre os toques, o jogador passava por cima e a
  velocidade ficava oscilando ("corrida bugada"). Removido.
- **Andar devagar travado (~0,87 m/s) e passo arrastado**: um limitador
  segurava o corpo e a animação misturava "parado" com "andando".
- **Parar correndo**: tentava pisar na bola ainda rápido (a sola não
  alcança) e a bola fugia.
- **Virar pouco o analógico parado**: a sola ficava "presa" na bola de uma
  parada anterior e nada acontecia.
- **Domínio que deixava passar**: a posse era tomada antes do pé encostar; se o
  pé não alcançava, a bola atravessava o jogador.

## Como ficou
- **Passos**: a velocidade que alimenta a animação muda suave; devagar usa a
  CAMINHADA inteira mais lenta (TimeScale) em vez de misturar com "parado";
  troca parado ↔ andando com mistura de ~0,2 s; a correção da perna (IK) entra
  e sai suave, cada perna com seu peso (nada de pé "teleportando"). Giro do
  corpo mais lento (8 sem bola / 5 com bola).
- **Corrida com a bola**: bola 0,35–0,65 m à frente, velocidade constante.
- **Parar**: soltou o analógico correndo → freia CONDUZINDO (toques curtos
  que tiram ~1,8 m/s da bola, o corpo acompanha ~0,3 m atrás dela) e pisa na
  bola quando já está devagar.
- **Virada com a sola**: parado/devagar e o analógico vai para outro lado
  (mesmo pouco, ≥ 25°) → a sola pisa na bola e a arrasta enquanto o corpo gira,
  com passos curtos; depois segue conduzindo na nova direção.
- **Domínio**: o jogador só fica com a bola quando o pé encosta nela (amortece
  com a parte de dentro do pé ou pisa). Se o pé não alcançar, a bola bate no
  corpo de verdade (não atravessa) e ele tenta de novo.

## Testes
- `receive_test` (novo): 12 passes de frente, de lado, de trás, fracos e
  fortes → 12/12 dominados.
- `dribble_test`: + virada leve com a sola.
- `contact_test`: toques aplicados com o pé na bola 16/16, 14/15.
