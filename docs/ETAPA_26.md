# Etapa 26: refinamentos (passe, reinícios, carrinho, condução, proteção, faltas)

Regra principal desta etapa: **não estragar o que já funciona**. Nada foi
reconstruído. Cada item começou por uma auditoria do código existente e
virou uma correção localizada. Depois de cada grupo rodou a suíte inteira de
testes (com zero erros de script). Tudo das Etapas 24 e 25 (condução híbrida,
contato corpo a corpo, pés sem deformação, inclinação, desarme pelo contato)
continua igual.

Testes novos:
- `tests/pass_contact_test`: passe andando, correndo, em curva, mudando de
  direção e desacelerando (6 repetições de cada).
- `tests/refine_test`: cobrança imóvel, tropeço sem giro, alcance do
  carrinho, falta (escurecer + barreira) e força do passe simples.
- `tests/curve_jitter_test`: trepidação da bola na condução em curvas, com a
  origem de cada mudança brusca.

`refine` e `pass_contact` também rodam no GitHub Actions antes de exportar o
APK.

## 1. Passe que "não pegava" na bola em movimento
**Causa:** o contato do chute acontecia num instante fixo do clipe. Em
corrida, curva ou freada a bola já tinha andado, e o pé fechava no ar. Além
disso:
- o "pé passivo" (que evita o pé atravessar a bola) empurrava a bola para
  longe justamente durante o preparo do chute;
- `can_kick()` reprovava a bola que estava encostada no pé de chute, mas um
  pouco além do alcance estático.

**Correção:**
- Nos chutes **em movimento**, o contato só acontece quando o pé efetivo
  (tornozelo + correção do IK, limitada a 0,3 m) está a ≤ 0,27 m da bola. O
  contato pode antecipar (até 60% do tempo previsto) ou esperar um pouco
  (`MAX_CONTACT_WAIT`). Chutes parados mantêm o tempo original, para não
  atrasar o chute mirado.
- No preparo, o jogador **prevê a bola**: fecha a distância pelo tempo que
  falta até o contato e acompanha a velocidade lateral dela. Não há ímã nem
  teletransporte.
- `can_kick_now()`: aceita a bola tocando o pé de chute.
- Se mesmo assim a bola fugiu (pé a mais de 0,34 m), o chute é abortado
  **uma vez** e o pedido fica guardado por 0,6 s, para sair no passo
  seguinte (antes saía um chute no vazio).
- O pé passivo não empurra durante o preparo do chute, e o empurrão dele
  ficou mais suave.

Medido (`pass_contact_test`): **30/30 passes saíram com o pé na bola**
(distância pé-bola no contato entre 0,04 e 0,24 m) nos 5 cenários.

## 2. Imobilidade real nas cobranças
**Causa:** `_restart_orbit` deixava o analógico girar o batedor em volta da
bola (rotação de 360°) e o deslocava.

**Correção:** o batedor fica freado no lugar e não gira pelo analógico
(`_restart_hold`). A animação de espera continua. O controle volta quando a
cobrança começa (o chute/passe sai normalmente).

Medido: analógico dando voltas completas por 2 s → **0,00 m de deslocamento
e 0° de giro**.

## 3. Passe curto com animação própria
**Causa:** todo passe usava o mesmo clipe, só variando a força.

**Correção:**
- `touch_pass`: passe curto **em corrida**. Toque rápido de parte interna,
  sem parar a corrida. O pé abre na diagonal (corpo gira só 25°, braços
  quase parados: `LeanModifier`). O contato é adaptativo.
- `run_pass`: passe forte em corrida.
- `firm_pass`: passe parado com força ≥ 0,6. Usa o clipe de passe longo (mais
  balanço da perna).
- Passe leve parado: continua o clipe curto original.

Os chutes (normal, forte, cavadinha) não mudaram.

## 4. Falta: transição pela tela escura
**Correção:** novo sinal `GameEvents.screen_fade`. Ao marcar a falta, a tela
escurece (0,18 s), o reposicionamento acontece com a tela preta (0,08 s) e
ela clareia (0,25 s). O retângulo preto fica na `MobileUI`.

