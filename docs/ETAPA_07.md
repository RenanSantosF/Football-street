# Etapa 7 — Animação natural (viradas, parada, domínio, chutes, espera)

## Animações novas (enviadas)
| Clipe | Uso |
|---|---|
| Breathing Idle | parado neutro (antes era o jogador brincando com a bola) |
| Walking | caminhada no mesmo estilo dos outros clipes |
| Running Turn 180 | virada de 180° correndo, puxando a bola junto |
| Left Turn / Right Turn | girar 90° parado |
| Run To Stop | parada brusca ao soltar o analógico correndo |
| Standing Arguing | reclamar (trechos aleatórios) |
| Start Walking | reservado |

Nas viradas o corpo gira pela própria animação; no fim do clipe a nova
direção é aplicada de uma vez (o clipe termina exatamente virado).

## Correções de movimento
- **"Pé levantado deslizando"**: era o clipe de domínio (sola na bola)
  disparando a cada virada com a bola e ficando preso enquanto corria. Agora o
  domínio só toca quase parado e sai na hora em que o jogador anda.
- **Toque de lado**: correndo com a bola e mudando de direção, o jogador leva a
  bola para o novo lado na hora (sem esperar o próximo passo).
- **Chutes e passes**: depois do contato o corpo segue o deslocamento do
  próprio clipe (antes o quadril ficava pregado e os pés deslizavam);
  contatos do passe longo e do chute forte ajustados.
- **Passe**: quem vai receber vem ao encontro da bola; se o passe é seu, o
  controle passa para o recebedor no toque; primeiro toque orientado para onde
  você empurra o analógico.
- Movimentos um pouco mais lentos (trote 3,5 m/s, sprint 5,2 m/s).
- Cada jogador começa num ponto diferente do ciclo das animações.

## Espera (tiro de meta, lateral, falta, gol)
Cada jogador escolhe sozinho: parado respirando, andar um pouco, reclamar,
aquecer, conversar ou fazer embaixadinha — sempre andando, nunca correndo.

## Botão BUSCAR (amarelo, sem a bola)
- **Segure**: o jogador corre sozinho para onde a bola vai estar.
- **Dois toques**: **bote** esticando o pé. Errou a bola e pegou o adversário:
  **FALTA** (ele tropeça/se desequilibra e o outro time bate, obrigado a tocar).

## Outros
- FPS limitado a 60.
- Bloquinhos menos perfeitos (fileiras onduladas, blocos tortos, juntas
  irregulares, blocos desnivelados).
- Anel do time mais fino e discreto.
- Painel ⚙ removido do jogo; ajustes antigos apagados (tudo no padrão).
