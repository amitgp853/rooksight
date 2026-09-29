# MoveWise — design handoff for Flutter

An AI chess coach. There's no login. You play Stockfish, play a friend on one phone, or import games from Chess.com and Lichess. The **AI Coach** explains your mistakes. It runs on Gemini, and Stockfish checks every move it mentions. The app is built for phones and is dark by default, with a light mode.

The `design/` folder holds the source of every artboard, plus `motion.css`. Each artboard is a `*.dc.html` file: HTML with inline styles and `{{placeholders}}`, which a small script block at the bottom fills in. These files won't render on their own in a browser, so view them on the MoveWise design canvas. Treat the source as the visual spec and copy exact colours, sizes, radii and text from it. Many screens are one component with a state prop, plus small wrapper files that show a single state. The wrappers are listed in the table below.

## Global rules (read first)

- **The name is "AI Coach" everywhere.** Use it on buttons, headers and tiles, never plain "Coach" or "coach chat".
- **AI is opt-in.** No AI call runs on its own: not when a screen opens, not when a game ends, not when an import finishes. The AI Coach runs only when the user taps a button that asks for it ("Explain key moments", "Ask AI Coach", "Get AI verdict", "Explain again", or sending a chat message). Stockfish analysis can run automatically. It's local and offline.
- Every move the AI mentions is checked by Stockfish before it's shown. Wherever AI text appears, the UI says so: "Explained by AI · moves and claims checked".
- The chess board is always full screen width.
- Every animation has a reduced-motion version (see Motion).

## Screens → design files

| # | Screen | Main file | State wrappers |
|---|---|---|---|
| — | Design system | `Main.dc.html` | |
| — | Board component (all overlays) | `Board.dc.html` | |
| 1 | Home (props `theme` dark/light, `weakness` found/empty) | `Home.dc.html` | `HomeLight` (light theme, no weakness found yet) |
| 2 | Play setup | `PlaySetup.dc.html` (prop `dialog`) | `PlaySetupAbandon` |
| 3 | Game vs Stockfish | `GameScreen.dc.html` (prop `state`), `Game.dc.html` = idle | `IX01…IX21-*` (full motion), `RM01…RM13-*` (reduced motion) |
| 4 | Game review (prop `stage`) | `Review.dc.html` | `ReviewAsk`, `ReviewLoading`, `ReviewProgress`, `ReviewError`, `ReviewEmpty` |
| 5 | AI Coach chat (prop `view`) | `Coach.dc.html` | `CoachEmpty`, `CoachEmptyGame`, `CoachPicker` |
| 6 | Stats | `Stats.dc.html` | |
| 7 | Report card (share screen + 1080×1350 image, prop `verdict` ai/summary) | `ShareReport.dc.html`, `ReportCard.dc.html` | |
| 8 | Settings | `Settings.dc.html` | `SettingsDev` (Developer mode on) |
| 9 | Pass & play | `PassSetup.dc.html`, `PassGame.dc.html`, `PassTabletop.dc.html` | `PassGameWhite`, `PassGameBlack`, `PassPaused`, `PassDraw`, `PassResult` |
| 10 | Import games (prop `state`) | `ImportGames.dc.html` | `ImportForm`, `ImportLichess`, `ImportProgress`, `ImportNotFound`, `ImportOffline`, `ImportRateLimit`, `ImportDone` |
| 11 | Games library | `Games.dc.html` (list rows are in `GameRows.dc.html`) | `GamesDelete`, `GamesEmpty` |
| 12 | Splash + animated intro | `Splash.dc.html` | `SplashDark`, `SplashLight`, `SplashA12Dark`, `SplashA12Light`, `SplashIntro`, `SplashIntroBlend` |
| — | Result card, all endings | `ResultCards.dc.html` | |
| — | Logo | `Logo.dc.html` | `LogoSheet`, `LogoDir1-9`, `LogoChosen`, `LogoHome`, `PhoneHome`, `LogoAdaptive`, `LogoMono`, `LogoOnReport` |
| — | Motion timings table | `MotionSpec.dc.html` | |