Medido: o escurecimento começa antes do reposicionamento (no máximo 14
quadros antes).

## 5. Defesa organizada na falta
**Causa:** nas faltas, o código só afastava quem estava a menos de 3 m da
bola. Os defensores ficavam onde estavam, muitas vezes atrás da bola ou
longe do gol.

**Correção:** `MatchManager._setup_free_kick_defense` só é chamado na falta.
Os outros reinícios usam o código antigo.
- **Barreira** a 3,2 m na linha bola→gol: 2 jogadores perto do gol, 1 longe.
- Quem sobra cobre a região do gol na linha da bola ou marca o atacante mais
  perigoso, pelo lado do gol.
- Espaço mínimo entre defensores: 0,7 m na barreira e 1,4 m nos demais.
- Cada defensor vai para a posição mais próxima dele.
- As posições ficam guardadas (`restart_slot`) e a IA fica nelas até a
  cobrança. Depois volta ao normal.
- Os atacantes não ficam colados na barreira nem em cima da bola.

Medido: toda a defesa entre a bola e o gol, barreira a ~3 m, separação
mínima de 0,77 m, defesa parada até a cobrança.

## 6. Trepidação da condução em curvas
**Causa:** nas curvas, o corpo e o pé passivo empurravam a bola com
correções grandes, quadro a quadro, por cima dos toques programados.

**Correção:** os empurrões ficaram limitados:
- corpo: até 0,3 m/s por quadro quando a bola não está colada;
- pé passivo: proporcional e com teto.

O posicionamento da bola continua pelos toques e pela assistência (que já
eram suaves).

Medido em 7,5 s de curvas (90°, zigue-zague e círculo), sem perder a bola:
- a assistência e o pé passivo não causam nenhuma mudança brusca;
- o corpo causa 0,7 mudança brusca/s;
- quase todas as mudanças bruscas que sobram são os próprios toques do pé
  (4,0/s), que são o que deve mexer a bola;
- a distância bola-jogador salta (> 4,5 cm num quadro) só 0,3 vez/s.

## 7. Recuperação do carrinho
**Causa:**
- Se o carrinho começava durante a **arrancada** (`Burst`), o controlador de
  animação mandava de volta para a locomoção e atropelava a transição. O
  jogador deslizava em pé, sem o clipe, e não havia o "levantar".
- A viagem até o clipe da ação passava pela locomoção, e o controlador
  zerava a ação nesse meio-tempo.

**Correção:**
- A arrancada só volta para a locomoção quando o jogador está em
  movimento livre (`MOVE`).
- Enquanto a viagem para o clipe da ação está em andamento, nada a
  interrompe.
- Há transições diretas Arrancada → cada ação.

O carrinho termina levantando (como já estava previsto). O controle volta só
no fim da ação.

## 8. Proteção automática (sem botão)
**Correção:**
- O botão e a tecla de proteção foram removidos.
- A proteção liga sozinha quando:
  - quem tem a bola não está em sprint;
  - está devagar (≤ 1,6 m/s) e com o analógico leve (≤ 0,6);
  - há um adversário a menos de 1,4 m.
- O corpo gira o mínimo necessário (até ~40°) para pôr o corpo entre o
  adversário e a bola. A base fica mais larga e o corpo, mais firme no
  choque (massa efetiva ×1,3).
- Ela **não** protege quem vem pela frente: com o adversário à frente
  (`facing·dir > 0,5`), a proteção não liga.
- Mesmo protegido, há chance real de perder a bola. Pelas costas, o bote
  passa pelo corpo em 30–55% das vezes. De frente, a IA tenta o desarme com
  32% de chance.

## 9. Analógico travado nas ações comprometidas
- **Tropeço / desequilíbrio:** o analógico não gira o corpo (antes girava
  mesmo cambaleando). Medido: 0° de giro.
- **Cobranças:** ver item 2.
- **Carrinho, chute, passe, bote, levantar:** já seguiam a direção da ação.
  Com o item 7, o clipe certo toca do começo ao fim.

