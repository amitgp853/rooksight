# MoveWise Design Spec (from Claude Design, "Night Study" v0.1)

Source files from Claude Design are in `design/source/` (templated `.dc.html`,
`motion.css`, `canvas.json`). They are the reference; this file is the summary
to implement from. **Also check `design/screenshots/` for how each screen looks.**

## Direction
Calm system for deliberate practice. Ink-slate surfaces, one cool focus blue
for action, brass only for moments worth remembering (hints, brilliancies,
last move). Dark is default; every token has a light twin. No felt-table
greens, no casino gold.

## Colour tokens
| Token | Use | Dark | Light |
|---|---|---|---|
| bg.base | App background | #0E1217 | #F1F3F6 |
| bg.raised | Cards, rows | #151B22 | #FFFFFF |
| bg.elevated | Inputs, sheets, pressed | #1C242E | #E6EAF0 |
| border | Hairlines, outlines | #2A3441 | #D5DBE3 |
| text.primary | Headings, body | #E9EDF2 | #121820 |
| text.secondary | Supporting copy | #A3AFBD | #4A5563 |
| text.tertiary | Captions, meta | #7C8898 | #5F6B7A |
| accent.focus | Primary action, your side | #86A8FF | #2F5BD3 |
| accent.onFocus | Text on focus fills | #0B1224 | #FFFFFF |
| accent.brass | Hints, brilliancies | #E3B25C | #8A5F0F |

### Semantic (move quality & results)
Quality is never colour alone: every marker shows its symbol.
| Token | Symbol | Meaning | Dark | Light |
|---|---|---|---|---|
| move.brilliant | !! | Rare, surprising best | #E3B25C | #8A5F0F |
| move.best | ! | Engine top choice | #86A8FF | #2F5BD3 |
| move.inaccuracy | ?! | loses 0.5–1.0 pawns | #E3C65C | #7A6200 |
| move.mistake | ? | loses 1.0–2.0 pawns | #F09A55 | #B4531A |
| move.blunder | ?? | loses more than 2.0 pawns | #F2677A | #C22F48 |
| result.win | W | Stats bars | #86A8FF | #2F5BD3 |
| result.draw | D | Stats bars | #7C8898 | #8A94A3 |
| result.loss | L | Stats bars | #F09A55 | #B4531A |

Check glow / illegal flash use **coral** (use move.blunder colour).

## Typography (Google Fonts, bundle them as assets)
| Style | Font | Weight | Size / line height | Tracking |
|---|---|---|---|---|
| display | Sora | 600 | 40 / 44 | −2% |
| title | Sora | 600 | 24 / 30 | |
| heading | Sora | 600 | 17 / 24 | |
| body | Instrument Sans | 400 | 15 / 22 | |
| label | Instrument Sans | 500 | 13 / 18 | |
| overline | Instrument Sans | 600, ALL CAPS | 11 / 16 | +8% |
| mono (moves, clocks) | JetBrains Mono | 500 | 15 / 22 | tabular numbers |

## Spacing & radius
4-pt base. Screen gutters 16; card padding 16–20; sections 24–32 apart.
Radius: xs 6 (quality chips), sm 12 (buttons/inputs), md 16 (cards),
lg 24 (sheets), full (pills). **Chess boards ignore gutters: full width, edge to edge.**

## Components
- Buttons: primary (focus blue), secondary, ghost, destructive, disabled.
  Height 52 (44 min touch target). Brass secondary is used ONLY for Hint.
- Chips: filter chips (pill, height 36); quality chips (radius 6, symbol first).
- Agent step rows (Coach): "done" and "running" states,
  e.g. "Asking Stockfish about move 23…", "Verified best move: Rd1".
- Cards: game card (raised, radius 16), insight card (AI explanation with
  quality chip, eval change "+0.4 → −2.9", best move), stat card with meter.

## Board
- Board spans full screen width (390 → 48.75px squares). Coordinates sit inside edge squares.
- Themes (light / dark squares; last-move tint light / dark):
  - slate (default): #CDD5E0 / #6B7C94; tint #E8D9A4 / #B39962
  - ink (high contrast): #D9DEE5 / #46536B; tint #E8D9A4 / #8F7C52
  - dusk: #DED7E9 / #7C6E9B; tint #ECDDB2 / #A88E74
  - ember (warm): #EEDFCF / #B47A5E; tint #F0DC9E / #C49A55
- Overlays: last move = brass tint; selected = focus-blue fill; legal moves =
  dots (rgba(14,18,23,0.32), 30% of square); captures = rings; castling via
  rook = dashed brass ring; hint = brass arrow (opacity 0.92); best move in
  review = focus-blue ring; check = coral glow; quality badge = symbol disc top-right.
- Pieces: custom MoveWise set, `design/pieces/*.svg` (48-unit grid, drawn at
  90% of the square, centred, drop shadow 0 1.5 1.5 rgba(0,0,0,0.35)).
  White = porcelain #F5F7FA with 1.5px ink outline; black = ink #1E2530 with pale rim.

## Screens (design/source)
1 Home (+ light mode) · 2 Play setup (Stockfish strength slider, big Elo number)
· 3 Game · 4 Game review · 5 Coach chat · 6 Weakness stats · 7 Report card
share (export image 1080×1350) · 8 Settings (Chess.com username + Import,
Gemini key, board theme picker) · Result cards for all 7 endings.

