# Etapa 25: biomecânica, pés sem deformação, disputas físicas e passe em profundidade

Tudo da Etapa 24 (condução automática, contato corpo a corpo, locomoção com
inércia) foi mantido. Cada mudança foi conferida em imagem (laboratório
visual com renderização real) e nos testes automáticos.

## 1. Deformação dos pés: causa encontrada e corrigida
Medição no rig (`rest × bind` por osso):
- O importador do Godot (retarget com *fix silhouette*) gira o descanso de
  alguns ossos para casar com o perfil humanoide **sem mexer no bind da
  malha**: braços 54–83° (A-Pose → T-Pose) e **pés/dedos 29,7°**.
- `HumanoidCharacter._fix_arm_binds` "assava" essa diferença nos vértices
  **só dos braços**, mas trocava o bind de **todos** os ossos. Nos pés isso
  girava a malha ~30° em relação à canela: pé "na ponta", tornozelo
  esticado/torcido na corrida.
- O remendo antigo (`_level_foot_and_toes`, que forçava o pé sempre
  horizontal) escondia parte do problema e matava o rolamento natural do pé
  (no balanço para trás o pé ficava "em gancho").

Correção:
- O ajuste de silhueta é assado nos vértices de **todos** os ossos — o
  resultado é matematicamente idêntico à pele original do importador em
  qualquer pose (`pose × rest⁻¹ × (rest × bind × v) = pose × bind × v`).
- Sem nivelamento forçado: o pé segue a animação (apoia, rola, aponta no
  balanço).
- Apoio pela **sola de verdade**: calcanhar, meio e ponta do pé são extraídos
  da malha original (`_extract_sole_points`) e ancoram o corpo no chão (antes
  era uma altura fixa de tornozelo, que fazia o pé flutuar).
- Na fase de apoio, em velocidades baixas/médias, o calcanhar acomoda no chão
  (os clipes de trote pisam só com o antepé); no sprint o antepé é o natural.
- Contato de chapa/amortecer: o giro do pé sai do **quadril** (rotação
  externa da perna inteira, 24–30°); o tornozelo só completa (antes 22° de
  torção só no tornozelo).

## 2. Inclinação biomecânica (corpo inteiro)
`LeanModifier._apply_body_lean`: o corpo inteiro pende para a direção da
**aceleração real** (`atan(a/g)`, 42% do valor físico, teto de 11°), girando
em torno do apoio no chão:
- curva = inclina para dentro (medido: cabeça até 0,32 m para dentro numa
  curva em sprint); freada = para trás; arrancada = para a frente;
- a cabeça compensa 60% (olhar mais nivelado), o pé apoiado acompanha o chão
  (tornozelo), o braço de fora da curva abre um pouco;
- o tronco ficou com só um resto pequeno de inclinação própria (sem torção).

## 3. Inércia e desequilíbrio
- Mudança brusca em velocidade tira equilíbrio na proporção de
  `(velocidade − 2,2) × severidade da curva` (inverter em sprint: equilíbrio
  cai para ~0,6); viradas animadas em velocidade também custam equilíbrio.
- Muito brusco = **quase queda** (tropeço curto, a bola pode escapar).
- Desequilibrado: acelera e corta menos, o corpo pende para onde estava indo,
  os braços abrem para segurar.
- Passes e chutes desequilibrados saem **mais fracos e mais tortos**.
- Recuperação progressiva (parado/andando mais rápida que correndo).

## 4. Desarmes e interceptações físicos (sem roubada "mágica")
- **Bote em pé**: escolhe a perna do lado da bola (clipe espelhado para a
  esquerda), o corpo avança até o ponto de apoio ao lado da bola e a perna
  estica (IK). O contato é **geométrico**: quando o pé encontra a bola no
  balanço, o toque acontece ali.
- Resultado decidido pela física do contato:
  - pé na bola exposta perto → **roubada com a parte de dentro** (a bola vem
    para o pé de quem desarmou, que sai conduzindo);
  - pé na bola mais longe → **cutucada** (desvia para o lado da perna);
  - os dois pés na bola → **dividida** (a bola espirra, os dois perdem
    equilíbrio);
  - corpo de quem conduz no caminho (protegendo) → o pé bate na perna dele:
    sem roubada, falta se for por trás;
  - pé não alcançou → **errou**: perde equilíbrio na proporção do avanço
    (avanço longo = tropeço).
