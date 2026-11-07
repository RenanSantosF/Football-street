# Créditos de assets

Todos os assets de terceiros usados no projeto são **CC0 (domínio público)**:
uso livre, inclusive comercial, sem obrigação de atribuição (creditamos mesmo assim).

| Asset | Autor | Licença | Pasta |
|---|---|---|---|
| Universal Animation Library (Standard) | Quaternius — quaternius.com | CC0 1.0 | `assets/animations/ual/` |

Apoie o autor: https://www.patreon.com/quaternius

## Mixamo (não incluído no repositório)

As animações de futebol vêm do **Soccer Game Pack** do Mixamo (Adobe), gratuitas
para uso em projetos por quem tem conta Adobe. Os arquivos brutos não são
redistribuídos aqui; ver `docs/ETAPA_03.md` para baixá-los.

## Personagem

Skin única do jogo: personagem adolescente criado pelo autor do projeto e rigado
no Mixamo (`assets/characters/teen_01/`, fora do repositório público).

## Animações de mocap de futebol — Anderson Rohr ("Free mocap pack 05: Soccer")
- https://andersonrohr.gumroad.com/l/mocap_pack5 — uso livre em projetos pessoais e
  comerciais; não pode ser redistribuído/revendido como produto avulso. Por isso os
  FBX NÃO estão neste repositório (só os .import); entram embutidos no jogo.
- Usadas: Side Foot Kick (passe de chapa), Power Kick (chute forte), Juggling 01
  (embaixadinha de espera). Créditos: https://linktr.ee/andersonrohr

## Sons (Etapa 27) — `assets/audio/`

Gerados por `tools/audio/build_sfx.py`.

**Sintetizados** (sem gravação de terceiros, feitos pelo projeto): toda a bola
(`ball/`: toques, passes, chutes, quiques, meio-fio, cercas, trave, corpo,
cabeça, rolando), o raspado do carrinho (`body/slide_*`) e o apito
(`whistle/`). Modelo físico: tempo de contato real + modos de vibração da
casca e da cavidade de ar da bola.

**Gravações** (OpenGameArt.org), recortadas, limpas e normalizadas:

| Uso no jogo | Origem (autor no OpenGameArt) | Licença |
|---|---|---|
| passos `steps/run_*`, `steps/walk_01–06`, derrapada `steps/scuff_*` | "Fantozzi's Footsteps (Grass/Sand & Stone)" — qubodup (de Fantozzi, freesound) | CC0 |
| passos `steps/walk_07–10` | "Footsteps" — GboxMikeFozzy | CC0 |
| passos `steps/walk_11–12` | "100 CC0 SFX #2" — rubberduck | CC0 |
| quedas/trombadas `body/fall_*` | "Body Hitting Ground" — dklon | **CC-BY 3.0** (atribuição obrigatória) |
| pouso do pulo `body/land_01` | "Jump Landing Sound" — qubodup (de MentalSanityOff, freesound) | CC0 |
| crianças `voices/kid_*` | "Children voices" — Yaroslav_Novikov | CC0 |
| risadas `voices/giggle_*` | "Group giggling" — Nocturnal_Vanguard (AuraVoice) | CC0 |
| comemoração `voices/cheer_*` | "Crowd Shouting/Speaking Ambience" — StarNinjas | CC0 |
| ambiência `ambience/street_day` | "AMB Morning Sounds" e "AMB Outside 1" — Kresiek The Furry; "Park ambiences" — Thimras; "High traffic road sounds" — IgnasD | CC0 |
