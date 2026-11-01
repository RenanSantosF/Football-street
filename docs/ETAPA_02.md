# Etapa 2 — Personagem humanoide e pipeline de animação

## O que mudou no jogo

- Os manequins foram substituídos por **personagens humanoides animados** com
  animações de **captura de movimento** (parado, andando, trotando, correndo e
  desequilíbrio ao sofrer desarme).
- **Sem deslizar**: a velocidade real do corpo escolhe e mistura os clipes
  (BlendSpace1D), e a passada é ajustada ao tamanho de cada personagem.
- **Diversidade**: tom de pele (7 tons), cabelo (curto repartido, raspado, comprido),
  cor de cabelo, camiseta, bermuda, tênis, meia, sujeira e altura variam por jogador.
- Time **com camisa** × time **sem camisa**; goleiro do time com camisa usa camisa escura.
- Tudo a partir de **um único corpo base e um único esqueleto**.

> Chutes e passes ainda acontecem sem o movimento de chute: os clipes de futebol
> entram na Etapa 3. A estrutura já está pronta para recebê-los.

## Como funciona (arquitetura)

```
assets/animations/ual/*.gltf ──┐   (esqueleto Rigify: DEF-hips, DEF-spine...)
assets/characters/base/*.gltf ─┼── retarget na importação ──► SkeletonProfileHumanoid
assets/characters/hair/*.gltf ─┘   (esqueleto Unreal: pelvis, spine_01...)      (Hips, Spine, Head...)
                                                                                    │
AnimationCatalog  ── bibliotecas por prefixo ("ual/") + nomes lógicos ("jog") ◄─────┘
AnimationTreeBuilder ── monta a StateMachine (Locomotion, LocomotionBall, Stumble, Fall)
ClothingMeshBaker ── máscaras de roupa nas cores de vértice (pose de repouso)
character_skin.gdshader ── pele (qualquer tom) + camiseta/bermuda/meia/tênis + sujeira
HumanoidCharacter ── junta tudo; é o nó "Visual" do jogador
PlayerAnimationController ── velocidade real → BlendSpace; ações → estados
```

Os dois modelos têm **esqueletos com nomes diferentes**, e o retarget do Godot
converte ambos para o perfil humanoide padrão. É exatamente o mesmo caminho que as
animações do Mixamo vão seguir na Etapa 3.

### Arquivos novos

| Arquivo | Função |
|---|---|
| `src/character/humanoid_character.gd` | monta o personagem (corpo, cabelo, roupa, proporções, AnimationTree) |
| `src/character/animation_catalog.gd` | bibliotecas de animação e nomes lógicos dos clipes |
| `src/character/animation_tree_builder.gd` | constrói a máquina de estados de animação por código |
| `src/character/clothing_mesh_baker.gd` | gera as máscaras de roupa |
| `src/shaders/character_skin.gdshader` | pele + roupa |
| `tests/character_lab.tscn` | laboratório: 6 adolescentes em velocidades diferentes |
| `tools/gen_imports.py` | gera os `.import` com o mapa de ossos (só para PC) |
| `assets/...` | modelos e animações CC0 (ver `CREDITS.md`) |

### Velocidades das passadas (medidas pelo pé apoiado, corpo em tamanho original)

| Clipe | Velocidade natural |
|---|---|
| Idle | 0 |
| Walk | 1,05 m/s |
| Jog_Fwd | 5,2 m/s |
| Sprint | 6,8 m/s |

## Como atualizar no celular

- **MGit**: abra o repositório → *Pull*.
- **ZIP**: baixe de novo a branch e substitua a pasta (pode apagar a antiga).

Ao abrir, o Godot importa os modelos novos (pode levar até 1–2 minutos na
primeira vez). Se aparecer algum aviso de importação, feche e abra o projeto de novo.

## Testar

1. **Laboratório**: no painel *Sistema de Arquivos*, abra `tests/character_lab.tscn`
   e toque em **Rodar cena atual** (ícone de claquete ▶). Você verá 6 adolescentes:
   parado, andando, trotando, correndo forte e um com reação de desequilíbrio.
2. **Jogo**: ▶ normal. Jogue uns minutos.

### Checklist

1. O projeto importou sem erros?
2. FPS no jogo comparado com a Etapa 1 (está fluido?)
3. Os pés deslizam no chão ao andar/trotar/correr? Em qual velocidade fica pior?
4. A transição parado → andar → correr está natural?
5. Aparência: os personagens parecem adolescentes? Algo estranho (roupa, pele, cabelo)?
6. No laboratório, a reação de desequilíbrio (último à direita) está boa?

## Limitação conhecida: o corpo base

O único corpo humanoide gratuito, CC0 e compatível que encontrei com qualidade
"estilizado realista" é adulto e atlético. Já apliquei: escala de 1,81 m → ~1,66 m,
cabeça proporcionalmente maior, tronco e ombros mais estreitos e relevo muscular
atenuado. O porte ainda é atlético.

A arquitetura permite **trocar o corpo base mudando uma linha**
(`HumanoidCharacter.BASE_MODEL`), mantendo animações, roupas e o resto.
Opções para um corpo realmente juvenil, a decidir:
- Um modelo humanoide jovem do **Mixamo** (gratuito com conta Adobe, já vem
  com esqueleto). O retarget aceita o esqueleto do Mixamo.
- Um corpo base adolescente feito sob medida (MakeHuman/MPFB, gratuitos, exigem
  computador; posso preparar os parâmetros).

## Preparando a Etapa 3 (animações de futebol)

A Etapa 3 usa animações do **Mixamo** (mixamo.com, gratuito, conta Adobe gratuita).
No celular, abra no Chrome em modo **"Site para computador"**. Para cada animação:
**Download → Format: FBX Binary · Skin: Without Skin · Frames per Second: 30 ·
Keyframe Reduction: none**. Para clipes de locomoção, marque **In Place**.

Na Etapa 3 eu vou te passar a lista exata (nomes de busca e arquivos) e os
`.import` prontos com o mapa de ossos do Mixamo, para você só copiar os arquivos
para `assets/animations/mixamo/`.
