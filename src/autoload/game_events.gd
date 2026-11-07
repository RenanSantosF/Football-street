extends Node
## Barramento global de eventos da partida (autoload "GameEvents").
##
## Sistemas que precisam reagir à partida (torcida, câmera, UI, áudio,
## animações de comemoração, sistema de busca da bola) escutam estes sinais
## em vez de conhecerem diretamente quem os emite. Isso mantém as cenas
## desacopladas: dá para adicionar a torcida (Etapa 6) sem mexer no MatchManager.

## Gol marcado. [param team] = time que marcou.
signal goal_scored(team: int, scorer: Node)
## Bola saiu do campo. [param kind] = BallOutSystem.Kind.
signal ball_out(kind: int, exit_position: Vector3, last_touch_team: int)
## Reinício de jogo (lateral, tiro de meta, saída de bola).
signal restart_started(team: int, kind: int, position: Vector3)
## Mudou quem tem a posse (null = bola livre).
signal possession_changed(new_owner: Node, old_owner: Node)
## Bola chutada/passada. [param kind]: &"pass", &"long_pass", &"shoot", &"tackle".
signal ball_kicked(kicker: Node, kind: StringName, power: float)
## Placar atualizado.
signal score_changed(score_shirts: int, score_skins: int)
## Estado da partida mudou (MatchManager.MatchState).
signal match_state_changed(state: int)
## O jogador controlado pelo humano mudou.
signal controlled_player_changed(player: Node)
## Mensagem curta para a tela ("GOL!", "LATERAL"...).
signal match_message(text: String, duration: float)
## Transição de tela (falta): escurece em [param out_time], segura
## [param hold] e clareia em [param in_time] (s). O reposicionamento acontece
## com a tela escura.
signal screen_fade(out_time: float, hold: float, in_time: float)