`GameScreen.dc.html` has a table (`var S = {...}`) with the exact board state for every interaction frame. It's handy for test positions too.

## Screen specs

### 1 Home
- **Continue card:** shows only when a game is unfinished. It has a mini board at the current position, "Blitz 5+0 · move 3" and "04:59 · your turn" (the player's own clock), and taps back into the game.
- **Tiles:** Play vs Computer · Pass & play · Import games (subtitle "Chess.com · Lichess") · AI Coach · Stats card.
- **Stats card:** shows the top weakness. With too few reviewed games it shows the empty state: "Review a few games to find your patterns."
- **Games row:** "22 saved · all, won and lost", opens the Games library.

### 2 Play setup
- Elo 400–3000 in steps of 200, colour (White / Random / Black).
- The time control section is headed **"Your clock"**, with the note: "Only you are timed. Stockfish plays without a clock." The summary line reads "… · your clock 5+0".
- If a vs-Stockfish game is unfinished, Start opens a dialog:
  - Title: "Abandon your current game?"
  - Body: "Your game vs Stockfish 1000 is saved on Home. Starting a new one ends it."
  - Buttons: **Keep it** (secondary) and **Start new game** (primary).

### 3 Game vs Stockfish
- **Header:** back, "vs Stockfish · 1000" over "Blitz 5+0", and a "…" button that opens the More sheet.
- **Clock:** only the player has one. Stockfish's row shows no clock box, just its name, its captured-piece tray and the thinking indicator. The chosen time control is the player's time. If the player's flag falls, they lose on time. Stockfish is never flagged.
- **Your row:** "You", a status line ("Your move" / "In check" / "Stockfish to move"), your captured tray and your clock. Clock colours: focus fill when running, brass under 30 s, coral under 10 s with a breathe.
- **Captured trays:** show material difference (+N). With nothing captured yet they read "No captures yet".
- **Action bar:**
  - Hint.
  - Undo: locked (with a lock icon) unless practice mode is on.
  - Flip.
  - More.
- **More sheet:**
  - Practice mode toggle. Its copy changes with the state: on = takebacks and hints unlimited, not counted in stats.
  - Offer draw, Resign.
- **Engine error card:**
  - Shown when Stockfish doesn't respond: "Stockfish didn't answer."
  - Buttons: **Try again**, **See result**.
- **Result sheet:**
  - Primary action: **Review with AI Coach**. It opens the Review screen in the `ask` stage and does *not* start AI on its own.
  - Secondary actions: Rematch and Share.

### 4 Game review (`stage`: done · ask · loading · progress · error · empty)
- **App bar:** back, Ask AI Coach (chat icon), Share and Delete.
- **progress:**
  - Stockfish is still analysing: "Analysing with Stockfish", with "Move 12 of 41 · you can look around meanwhile".
  - The board and moves stay usable while it runs.
- **error:** "Stockfish couldn't finish the analysis." with **Try again**.
- **ask:**
  - Stockfish is done. The eval graph and key moments show, without AI text.
  - Card: "Want these explained in plain words?" with **Explain key moments** and the line "Every move the AI mentions is checked."
- **loading:** "Asking AI about 3 moments…"
- **done:**
  - An AI block with SUMMARY and WORK ON sections.
  - Footer: "Explained by AI · moves and claims checked" with an **Explain again** button.
- **Key moment cards:**
  - Each card shows a quality chip, a side chip (you / Stockfish), the eval, a headline with a sparkle, and a LESSON box.
  - Actions: "Ask AI Coach about this move" and "Play the best move".
  - Collapsed cards show **Read more** / **Show best move**.
- **Replay bar (over the board while a line plays):**
  - "Stockfish's line · 2 of 5", then **Back to the game**.
  - When you replay your own line: "Your line", then **Back to key moments**.
- **empty:** "No big mistakes and no standout finds: a steady game."

### 5 AI Coach (`view`: answer · empty · emptyGame · picker)
- **Header:** "AI Coach" over "Every move claim checked by Stockfish", with a **New chat** pill.
- **Agent steps:** three live steps (animated while running), which collapse behind a chevron when finished.
- **Answer:**
  - A bold headline ("You weaken your king too early."), then the explanation.
  - A "Try this:" line.
  - A tappable move card, e.g. "15. g3?? → Qg5", that opens the position.
- **Composer:** a "+" button to attach a game, a pill-shaped text field, mic and send. Attached games show as chips above the field.
- **Agent step copy:** "Checking your last 20 games…", "Asking Stockfish about move 15…", "Verified best move: Qg5 · Same result at depth 26".
- **Empty:**
  - "Ask about your games, a move or a pattern. Every move it suggests is checked by Stockfish before you see it. Tap + to pick a game."
  - Suggestions: "Why do I keep losing?", "What should I work on first?", "Explain my costliest mistake".
- **emptyGame** (a game is attached):
  - "Ask anything about this game…"
  - Suggestions: "What went wrong in this game?", "Where did I lose the advantage?", "What should I have played instead?".
- **Picker sheet:** saved games with filters All / Won / Lost, using the same rows as the Games library.

### 6 Stats
- **Tiles:**
  - Win rate 45%.
  - Accuracy 76.2.
  - Blunders / game 1.2, with the note "no trend yet" when there's too little data.
  - Record "9–1–10", with the note "wins – draws – losses".
- **Weakness cards:** each has **Ask AI Coach** and **See N games**.
- **"When your games go wrong":** stacked bars by game phase, labelled "first moves", "most pieces on" and "few pieces left" (no jargon), with a caption such as "37% …".
- **Openings chart.**

### 7 Report card
- There are two variants of the 1080×1350 image:
  - **summary** (no AI): titled "Game summary". Its subtitle is the opening name, or falls back to the first moves ("1. e4 e6").
  - **ai**: the AI verdict. It exists only after the user taps **Get AI verdict**.
- **Share screen:** shows the summary card plus **Get AI verdict**, **Share image** and **Copy PGN**.

### 8 Settings
- **Game import:** Chess.com username and Lichess username. The note reads: "Only public games are read. No login, no password. One username per site is kept on this phone."
- **Board theme.**
- **Appearance:** Dark / Light / System.
- **Sound and motion:** toggles.
- **Stockfish analysis depth:** Fast 14 / Balanced 18 / Deep 22. The note reads: "Deeper analysis is more accurate but takes longer. It all runs on this phone, offline."
- **Developer mode:** "Shows advanced settings, including your own AI Coach key." When on (`SettingsDev`), it shows:
  - **AI Coach key (Gemini):** "Stored only on this phone. The AI Coach runs only when you tap a button that asks for it."
  - A step-by-step free-key guide for Google AI Studio.
  - A free-tier limits note.
- **Footer:** "MoveWise 0.1.0 · Stockfish runs on your device".

### 10 Import games (`state`: form · lichess · progress · notFound · offline · rateLimit · done)
- **form / lichess:**
  - A source switch: Chess.com or Lichess.
  - Username, prefilled from Settings.
  - How far back: 3 months ("Since Jul 2026"), 12 months, or Everything ("Your whole history").
  - Notes: "Only public games are read. No login or password." and "Games you already have are skipped."
- **progress:** "Importing from Chess.com", a progress bar and "You can leave this screen. The import keeps going."
- **notFound:** inline error on the username field.
- **offline:**
  - Title: "You're offline".
  - Body: "Importing needs the internet. Your saved games, Stockfish and pass & play still work."
- **rateLimit:**
  - Title: "Chess.com asked us to slow down".
  - Body: "Their servers limit how fast games can be fetched. We'll carry on automatically in 0:42."
  - Note: "Nothing is lost. Games fetched so far are already saved."
- **done:** "57 games imported", "From Chess.com, last 3 months. 12 you already had were skipped."
- **Stockfish after import:** it analyses imported games in the background. The AI Coach never runs on its own.

### 11 Games library
- **Filters:** All 22 / Won 9 / Lost 11.
- **Rows** (`GameRows.dc.html`):
  - A W/L/D badge, the opponent, a line such as "Checkmate · 41 moves · 5+0 · 28 Sep", a source tag and the date.
  - Tap a row to open Review.
  - The row menu opens a **delete sheet**:
    - Title: "Delete this game?"
    - Body: "Its review and AI notes are deleted too. It will no longer count in your stats. This can't be undone."
    - Button: **Delete game**.
- **Empty state:**
  - "No games yet" / "Every game you finish is kept here, ready for review. Play Stockfish or a friend, or bring in your online games."
  - Buttons: **Play vs Computer** and **Import from Chess.com or Lichess**.

## Logo (direction 9A, "the analyst's rook")

A rook (chess) whose three battlements rise like a bar chart (analysis); the tallest bar is brass (the best move) and a four-point spark is cut into the tower (the AI coach). Source: `Logo.dc.html` (variant `brand` = `9a`) and the `Logo*.dc.html` frames. Ready-made files are in `logo/`:

- `app_icon_dark.svg` / `app_icon_1024.png`: full app icon, tile #151B22, for iOS and the Play Store.
- `adaptive_foreground.svg` / `adaptive_foreground_432.png`: Android adaptive icon foreground (rook at 64%, inside the 66dp safe zone). Background layer = solid #151B22.
- `adaptive_monochrome.svg` / `adaptive_monochrome_432.png`: Android 13+ themed icon layer (spark is a real cut-out).
- `mark_dark.svg`, `mark_light.svg`, `mark_mono.svg`: the mark for in-app headers, light backgrounds and favicons.

With `flutter_launcher_icons`: `image_path: logo/app_icon_1024.png`, `adaptive_icon_background: "#151B22"`, `adaptive_icon_foreground: logo/adaptive_foreground_432.png`, `adaptive_icon_monochrome: logo/adaptive_monochrome_432.png`.
Wordmark: "MoveWise" in Sora 600, tracking −2.5%, beside the icon.

## Pass & play rules

- Names default to "You" and "Opponent", editable (max 16 chars). The swap button trades colours; White moves first.
- Clock: 3+2, 5+0, 10+0, 10+5 (default), 15+10 or no clock. Increment is added after each move. Both players have clocks here (unlike vs Stockfish). Same 30 s / 10 s clock colours.
- "Flip board after each move" (default on): after a move lands, wait ~400 ms, then flip so the player to move sits at the bottom. The name rows swap with the board, and a "pass the phone" banner appears.
- "Face-to-face layout": the phone lies flat, the board never flips, and the top panel is turned 180° for the opponent. Each panel has its own big clock, Takeback, Offer draw and Resign. Choosing this turns off auto-flip.
- Takebacks and draw offers need the other player to confirm on the same phone. Pause stops both clocks and hides the board.
- Fully offline. Every game is saved locally as PGN (players, time control, clocks per move) in "Your games", ready for engine review offline and AI Coach explanations when online (on request).

## Splash screens

Everything is in `splash/`:

- `splash_logo_light.png`, `splash_logo_dark.png` (592×592): the rook, centred on #F1F3F6 / #0E1217. Shows at 148 dp.
- `android12_icon_light.png`, `android12_icon_dark.png` (960×960): Android 12+ splash icon, rook inside the 640 px circle, on an icon background of #FFFFFF / #151B22.
- `branding_light.png`, `branding_dark.png` (800×200): the "MoveWise" wordmark shown at the bottom.
- `flutter_native_splash.yaml`: ready-made config. Copy the PNGs to `assets/splash/`, add the block to `pubspec.yaml` (or keep it as its own file), then run `dart run flutter_native_splash:create`.
- `movewise_intro.dart`: optional animated intro (about 1.2 s) that runs right after the native splash: the tower appears, the three battlements rise one by one, the AI spark pops in and the wordmark fades up. The logo sits in the same spot as the native splash, so the hand-off is seamless. It respects reduced motion. Needs the Sora font registered in `pubspec.yaml`.

Canvas frames: `SplashDark`, `SplashLight`, `SplashA12Dark`, `SplashA12Light`, `SplashIntro` (light), `SplashIntroBlend` `.dc.html`.

**Intro theme blend:** the native splash follows the phone's system theme, but the app may use a different one (for example, the phone is light and the app is dark). The intro starts in the native splash colours and cross-fades to the app theme between 300 ms and 1200 ms while the rook draws: background #F1F3F6 → #0E1217, rook #2F5BD3 → #86A8FF, brass #C98A1B → #E3B25C, wordmark #121820 → #E9EDF2. The keyframes are `mw-i-bgblend`, `mw-i-pri`, `mw-i-acc`, `mw-i-hole`, `mw-i-ink` and `mw-i-inksub` in `motion.css`. If the two themes match, there's no blend. With reduced motion, show the end state straight away.

## Colour tokens

| Token | Dark (default) | Light |
|---|---|---|
| bg.base | #0E1217 | #F1F3F6 |
| bg.raised | #151B22 | #FFFFFF |
| bg.elevated | #1C242E | #E6EAF0 |
| border | #2A3441 | #D5DBE3 |
| text.primary | #E9EDF2 | #121820 |
| text.secondary | #A3AFBD | #4A5563 |
| text.tertiary | #7C8898 | #5F6B7A |
| accent.focus | #86A8FF | #2F5BD3 |
| accent.onFocus | #0B1224 | #FFFFFF |
| accent.brass | #E3B25C | #8A5F0F |

Semantic (dark / light): brilliant `!!` #E3B25C / #8A5F0F · best `!` #86A8FF / #2F5BD3 · inaccuracy `?!` #E3C65C / #7A6200 · mistake `?` #F09A55 / #B4531A · blunder `??` #F2677A / #C22F48 · win #86A8FF · draw #7C8898 · loss #F09A55.
Always show the quality symbol next to its colour. Never rely on colour alone.

Clocks: normal active = focus fill; under 30s = brass; under 10s = coral (#F2677A), breathing 1 → 0.7 opacity each second.

## Type (Google Fonts)

- Sora 600: display 40/44 (−2%), title 24/30, heading 17/24
- Instrument Sans: body 15/22 (400), label 13/18 (500), overline 11/16 600 caps +8%
- JetBrains Mono 500: moves, clocks, evals 15/22

## Spacing & radius

4-pt scale: 4, 8, 12, 16, 20, 24, 32, 40, 56. Screen gutter 16.
Radius: chips 6, buttons 12, cards 16, sheets 24, pills full.
Buttons 52 high (44 min touch target).

## Board

- Full screen width on every chess screen (390 wide → 48.75 px squares), no side padding.
- Themes (light / dark square): Slate #CDD5E0 / #6B7C94 (default) · Ink #D9DEE5 / #46536B · Dusk #DED7E9 / #7C6E9B · Ember #EEDFCF / #B47A5E.
- Last move tint (light / dark square): Slate #E8D9A4 / #B39962, Ink #E8D9A4 / #8F7C52, Dusk #ECDDB2 / #A88E74, Ember #F0DC9E / #C49A55.
- Selected square: #86A8FF at 55%. Legal dot: 30% of square, rgba(14,18,23,0.32). Capture ring: inset ring 9% of square, same colour. Castle-onto-rook target: dashed brass ring.
- Drag target: 4px inset ring rgba(233,237,242,0.92). Check: radial coral glow. Hint: brass arrow (#E3B25C, 92%), shaft width 20% of square.
- Coordinates sit inside the edge squares, JetBrains Mono, 21% of square.

### Piece set (custom SVG, 48×48 viewBox, draw at 90% of square, centred)

White: fill #F5F7FA, stroke #1A212B width 3 **painted behind the fill** (visible outline 1.5). Black: fill #1E2530, stroke rgba(226,232,240,0.72) width 2.4 behind the fill. Detail lines: 1.6 wide, #1A212B (white) / #8FA0B5 (black). Drop shadow 0 1.5 1.5 rgba(0,0,0,.35).
In Flutter: draw the stroke first, then the fill (two `Paint`s on the same `Path`, e.g. with `path_drawing`'s `parseSvgPathData`), or export these as SVG assets for `flutter_svg`.

```
BASE = M12 36.5h24a2 2 0 0 1 2 2v1.5a2 2 0 0 1-2 2H12a2 2 0 0 1-2-2v-1.5a2 2 0 0 1 2-2z
pawn   = M24 8.5a6 6 0 1 1 0 12a6 6 0 1 1 0-12zM18 21.5h12l-1.5 3h-9zM19.5 25.5h9c.5 4.2 2 7.6 4.5 10.5H15c2.5-2.9 4-6.3 4.5-10.5z + BASE
rook   = M12 7h5v4h3.5V7h7v4H31V7h5v8l-3 3H15l-3-3zM15 19h18l1.4 15.5H13.6zM11 35.5h26a2 2 0 0 1 2 2v2.5a2 2 0 0 1-2 2H11a2 2 0 0 1-2-2v-2.5a2 2 0 0 1 2-2z
bishop = M24 3.5a2.6 2.6 0 1 1 0 5.2a2.6 2.6 0 1 1 0-5.2zM24 9.5c5 3.5 8 7.8 8 12c0 2.8-1.6 4.6-3.6 5H19.6c-2-.4-3.6-2.2-3.6-5c0-4.2 3-8.5 8-12zM16.5 27.5h15a1 1 0 0 1 1 1v.5a1 1 0 0 1-1 1h-15a1 1 0 0 1-1-1v-.5a1 1 0 0 1 1-1zM19 31h10l2.5 4.5h-15z + BASE   detail: M27 14.5l-4.5 5.5
knight = M34.54 36.8L36.38 30.36L38.22 28.98L36.38 26.22L37.3 22.54L35 20.7L35 17.02L32.7 15.64L31.78 11.96L29.02 10.58L28.1 5.06L26.26 2.3L24.88 7.36L22.12 8.28L11.54 20.24L9.24 23.46L9.24 26.68L12 28.06L15.22 26.91L14.99 29.21L19.36 29.44L23.96 25.76L25.34 24.38L21.2 28.98L17.98 32.66L16.14 36.8Z + BASE   detail (nostril, eye): M11.54 24.61L10.62 25.07M21.2 12.42L19.59 13.57L21.2 14.72L22.81 13.57Z
queen  = M10 9.8a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 1 1 0-4.4zM17 6.3a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 1 1 0-4.4zM24 4.8a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 1 1 0-4.4zM31 6.3a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 1 1 0-4.4zM38 9.8a2.2 2.2 0 1 1 0 4.4a2.2 2.2 0 1 1 0-4.4zM10.5 15L14.5 28h19l4-13l-6.5 6.8L30.5 11.5l-4 9.5L24 10l-2.5 11l-4-9.5l-.5 10.3zM14.5 29h19l-1 3.5h-17zM15.8 33.5h16.4l1.3 2.3H14.5z + BASE
king   = M22.6 2.5h2.8v2.8h2.8v2.8h-2.8v3.4h-2.8V8.1h-2.8V5.3h2.8zM24 12.5c-2.8 0-4.6 2.2-4.6 4.6c0 .9.2 1.7.6 2.4C17.4 18 12.6 18.2 11.4 22c-1 3.3 1.6 5.8 3.6 6.5h18c2-.7 4.6-3.2 3.6-6.5c-1.2-3.8-6-4-8.6-2.5c.4-.7.6-1.5.6-2.4c0-2.4-1.8-4.6-4.6-4.6zM15 29.5h18l-1 3h-16zM16 33.5h16l1.3 2.3H14.7z + BASE   detail: M24 18v10
```

## Motion (full table in `MotionSpec.dc.html`)

Rules: nothing on the board runs longer than 360ms. New input jumps any running animation to its end state. If `MediaQuery.of(context).disableAnimations` is true, nothing travels, scales or shakes; use 150ms fades and colour changes only.

| Interaction | Full motion | ms | Curve |
|---|---|---|---|
| Tap piece | dots/rings pop 0.3→1, square tints | 120 | easeOutCubic |
| Drag | lift scale 1→1.1, shadow, 0.4 sq above finger, 28% ghost at origin | 100 | easeOut |
| Move / engine move | slide | 200 | Cubic(0.22, 0.9, 0.3, 1) |
| Illegal | snap back 150 → shake ±5/±5/±3 over 200, coral flash on origin | 350 | easeOutCubic |
| Capture / en passant | captured piece fades + shrinks to 0.55 starting 100ms before landing | 190 | easeIn |
| Castling | king + rook slide together | 240 | easeOutCubic |
| Promotion picker | board dims 58%, picker grows from square (Q first, largest) | 160 | easeOutCubic |
| Promotion morph | pawn out to 0.7 (120), piece in 0.6→1.08→1 (200) | 320 | easeOutBack |
| Check | king square pulses 0→1→0.45→1, then stays tinted | 360 | linear |
| Thinking | 3 dots, 1200ms loop, 150ms stagger, shown after 300ms | loop | easeInOut |
| Hint | brass arrow draws, head appears last 100ms | 360 | easeOutCubic |
| Flip | board rotates 180°, pieces counter-rotate | 300 | easeInOutCubic |
| Sheets (options, result) | slide up + 55% scrim; result waits 600ms after final move | 320 | Cubic(0.2, 0.9, 0.3, 1) |

Haptics: selectionClick (pick up, tap), lightImpact (move), mediumImpact (capture, illegal, game over), heavyImpact (your king in check).

## Game-end reasons (result sheet)

Checkmate (win or loss), stalemate, threefold repetition, 50-move rule, insufficient material, resignation, timeout (vs Stockfish only the player can lose on time).

Actions:

- **Review with AI Coach** (primary). It opens Review at the `ask` stage and doesn't call the AI.
- Rematch.
- Share.

## Data and engines

- **Chess rules:** a Dart chess logic package for legal moves, FEN/PGN and draw detection.
- **Engine:** Stockfish on the device, via a pub.dev Stockfish package (UCI).
  - Elo 400–3000 maps to `UCI_LimitStrength` / `UCI_Elo`. Stockfish's own floor is about 1320; below that, use Skill Level plus a shallow depth.
  - Review depth comes from Settings: 14 / 18 / 22.
  - Stockfish has no clock. Give it a fixed movetime or depth per move, plus a short random delay so replies don't feel instant.
- **Chess.com import:** public API, no auth. `https://api.chess.com/pub/player/{username}/games/archives` lists the monthly archive URLs, and each archive returns PGNs. On HTTP 429, show the rateLimit state and retry with backoff.
- **Lichess import:** public API, no auth. `https://lichess.org/api/games/user/{username}?since={ms}` with `Accept: application/x-chess-pgn` streams PGN. Keep to one request at a time. On 429, wait 60 s (rateLimit state). A 404 means the user wasn't found (notFound state).
- **Deduplicate** on source plus game id (Chess.com URL or Lichess id), so re-imports skip games you already have.
- **Storage:** everything is local: games (PGN plus metadata: source, result, time control, clocks), Stockfish analysis, AI notes and settings. Deleting a game removes its review and AI notes and drops it from stats.
- **AI Coach:** Gemini, with the user's own API key. The key field is visible only in Developer mode and is kept in secure storage on the device. The agent calls Stockfish as a tool and only states moves it has verified. Show each step live, as the Coach screen does.
  - It never runs without a user tap.
  - With no key or no network, the AI buttons stay visible, and tapping one explains what's needed. Stockfish features keep working.
