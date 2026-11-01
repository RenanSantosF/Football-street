# Etapa 6 — Animação e movimentação, controles, condução, fundo e desempenho

## Animação
- **Braços "para trás" corrigidos**: as animações "sem skin" do Mixamo vêm em
  pose T e o personagem com skin em pose A; a diferença (~45°) ia para os
  braços na conversão. Agora a importação usa **Fix Silhouette**, que normaliza
  as duas poses antes do retarget (vale para corrida, condução, chutes...).
- **Levantar do chão** com as animações enviadas: "Standing Up" (de bruços,
  depois do tropeço) e "Stand Up" (de costas, depois do carrinho), usando só o
  trecho em que ele levanta, levemente acelerado.
- **Sem tremer**: marcação com margem (entra a 5 m, sai a 6,2 m) e tempo mínimo
  em cada modo; girar parado dá passinhos.

## Condução (refeita)
Controle próximo: cada toque é calculado para a bola chegar de novo ao pé no
próximo passo (velocidade buscada + atrito do piso). Bola entre ~0,3 e 0,56 m;
zigue-zague com **100% de posse**. Virar para o lado oposto: vai até a bola,
puxa com a sola e sai.

## Regras
- Na saída, lateral, escanteio e tiro de meta **só o batedor toca na bola**
  até o passe sair (antes um companheiro da IA podia pegar e você saía andando).
- **Não troca de jogador com a bola no pé.**

## Controles
| Botão | Com a bola | Sem a bola |
|---|---|---|
| Vermelho | CHUTE (segure + analógico = mira; **arraste = cavadinha**) | CARRINHO |
| Azul | PASSE (segure = mais forte; **arraste = por cima**) | TROCAR jogador |
| Amarelo | DRIBLE (giro) | DESARME |
| Verde | CORRER | CORRER |
- **Anel de força** em volta do botão enquanto segura.
- Pequena preparação antes do toque (0,2 s no passe curto, 0,28 s no longo).
- **Seta de mira** visível (antes ficava invisível de cima).
- Botões redesenhados; minimapa **embaixo no meio**; **FPS** no canto; dica
  dos gestos no começo da partida; marca do time vira um anel fino e discreto.

## Ferramentas (botão ⚙)
Movimento (gráfico de velocidade e distância da bola, animação atual, toques/s,
câmera lenta), Controle (analógico, botões, atraso aperto→ação), Personagem
(ajuste ao vivo de velocidades/aceleração/giro + laboratórios) e Mundo (hora do
dia, sol, câmera, resolução 3D, sombras, pedestres). Ajustes salvos no celular.

## Visual
- **Bola de futebol** de verdade (12 pentágonos pretos + 20 hexágonos brancos).
- **Casas no fundo**: reboco pintado e desbotado, telhado de barro, janelas com
  grade e vidro, caixa d'água azul, segundo andar de tijolo à mostra, varais.
- Muro de tijolo aparente, quintais verdes, arbustos junto das cercas.

## Desempenho
Chão de bloquinhos com 4 ruídos por pixel (antes ~13), superfícies sem cálculo
de rachadura onde não há, copas sem sombra, resolução 3D 85%, sem glow, sombra
mais curta e em 16 bits, 2 pedestres.
