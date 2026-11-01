# Etapa 1 — Fundação jogável

## O que esta etapa entrega

- Projeto Godot 4.3 configurado para Android (paisagem, renderizador Mobile,
  compressão de textura ETC2/ASTC, multitoque).
- **Rua de bairro** gerada a partir das medidas reais: asfalto com rachaduras, manchas
  e remendos (shader procedural, sem texturas), calçadas com meio-fio, casas coloridas
  e gastas de um lado, muros baixos e casas recuadas do outro, postes, lixeira,
  tijolos, linhas de cal falhadas, sol de fim de tarde com sombras.
- **Traves de ferro** pequenas (2 m × 1,2 m), tinta branca descascada com ferrugem,
  **sem rede** (a bola passa e alguém tem que buscar), com colisão real nas barras.
- **Bola com física própria**: rola, quica, perde velocidade no asfalto, tem arrasto do
  ar e efeito (curva), bate no meio-fio, nos muros, nos postes e nas traves.
- **Condução por toques**: a bola nunca gruda. O jogador dá toques e corre atrás; a
  distância varia com a velocidade (≈0,4 m a 1,9 m) e com um pouco de aleatoriedade;
  mudar de direção faz o próximo toque sair na nova direção; se a bola escapa, perde a posse.
- Passe curto rasteiro, passe longo pelo alto, chute com força variável e imprecisão
  realista, domínio, desvio da bola no corpo, desarme, drible básico (corte/arrancada).
- **Regras**: saída de bola, gol, lateral, tiro de meta, placar. O `BallOutSystem` já
  tem a interface definitiva para a sequência de busca da bola (Etapa 6).
- **IA simples 3×3** com goleiro.
- **Câmera** elevada de transmissão (~40°), seguindo a jogada.
- **Controles de toque**: analógico flutuante, CHUTE, PASSE, DRIBLE, CORRER, TROCAR.

### Importante sobre a aparência dos jogadores nesta etapa

Os jogadores ainda são **manequins provisórios feitos de formas simples e parados**
(eles deslizam). Isso é de propósito: não vou simular animação mexendo partes por
código. A animação real (esqueleto humanoide + animações capturadas) é a Etapa 2.
Esta etapa serve para validar **física da bola, condução, controles, câmera, regras e IA**.

---

## Como abrir no celular Android (sem computador)

### 1. Instalar o Godot 4.3 para Android

- Baixe o APK oficial do editor **4.3**: site godotengine.org → *Download* →
  *Archive* → **4.3 stable** → arquivo `Godot_v4.3-stable_android_editor.apk`
  (para celulares comuns, versão arm64/“universal”).
- A versão da Play Store acompanha sempre a mais recente (4.4/4.5+). Ela também abre o
  projeto, mas converte arquivos; para seguir exatamente este projeto, prefira a 4.3.
- Ao abrir pela primeira vez, permita **acesso a todos os arquivos**.

### 2. Baixar o projeto

**Opção A — ZIP (mais simples):**
1. No navegador do celular, abra o repositório no GitHub, troque para a branch desta
   etapa e toque em **Code → Download ZIP**.
2. Extraia o ZIP (app *Arquivos* do Android ou **ZArchiver**, gratuito) em uma pasta
   como `Documentos/Godot/rua10/`. Dentro dela deve estar o `project.godot`.

**Opção B — Git (recomendado para as próximas etapas):** instale o app gratuito
**MGit**, clone o repositório e, a cada etapa, só toque em *Pull* para atualizar.

### 3. Importar e rodar

1. No Godot: **Importar** → navegue até a pasta → selecione `project.godot` →
   *Importar e Editar*.
2. A primeira importação leva alguns segundos (compila shaders).
3. Toque no botão **▶ (Rodar projeto)** no canto superior direito.

Se o celular for antigo e a tela ficar preta ou travar: *Projeto → Configurações do
Projeto → Renderização → Renderizador → Método de renderização* = `gl_compatibility`
(também em *Mobile*), salve e reinicie o editor.

---

## Controles

| Controle | Toque | Teclado (teste) | Controle BT |
|---|---|---|---|
| Mover | analógico (metade esquerda da tela, onde tocar) | WASD / setas | analógico esquerdo |
| Correr | segurar **CORRER** | Shift | RB |
| Passe | toque = curto rasteiro; segurar = longo pelo alto | J | A |
| Chute | segurar para mais força; soltar chuta | K | B |
| Desarme | **CHUTE** sem a bola, perto de quem conduz | K | B |
| Drible | **DRIBLE** + direção = corte/arrancada | L | X |
| Trocar jogador | **TROCAR** | Q | LB |

- Você joga pelo time **COM CAMISA**, atacando para a **direita**.
- O jogador controlado tem um **anel amarelo** no chão.
- Ao receber um passe, o controle passa automaticamente para quem recebeu.
- A direção do analógico no momento do chute define o canto; sem direção, ele mira
  no canto oposto ao goleiro.

---

## Checklist de teste (me diga o resultado de cada item)

1. O projeto abriu e rodou sem mensagens de erro no editor?
2. Quantos FPS aproximadamente? (*Depurador → Monitores → FPS*, ou só diga se está fluido)
3. Os botões e o analógico respondem bem, inclusive dois dedos ao mesmo tempo
   (correr + mover + chutar)?
4. A condução parece natural (bola indo e voltando do pé) ou a bola foge/demora demais?
5. Passes curtos chegam no companheiro? Passe longo sobe e cai perto dele?
6. O chute forte tem potência? A bola bate na trave/muro de forma convincente?
7. Saída lateral e tiro de meta acontecem certo?
8. A câmera está boa (altura, distância, inclinação) na tela do seu celular?
9. A IA marca, passa e chuta? Algum jogador fica parado/travado?
10. Algo te incomodou no visual da rua (cores, rachaduras, casas)?

---

## Ajustes rápidos sem programar

Selecione o nó no editor e altere no **Inspetor**:

- `Ball` → *Física*: `rolling_resistance` (bola mais "pesada"/mais rápida), `air_drag`.
- `Players` são criados por código; para mudar velocidades, abra `src/player/player.tscn`,
  selecione o nó raiz e altere *Movimento* (`jog_speed`, `sprint_speed`, `acceleration`...).
- `MatchCamera`: `height`, `distance`, `ball_weight`, `follow_speed`.
- `MatchManager` → `autoplay = true` para assistir IA × IA.
- `Street` → `seed_value` gera outra combinação de casas e cores.

---

## Testes automáticos (opcional, só com PC)

```
godot --headless --path . res://tests/autoplay_test.tscn --fixed-fps 60 -- --seed=1
godot --headless --path . res://tests/human_input_test.tscn --fixed-fps 60
```

Resultado de referência (4 min de IA × IA, 5 sementes): 3–8 gols, ~45 passes,
25–40 chutes, 8–21 desarmes, nenhuma bola fora do mundo, nenhuma bola parada sem dono
por mais de 1 s. Condução humana: bola entre 0,37 m e 0,65 m do jogador trotando.
