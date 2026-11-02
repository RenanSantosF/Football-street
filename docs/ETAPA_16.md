# Etapa 16 — Controle de bola: viradas, inversão, domínio, pé natural

## Correções
- **Pé contorcido**: a correção da perna (IK) agora mantém a ROTAÇÃO do pé
  igual à da animação (só a posição é ajustada) e corrige menos.
- **Pé alto ao dominar**: a pisada na bola ("Stall Soccerball", que levanta o
  pé) só com bola chegando bem mansa; no resto, parte de dentro do pé. Ao parar
  a bola não toca mais essa animação. Área de domínio um pouco maior.
- **Virada de um lado para o outro lenta**: o toque de lado não espera mais a
  próxima passada — o pé estica para o lado da bola na hora (IK um pouco maior
  só para esse toque). Tempo até o toque: ~0,15–0,35 s (antes 0,6–1,3 s).
  Um toque pendente para a direção antiga é cancelado assim que você vira.
- **Correndo e virando para o lado oposto perdia a bola**: a virada de 180°
  correndo só acontece com a bola colada; senão ele freia pisando na bola com a
  sola (a perna estica à frente) e vira já devagar (Walking Turn 180) com a bola
  no pé.

## APK menor
- As animações do pack UE5 vinham com o boneco do autor junto: a importação
  agora pula a malha (de ~28 MB para ~1,3 MB nessas 3 animações).

## Pacote "Everyday Actions" (Anderson Rohr)
- Recebido; não tem nada de futebol (acordar, banho, passear com cachorro...).
  "Walk And Wave"/"Stretch Stand And Walk" podem servir para os pedestres depois.