## Motion spec (per interaction)
Default curve for moves: Cubic(0.22, 0.9, 0.3, 1). Keyframes in `design/source/motion.css`.

- **TAP A PIECE**: Square fills focus blue. Dots on empty legal squares, rings on capturable pieces (Nf3 can take e5). Pop-in 120ms, easeOutCubic (scale 0.3 → 1). Tap again or elsewhere: fade out 90ms. Haptic: selectionClick.
- **DRAG**: Lift 100ms: scale 1 → 1.1, shadow 2 → 10px blur. The piece rides 0.4 square above the finger so it's never hidden. The origin keeps a 28% ghost. The square under the finger gets a 4px light ring (instant).
- **MOVE — Bc1–g5**: Slide 200ms, Cubic(0.22, 0.9, 0.3, 1). A drop from drag slides from the release point instead of the origin. Clock hands over as the piece lands. Haptic: lightImpact.
- **ILLEGAL — Nf3 dropped on f5**: Snap back 150ms (easeOutCubic), then shake ±5 / ±5 / ±3 px over 200ms. Origin square flashes coral: 70ms in, 400ms out. Haptic: mediumImpact.
- **LAST MOVE**: From- and to-squares keep a soft brass tint until the next move (fades in 120ms). Same tint in every board theme, so it never changes meaning.
- **CAPTURE — Bxf6**: Attacker slides 200ms. Captured knight fades + shrinks to 0.55 over 190ms, starting 100ms before the attacker lands. The knight joins the tray under your name and +3 appears (150ms fade).
- **CASTLING — targets**: Selecting the king shows a dot on g1 (two-square move) and a dashed brass ring on the h1 rook: dropping the king on its rook castles too. f1 is an ordinary king step.
- **CASTLING — O-O**: King e1 → g1 and rook h1 → f1 slide together as one 240ms animation, easeOutCubic. One haptic (lightImpact), one move in the list.
- **EN PASSANT — exd6**: Pawn slides diagonally (200ms). The d5 pawn beside it fades + shrinks, same 190ms curve as any capture. Move list marks it “e.p.”
- **PROMOTION PICKER**: Pawn reaches b8: board dims to 58%, picker grows from that square (160ms). Queen first and largest, pre-highlighted, then rook, bishop, knight, cancel. For Black the picker grows upward from rank 1.
- **PROMOTION — b8=Q#**: Pawn shrinks out (120ms), queen grows 0.6 → 1.08 → 1 (200ms, easeOutBack). This promotion is also mate, so the g8 king pulses coral as the queen lands.
- **CHECK — …Bxf2+**: King square pulses once as the bishop lands (0 → 1 → 0.45 → 1 over 360ms), then stays tinted until the check is resolved. Your name line reads “In check”. Haptic: heavyImpact.
- **STOCKFISH THINKING**: Three dots bob beside the name (1200ms loop, 150ms stagger). Shown only after 300ms, so instant replies don't flicker. Stockfish's clock is the running one.
- **ENGINE MOVE — …d6**: Exactly the player's move: 200ms slide, same curve, same last-move tint. Minimum 400ms think time before it plays.
- **HINT**: Brass arrow draws from piece to target in 360ms (easeOutCubic); the head appears in the last 100ms. Hint text fades in under the board. Arrow clears on your next move.
- **CLOCKS**: Under 30s: brass (fill when running, digits + outline when idle). Under 10s: coral, breathing 1 → 0.7 opacity once a second. Colour change is a 200ms tween. Haptic tick at 10s.
- **FLIP BOARD**: Board rotates 180° over 300ms (easeInOutCubic) while each piece counter-rotates to stay upright. Coordinates swap at the midpoint; the name rows swap with the board.
- **OPTIONS**: More → sheet slides up 320ms, scrim to 55% in 200ms. Offer draw and Resign live here. Undo works only in practice mode: in a normal game it shows locked, and the sheet offers to switch practice on.
- **GAME OVER**: Hold 600ms on the final position, then the result sheet slides up (320ms) over a 55% scrim. Primary: Review with AI coach. Secondary: Rematch, Share report card. All 7 endings → right.
- **Every frame on this page is this one component. Open its Tweaks to switch state and full / reduced motion.**: 
- **DRAG (reduced)**: No scale-up. The lift shows through shadow and the origin ghost only.
- **MOVE (reduced)**: No travel: the piece fades out at c1 and in at g5, together, 150ms.
- **ILLEGAL (reduced)**: No shake. The piece fades back to f3 (150ms) and the square flashes coral. Haptic still fires.
- **CAPTURE (reduced)**: Knight fades out as the bishop fades in, 150ms. No shrink.
- **CASTLING (reduced)**: King and rook crossfade to their new squares together, 150ms.
- **EN PASSANT (reduced)**: Pawn crossfades to d6; the captured pawn fades, 150ms.
- **PROMOTION PICKER (reduced)**: Dim and picker fade in (150ms). No grow.
- **PROMOTION (reduced)**: Pawn → queen crossfade, 150ms. No overshoot.
- **CHECK (reduced)**: The coral tint fades in and stays. No pulse.
- **THINKING (reduced)**: Static “Thinking…” chip instead of bouncing dots.
- **HINT (reduced)**: The whole arrow and the hint text fade in (150ms). No drawing.
- **CLOCKS (reduced)**: Same colours at 30s and 10s. No breathing.
- **GAME OVER (reduced)**: Same 600ms hold, then sheet and scrim fade in (200ms). No slide.
