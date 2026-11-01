# Etapa 11 — Pé na bola (IK) e correções de animação

## O pé encosta na bola em todo toque
- Cada toque é **agendado**: a perna vai até a bola (IK de perna — quadril →
  tornozelo — misturada por cima da animação só no instante do toque) e a bola
  só muda de velocidade **no quadro em que o pé encosta**. Depois a perna volta
  suave para a animação.
- Vale para: condução (parte de dentro/peito do pé atrás da bola), toque de
  lado (o pé do lado certo), puxada de sola, parar a bola (sola em cima),
  virada com a bola, giro, primeiro toque e o pé do chute/passe.
- Saiu a "assistência" que mexia a bola sem toque: a bola só se move por contato.
- Toque agendado que perdeu sentido (bola com outro jogador, virada começou,
  reinício) é cancelado — não dispara mais sozinho.
- Teste `tests/contact_test.tscn`: mede a distância tornozelo → centro da bola
  no contato (pé na bola ≈ 0,12–0,22 m). Resultado típico: 17/17, 14/15.

## Domínio
- Primeiro toque com o pé: na maioria das vezes **parte de dentro do pé, do
  lado**, amortecendo (a bola fica perto); parado com bola mansa, às vezes pisa.

## Animações
- Corrigida a pose congelada da **arrancada** ("Idle To Sprint"): ao apertar
  CORRER parado, no fim do clipe o jogador ficava preso no último quadro
  "desfilando"/deslizando. Agora volta para a corrida no fim do clipe (e não
  usa a arrancada com a bola).

## Chute e passe
- Chute segurando: 12 a 23 m/s, baixo (quase sem quicar).
- Passe rasteiro segurando: 10 a 18 m/s.

## IA do meu time
- Não vai mais "roubar" a bola do jogador que você controla: só corre atrás de
  bola livre se estiver bem mais perto que você; senão se posiciona para receber.
