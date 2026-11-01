# Etapa 3 — Animações de futebol (Mixamo) sincronizadas com a bola

## O que mudou

- **Passe curto, passe longo, chute e chute forte** com animações reais de
  captura de movimento (Mixamo — *Soccer Game Pack*).
- **A bola sai no quadro em que o pé encosta nela.** A física decide o instante
  do contato; o controlador de animação pula para o ponto do clipe em que falta
  exatamente esse tempo para o pé tocar a bola (nó *TimeSeek* do AnimationTree).
- **Pé de apoio ao lado da bola**: na preparação do chute o jogador se posiciona
  para que a bola fique do lado do pé que chuta (direito ou esquerdo, conforme o clipe).
- **Domínio**: ao receber a bola parado ou trotando, o jogador pisa nela
  (clipe *stall soccerball*).
- **Condução sincronizada com a passada**: o toque de condução só sai quando um pé
  da animação está atrás e perto da bola (com limite de espera, para nunca perder o
  controle por isso). A bola fica entre ~0,25 m e ~0,75 m à frente do corpo.
- **Clipes "no lugar"**: os clipes do Mixamo andam até 4 m; o movimento horizontal
  do quadril é retirado ao carregar (o balanço natural fica) e guardado para uso
  como *root motion* nos dribles e no carrinho (Etapa 4).
- Se o pack do Mixamo não estiver no projeto, o jogo funciona igual à Etapa 2
  (os estados de chute simplesmente não são criados).

### Clipes escolhidos (verificados quadro a quadro)

| Ação | Arquivo do pack | Pé | Contato |
|---|---|---|---|
| Passe curto | `kick soccerball (2).fbx` | direito | 0,20 s |
| Passe longo | `kick soccerball.fbx` | esquerdo | 0,20 s |
| Chute | `strike foward jog.fbx` | direito | 0,41 s |
| Chute forte | `soccer penalty kick.fbx` | direito | 0,77 s |
| Domínio | `stall soccerball (2).fbx` | direito | 0,29 s |

Os demais clipes do pack (goleiro, carrinho, cabeceio, queda, levantar, lateral...)
já têm importação configurada e entram nas Etapas 4 e 5.

## Como colocar o Soccer Game Pack no projeto (pelo celular)

> O repositório no GitHub é **público** e os termos do Mixamo não permitem
> redistribuir os arquivos brutos. Por isso os `.fbx` estão no `.gitignore`;
> só a configuração de importação (`.import`) fica no repositório.

1. No Chrome do celular, abra **mixamo.com** → menu ⋮ → marque **"Site para computador"**.
   Entre com sua conta Adobe (gratuita).
2. Aba **Animations** → busque **Soccer Game Pack** → abra o pack.
3. **Download** com: *Format* **FBX Binary (.fbx)** · *Skin* **Without Skin** ·
   *Frames per second* **30** · *Keyframe Reduction* **none**.
4. Extraia o ZIP (ZArchiver). Copie **todos os `.fbx`** (sem renomear!) para:
   `rua10/assets/animations/mixamo/soccer_pack/`
   (a pasta já existe e já tem um `.import` para cada arquivo).
5. Abra o projeto no Godot: ele importa os clipes já com o mapa de ossos do Mixamo
   (1–2 minutos). Rode o jogo ou o laboratório de chute.

Se o Mixamo baixar algum arquivo com nome diferente (ex.: com maiúsculas), me avise
o nome que eu ajusto a configuração.

## Testar

- **Laboratório de chute**: abra `tests/kick_lab.tscn` → *Rodar cena atual*.
  Um jogador repete passe curto, passe longo, chute e chute forte.
- **Laboratório de personagens**: `tests/character_lab.tscn` (locomoção).
- **Jogo**: ▶.

### Checklist
1. O pé encosta na bola no momento em que ela sai? (passe, chute, chute forte)
2. O chute forte tem preparação demais (demora a sair)? E o passe é rápido o bastante?
3. O domínio (pisar na bola) aparece ao receber passes?
4. Na condução, a bola parece ser empurrada pelo pé ou "flutua" sozinha?
5. Alguma animação corta de forma brusca?

## APK

O APK desta etapa foi gerado com o Godot 4.3 (modelo de exportação oficial,
arm64-v8a, Android 5.0+, assinado). Configuração em `export_presets.cfg`.

Para instalar: abra o arquivo `.apk` no celular → permita "instalar apps
desconhecidos" para o app que abriu o arquivo (Arquivos/Chrome) → Instalar.

> Cada APK gerado aqui é assinado com uma chave de desenvolvimento. Se uma versão
> futura for assinada com outra chave, o Android pede para desinstalar a anterior
> antes de instalar (não há dados a perder no jogo ainda).