O movimento continua livre fora dessas ações (sem travamento excessivo).

## 10. Alcance do carrinho pela velocidade de entrada
O alcance do deslocamento do carrinho é multiplicado por
`clamp(v_entrada / 3,6, 0,35, 1,12)`. Em sprint (> 3,8 m/s) a recuperação
demora um pouco mais e o equilíbrio cai 0,3.

Medido (deslocamento total do jogador):
- andando: 1,25 m;
- em sprint: 4,14 m.

## 11. Passe simples mais firme
**Causa:** a velocidade do passe rasteiro era calculada para a bola
**chegar parando** no colega. Em passes curtos ela saía lenta e era
interceptada.

**Correção:** a velocidade de chegada no passe rasteiro subiu para 4,6–6,4
m/s, e a velocidade mínima de saída para 8,0–13,5 m/s (conforme a força). A
diferença entre passe curto, forte e em profundidade continua.

Medido: passe simples (toque rápido) a 6 m e a 12 m saem a 8,1 m/s, e o
colega domina nos dois.

## 12. Espaçamento entre companheiros
**Causa:**
- Na defesa, vários jogadores marcavam o mesmo atacante.
- No apoio, a separação considerava só a posição atual dos colegas, não
  para onde eles estavam indo.

**Correção:**
- Marcações distintas: quem pressiona é o mais perto de quem conduz. Os
  outros recebem os atacantes por ordem de perigo (distância ao gol).
- A separação considera a posição dos colegas **e o destino** deles.
- O apoio também se afasta dos colegas antes de escolher o lugar.

A tática (formação, pressão, apoio, tabela) não mudou.

Medido (`autoplay_test`): o tempo com jogadores do mesmo time aglomerados
caiu de 33–37% para 17–19%.

## 13. Deslizar sem animação
A causa é a mesma do item 7: a arrancada atropelava a transição para a
ação. Corrigida pelo mesmo ajuste.

## Arquivos alterados
- **Jogador:**
  - `src/player/player_controller.gd`: contato do passe, preparo,
    cobrança, tropeço, carrinho, proteção;
  - `src/player/ball_control.gd`: `can_kick_now`, pé passivo, corpo, passe
    rasteiro, proteção.
- **Animação:**
  - `src/player/player_animation_controller.gd`: arrancada e viagem até a
    ação;
  - `src/character/animation_tree_builder.gd`: Burst → ações;
  - `src/character/lean_modifier.gd`: postura do `touch_pass`.
- **IA:** `src/ai/ai_controller.gd`: marcações, separação, posições da falta.
- **Partida:**
  - `src/match/match_manager.gd`: defesa na falta;
  - `src/match/ball_out_system.gd`: escurecimento.
- **Interface e controles:**
  - `src/ui/mobile_ui.gd` e `.tscn`: tela escura, sem botão de proteção;
  - `src/player/human_input.gd` e `src/autoload/input_setup.gd`: sem tecla
    de proteção;
  - `src/autoload/game_events.gd`: sinal `screen_fade`.

## Limitações conhecidas
- **Inversão logo depois de um toque (já existia antes desta etapa):** se o
  analógico inverte 1 quadro depois de um toque de condução para a frente,
  a bola sai a ~3 m/s enquanto o jogador freia. A puxada de sola não
  alcança, e ele volta para buscá-la (~1,5 s). Isso depende do ponto da
  passada em que a inversão acontece:
  - `dribble_test` → `inverter_bola_na_frente`: ~20% das rodadas, igual no
    código da Etapa 25 (2 de 10);
  - `rules_test` → `bola_a_frente_na_nova_direcao`: mesmo cenário, 3 de 42.

  Não foi alterado aqui porque mexe no núcleo da condução. Fica para a
  próxima etapa.
- `virada_leve_puxou_com_sola` já dava `false` antes desta etapa
  (inalterado).
- Validação feita por testes automáticos e capturas renderizadas, sem
  aparelho Android.