- Tempo de contato do clipe "Soccer Tackle" corrigido (extensão máxima
  medida ≈ 0,18 s; o catálogo dizia 0,25 s).
- **Interceptação**: passe/chute do adversário passando a 0,5–0,95 m — o
  jogador estica a perna; bola mansa = amortece e fica, bola forte = desvia.
- **Botão DESARME sem adversário com a bola**: estica a perna na bola solta.

## 5. Proteção da bola e disputa
- Botão **PROTEGER** (aparece só com a bola no pé; tecla G; gatilho esquerdo
  do controle): passos curtos, costas/lado para o marcador, bola do lado de
  longe (sola), base mais aberta e quadril mais baixo (IK das pernas), massa
  efetiva maior no contato (aguenta empurrões).
- Proteção automática mais leve quando parado com marcador colado.
- IA com a bola protege por pouco tempo e depois toca ou sai girando.
- IA defensora: ataca a **bola** pelo lado em que ela está exposta (troca de
  lado se o corpo do atacante fecha), dá o bote só com **linha limpa** até a
  bola e no momento em que ela fica exposta (logo após um toque); cada
  defensor tem agressividade própria.

## 6. Passe em profundidade (botão PROFUNDIDADE)
- Botão novo (tecla H; botão Y do controle). Segurar = mais força = mais
  longe à frente do companheiro (3 a 8,5 m).
- A bola vai para o **espaço** onde o companheiro vai estar (direção da
  corrida dele ou rumo ao gol), com a velocidade calculada para os dois
  chegarem juntos (ainda rolando). Arrastar não é preciso; seta **verde** e
  mais comprida durante a mira (o passe normal é azul/branco).
- Toque firme de parte de dentro com o clipe do passe longo (pé esquerdo =
  espelhado), sincronizado com o contato.
- Quem recebe segue correndo até o ponto de encontro (não volta para buscar).
- A IA também usa quando um companheiro arranca com espaço.

## 7. Variedade e naturalidade
- Estilo individual por jogador (amplitude do balanço dos braços, postura do
  tronco).
- Chute colocado às vezes com outro gesto (peito de pé, "Kick Soccerball").
- Botes com perna direita/esquerda, roubada × cutucada × dividida,
  interceptação esticando a perna, tropeços de quase queda.

## 8. Pesquisa de animações
- *Universal Animation Library 2* (Quaternius, CC0): sem animações de futebol
  (combate, parkour, fazenda...).
- Pacotes de esportes da Rokoko (esqueleto Mixamo, uso comercial liberado) e
  da Xsens: exigem conta para baixar — não foi possível incorporar daqui.
- Clipes ainda não usados do pack de 76 FBX foram **avaliados no esqueleto**
  (`tests/clip_viewer.tscn`): "Soccer Tackle (1)" é um mergulho (exagerado
  para bote em pé), "Stand Up (1)" tem um salto, "Receive Soccerball" tem
  deslocamento no quadril, "Dribble" (≈ 2,8 m/s) foi testado na condução mas
  o pé dele empurrava a bola nas viradas — nenhum entrou.

## Testes
- Novo `duel_test` (no CI): bote em bola exposta tira a bola pelo pé; bote em
  quem protege não rouba; bote de longe erra e desequilibra; PROTEGER segura a
  bola 3 s contra a IA com a bola sempre do lado de longe; interceptação;
  passe em profundidade cruza a linha de corrida ~6 m à frente e é dominado;
  inverter em sprint desequilibra.
- `dribble`, `contact`, `receive`, `body_contact`, `rules`, `aerial`,
  `human_input`, `gameplay`, `autoplay`: sem erro de script.
- Ferramentas novas (precisam de tela; no servidor use Xvfb):
  `tests/visual_lab.tscn` (cenários reais com câmera de perto, folhas de
  contato) e `tests/clip_viewer.tscn` (confere clipes no esqueleto).
