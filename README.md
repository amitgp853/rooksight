# MoveWise

**An AI chess coach that never makes up a move.** Play Stockfish at your level, play a
friend on the same phone, or import your Chess.com and Lichess games. Every move is
reviewed by Stockfish on your phone, and you can ask the AI Coach why you keep losing,
then come back to that chat later. Every move the AI mentions is checked against the
engine and the rules before you see it.

Flutter · Android and iOS · no login, no backend, free to run.

<p align="center">
  <img src="design/screenshots/home.png" width="200" alt="Home">
  <img src="design/screenshots/game.png" width="200" alt="Playing Stockfish: only your clock runs">
  <img src="design/screenshots/result.png" width="200" alt="Game over">
  <img src="design/screenshots/review.png" width="200" alt="Game review with AI explanations">
  <br>
  <img src="design/screenshots/coach.png" width="200" alt="AI Coach answering with its steps">
  <img src="design/screenshots/stats-weaknesses.png" width="200" alt="Top 3 weaknesses">
  <img src="design/screenshots/stats-charts.png" width="200" alt="When games go wrong">
  <img src="design/screenshots/report-card.png" width="200" alt="Shareable report card">
  <br>
  <img src="design/screenshots/play-setup.png" width="200" alt="New game setup">
  <img src="design/screenshots/pass-setup.png" width="200" alt="Pass & Play setup">
  <img src="design/screenshots/pass-tabletop.png" width="200" alt="Pass & Play, face to face">
  <img src="design/screenshots/pass-result.png" width="200" alt="Pass & Play result, saved to your games">
  <br>
  <img src="design/screenshots/coach-new.png" width="200" alt="AI Coach, new chat">
  <img src="design/screenshots/coach-chats.png" width="200" alt="Saved AI Coach chats">
  <img src="design/screenshots/coach-chat-options.png" width="200" alt="Rename or delete a chat">
  <img src="design/screenshots/import.png" width="200" alt="Chess.com and Lichess import">
  <br>
  <img src="design/screenshots/stats-openings.png" width="200" alt="Results by opening and personal bests">
  <img src="design/screenshots/games.png" width="200" alt="Game library">
  <img src="design/screenshots/home-light.png" width="200" alt="Light mode">
</p>

## What it does

