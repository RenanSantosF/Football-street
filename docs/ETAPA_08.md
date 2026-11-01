# Etapa 8 — Jogabilidade: passe, recepção, modos, saída de bola

## Passe
- **Bola sai firme e reta**: passe rasteiro sai a 8,5–11 m/s (antes ~5 m/s e
  "mascando"). Mesmo o toque fraco chega rápido no companheiro.
- **Precisão**: erro máximo de 0,6° (toque) a 1,8° (passe forte).
- **Sem direção no analógico** o passe vai no companheiro mais fácil (nunca no
  vazio — antes a saída de bola entregava a bola ao adversário).
- **Em profundidade**: analógico apontando para o espaço vazio → a bola vai para
  o espaço e corre quem chega primeiro.
- **Barra de força** acima dos botões: enche enquanto você segura PASSE ou
  CHUTE (cheia em 0,6 s).

## Recepção automática
- Passe direto: o recebedor espera parado ou dá um passo ao encontro da bola.
- Passe em profundidade: o recebedor corre já para o ponto onde a bola vai
  estar (prevê a desaceleração da bola nos bloquinhos).
- O controle muda para o recebedor no momento do toque. Se você mexer o
  analógico, assume na hora.

## Dois modos (botão **MODO** no canto superior esquerdo)
- **TREINO**: só o seu time em campo (treinar condução, passe e chute). Todo
  reinício (lateral, escanteio, saída) fica com o seu time.
- **PARTIDA**: com adversários.
- O modo escolhido fica salvo para a próxima vez.

## Saída de bola e formação
- Os dois times se posicionam na formação padrão (fixo atrás + duas alas).
- Até a saída ser tocada ninguém do outro time entra no seu campo: eles ficam
  com animações aleatórias de espera (respirar, reclamar, aquecer, embaixadinha)
  ou andam pouquinho perto da posição.

## Condução e buscar
- Correção lateral suave entre os toques: a bola não "escapa" para o lado
  quando você muda um pouco a direção.
- BUSCAR: corre para interceptar a bola (prevê onde ela vai estar); se o
  adversário está com ela, se posiciona entre ele e o seu gol e diminui o
  passo ao chegar perto.

## Visual
- Adversários com pele clara (provisório, só para diferenciar os times).

## Testes (PC/servidor)
- `tests/gameplay_test.tscn`: saída (adversário espera), velocidade do passe,
  controle muda para o recebedor, recebedor domina, profundidade, modo treino.
- `tests/rules_test.tscn`, `tests/human_input_test.tscn`, `tests/autoplay_test.tscn`.
