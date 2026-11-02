# Etapa 15 — Viradas novas, domínio correndo, condução para o lado

## Animações novas (Mixamo, enviadas)
| Clipe | Uso |
|---|---|
| Running Right Turn (+ espelhado) | CORTE correndo (~40°) com toque de lado do pé certo |
| Walking Turn 180 (+ espelhado) | inverter ANDANDO (180°), com a sola puxando a bola |
| Standing Cover Turn (+ espelhado) | GIRO parado (~55°) com a bola: a sola leva a bola até a frente da nova direção |
| Stop Walking | parada andando (sem bola) |
| Walking Left Turn, Jog Strafe L/R (1), Running Turn 180 (1), Running To Turn | importadas; "Running Turn 180 (1)" é igual à que já existia; "Running To Turn" (2,3 s) ficou de fora |

## Correções
- **Receber segurando CORRER**: a bola passava porque a velocidade relativa
  (bola + jogador correndo de frente) passava do limite de domínio (12 m/s) e
  o recebedor chegava atropelando. Agora o limite é 18 m/s, o recebedor chega
  controlado (≤ 2,2 m/s) quando a bola está a < 0,6 s, e o analógico durante a
  recepção só escolhe a direção do primeiro toque. Teste com CORRER + analógico:
  11/12, 9/12, 12/12 (antes 0–1/12).
- **Condução para o lado**: com a bola à frente e virada de 90°, ele "dava a
  volta" na bola pelo lado errado. Agora vai direto ao ponto atrás dela
  (acompanhando a velocidade da bola) e toca: tempo até o toque ~0,6–0,9 s
  (antes ~1,4 s).
- **Cavadinha / passe por cima**: barra cheia arrastando = bem mais alto.

## Pacote de mocap de futebol (Anderson Rohr, esqueleto UE5)
- 21 tomadas convertidas para o esqueleto humanoide (BoneMap UE5 → humanoide).
- Ficam FORA do repositório e do APK até a licença ser confirmada.
