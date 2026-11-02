# Etapa 13 — Condução no padrão dos jogos de futebol

A arquitetura da Etapa 12 (bola "puxada" para o DribblePoint entre os toques,
toque `(alvo − bola) × 11`, bola levada ao KickPoint no chute) deixava a bola
flutuando/fugindo e a perna esticava demais. Voltamos ao padrão usado nos jogos
de futebol, mantendo o que a Etapa 12 trouxe de bom.

## Como os jogos fazem (e como ficou aqui)
1. **A bola é sempre física.** Entre os toques ela rola sozinha (atrito dos
   bloquinhos). Nada de "imã".
2. **O toque acontece na passada da animação.** Espera o pé da animação
   chegar a ~20 cm do ponto de contato; o toque manda a bola para onde o pé vai
   estar no próximo toque (no caminho do pé: ~0,36 m à frente).
3. **Quem se ajusta é o CORPO.** O jogador acelera/freia para a passada chegar
   na bola, não "atropela" a bola, contorna para ficar atrás dela antes de
   mudar de direção, e anda até ela para pisar.
4. **IK só de poucos centímetros.** A correção da perna é pequena (até ~16 cm
   cheia, some aos ~32 cm; um pouco mais devagar ou pisando na bola à frente) e
   nunca cruza a perna na frente do corpo. Se o pé não alcança de verdade, **o
   toque não acontece** (o corpo se ajusta e o toque sai na próxima passada).
5. **Chute:** o corpo vai até a bola na preparação (pé de apoio do lado dela) e
   o impacto é no quadro de contato do clipe.

## Mantido da Etapa 12
- PickupArea (domínio), `add_collision_exception_with` enquanto conduz,
  colisão real da bola solta com o corpo, rotação com inércia (`lerp_angle`
  11 / 6,5 com bola), rolamento de 18 rad/s no chute, 0,45 s sem dominar após chutar.
- Markers: DribblePoint agora a 0,30 m (onde o pé passa), KickPoint/KickPointLeft.

## Alcance real
- Medido na animação: o tornozelo vai só ~0,14 m à frente do corpo na passada
  com bola; a perna alcança ~0,4–0,45 m no chão. A lógica usa esses números.

## Testes
- `contact_test`: todos os toques aplicados com o pé na bola (10/10, 15/15);
  os que o pé não alcançaria são cancelados.
- `dribble_test`: parar, inverter, virar com a bola longe, chacoalhar, passe
  para trás, bola atrás — todos passam.