| | |
|---|---|
| **Play** | Stockfish from 400 to 3000 Elo (step 200), your colour and time control. Only you are timed; Stockfish plays without a clock. Hints, take-backs in practice mode, draw offers, every rule (castling, en passant, promotion, repetition, 50-move rule, insufficient material). An unfinished game waits on Home. |
| **Pass & Play** | Two players on one phone, fully offline, both clocks running. The board turns for the player to move, or a face-to-face layout lets the phone lie flat between you (pieces turn to face whoever's move it is). Takebacks and draw offers need the other player's OK. Pause hides the board; "Save and finish later" keeps the game on Home. Finished games are saved from the first player's side and count in their stats. |
| **Import** | Your public Chess.com and Lichess games by username (one per site, kept on the phone). No login; requests are one at a time, and later imports fetch only new games. When a site asks to slow down, the import pauses with a live countdown (or "Try now") and carries on by itself. |
| **Scan a board** | Photograph a real board or a book diagram (or pick a photo), crop it to the 64 squares, and Gemini reads the position with your own key while you watch each step. If something doesn't add up (two white kings, a pawn on the back rank) it takes a second look at just those squares. Then check it: doubtful squares are marked, a side-by-side view compares with your photo, a piece palette fixes any square, and you set side to move and castling. Analyze stays off until the position is legal. Without a key, offline or out of quota, the same editor sets a position up by hand. The photo is never saved. |
| **Analysis board** | Any position from a scan, by hand, or "Analyze this position" in a review: Stockfish's eval (signed), win/draw/loss chances, its top 3 lines deepening live to depth 24, the best-move arrow, and a Threat arrow for what the other side wants. Play any move for either side; moves off the line become variations (long-press to promote, copy or delete), each marked `?!` `?` `??` against Stockfish's best, with Take back. Flip, copy FEN, share an image, play on from here vs Stockfish, or ask the AI Coach. Save a position (bookmark) to come back to it from Home: the moves you explore are kept as you go. |
| **Review** | Stockfish checks every move on the phone: accuracy, an evaluation graph and bar, moves marked `!!` `!` `?!` `?` `??`, and the key moments. One optional AI request explains them. |
| **AI Coach** | Ask anything about your games. A tool-calling agent looks at your games and asks Stockfish, and you watch each step as it happens. Chats are saved on the phone: search them, rename or delete them, and reopen one to carry on (opening a chat never runs the AI). |
| **Stats** | Your top 3 weaknesses, when in a game things go wrong, blunders by phase, results by opening, personal bests. All computed on the phone. |
| **Report card** | A 1080 × 1350 image of a game (accuracy, best move, worst blunder, verdict) to share. |

## Architecture

Feature-first. Everything that talks to the outside world sits behind an
interface, so tests swap in fakes.

```mermaid
flowchart TB
  subgraph UI["features/ (screens + Riverpod controllers)"]
    play[play] --- pass[pass_play] --- review[review] --- coach[coach]
    import[import] --- stats[stats] --- report[report_card]
    games[games] --- settings[settings] --- splash[splash]
    scan[scan] --- analysis[analysis]
  end

  subgraph core["core/ + engine/"]
    engine["ChessEngine<br/>(Stockfish 16 NNUE, off the UI thread)"]
    llm["LlmClient<br/>(Gemini REST, retries + fallback model)"]
    chesscom["ChessComApi · LichessApi<br/>(public APIs, one request at a time)"]
    repo["GameRepository · AnalysisRepository · ChatRepository<br/>(Drift / SQLite)"]
    rules["dartchess<br/>(rules, SAN, PGN)"]
    board["chessground board<br/>+ MoveWise theme"]
  end

  play --> engine & rules & board & repo
  pass --> rules & board & repo
  review --> engine & llm & repo & board
  coach --> llm & engine & repo
  import --> chesscom & repo
  stats --> repo
  report --> repo & board
  scan --> llm & rules & board
  analysis --> engine & rules & board
```

```
lib/
  core/       theme, board, routing, storage (Drift), llm, settings, motion
  engine/     Stockfish over UCI, Elo levels (one config file)
  features/   play · pass_play · import · games · review · coach · stats · report_card · settings · splash
```

**Stack:** Flutter, Riverpod, go_router, Drift, dartchess, chessground,
multistockfish (Stockfish 16), Gemini over plain REST, share_plus.

## The AI Coach agent

The one agentic feature, a loop written by hand in Dart
([coach_agent.dart](lib/features/coach/domain/coach_agent.dart)).

```mermaid
sequenceDiagram
  actor You
  participant Agent as CoachAgent
  participant Model as Gemini
  participant Tools as CoachTools
  participant SF as Stockfish

  You->>Agent: "Why do I keep losing?"
  Agent->>Model: question + your recent games + 3 tool definitions
  loop at most 5 tool calls
    Model-->>Agent: call get_my_stats / get_game_mistakes / analyze_position
    Agent->>Tools: run it (step shown live)
    Tools->>SF: analyse positions if needed
    Tools-->>Agent: compact summary (never raw engine output)
    Agent->>Model: tool results
  end
  Model-->>Agent: answer (JSON: headline, body, try this, move)
  Agent->>Agent: drop every sentence naming a move no tool reported
  Agent-->>You: checked answer + a card that opens the move in its review
```

- **Tools:** `get_my_stats()`, `get_game_mistakes(game_id)`,
  `analyze_position(fen)`.
- **Budget:** at most 5 tool calls. After that the model must answer, so a
  question costs 2–6 model calls.
- **Grounding:** the prompt tells the model to use only moves from tool
  results. The code then checks: every move in the answer must be one the tools
  reported (legal in a position they looked at), or its sentence is removed.
  The move card must point to a move the tools described.
- **Live steps:** "Checking your last 20 games…", "Asking Stockfish about move
  23…", "Verified best move: Rd1".
- **Memory:** a question carries the chat's last 5 questions and answers. Chats
  are saved on the phone (Drift), with the moves their tools verified, so a
  reopened chat can still mention them in follow-ups. Past about 2,000 tokens a
  chat is full and asks you to start a new one.

The review's single AI call is checked the same way, and more strictly. Claims
of mate need a forced mate in Stockfish's lines. "Loses the queen" needs a
queen-sized material swing. Titles can't praise a mistake.

## How moves are judged

Loss against Stockfish's best move, in pawns (capped at ±10): **inaccuracy**
0.5–1.0, **mistake** 1.0–2.0, **blunder** over 2.0. `!` marks the one good move
(every alternative at least a pawn worse, with the game still in the balance).
`!!` marks a sound sacrifice. Accuracy is computed as Lichess does: each move
scores by how much it dropped your winning chances, and the game averages a
volatility-weighted mean with a harmonic mean, so a few blunders count as they
should instead of disappearing into a plain average.

## Running it

Requires Flutter 3.47+.

```sh
flutter pub get
flutter run
```

**Gemini key:** get a free key from https://aistudio.google.com/apikey and paste
it in Settings: turn on **Developer mode** at the bottom, and the **AI Coach**
section appears below it. It's kept in the iOS Keychain / Android encrypted
storage and never leaves the phone except in requests to Gemini. Without a key
everything works except the AI explanations and the AI Coach.

For development you can also pass a key at build time, used only when none is
saved in Settings:

```sh
cp .env.example .env          # add your key
flutter run --dart-define-from-file=.env
```

In VS Code, the launch configurations in `.vscode/launch.json` pass `.env` for
you.

**Free tier:** playing (against Stockfish or a friend), importing, reviewing
with Stockfish, stats and reopening saved chats make no AI calls. Explaining a game is 1 call; a coach question is 2–6. Overloads and
short rate limits are retried with jittered backoff. A busy model, or one whose
free quota is used up, hands over to a lighter one (`GEMINI_MODEL`,
`GEMINI_FALLBACK_MODEL` in `.env`).

Debug builds compile Stockfish with optimisation (see `ios/Podfile` and
`android/build.gradle.kts`); without it the engine is about 17× slower.

## Tests

```sh
flutter analyze
flutter test
```

Tests cover the Elo mapping, move classification, special rules from FEN
positions, the clocks (player-only against Stockfish, both sides in Pass & Play),
Pass & Play (takebacks, draw offers, pause, saving and resuming), Chess.com and
Lichess parsing and import, the Gemini client (retries, fallback, tool-call
format), the coach loop with a fake model (tool cap, forced answer, grounding),
saved chats (storage and migration, search, reopening without an AI call,
continuing with earlier moves), the weakness checks, the report card image size,
and the screens.

Tools in `tool/` regenerate assets: `render_pieces.dart` (piece PNGs),
`make_sounds.py` (move sounds).
Icons and splash come from `flutter_launcher_icons.yaml` and
`flutter_native_splash.yaml`.

## Design

The full design (colour tokens, type, motion spec, every screen) is in
[`design/`](design/design-spec.md), made in Claude Design ("Night Study").
The piece set and the logo, the analyst's rook, are custom.

## Licence

Copyright (C) 2026 amitgp853

MoveWise is free software: you can redistribute it and/or modify it under the
terms of the [GNU General Public License v3.0](LICENSE) (GPL-3.0-only).

In short: you may run, study and change it. If you share it or a modified
version, in any form, you must share its full source under the same licence,
keep this copyright notice, and state what you changed. It comes with no
warranty.

It builds on these GPL-3.0 projects, which is why MoveWise uses the same
licence:

- [Stockfish](https://stockfishchess.org), via
  [multistockfish](https://github.com/lichess-org/dart-multistockfish)
- [dartchess](https://github.com/lichess-org/dartchess) and
  [chessground](https://github.com/lichess-org/flutter-chessground) from Lichess
- [sound_effect](https://github.com/lichess-org/flutter-sound-effect)

The MoveWise piece set, logo, design and board sounds are part of this
repository and covered by the same licence.
