# MoveWise — design handoff for Flutter

AI chess coach. No login. Play Stockfish or import Chess.com games; an AI coach (Gemini, every move claim checked by Stockfish) explains mistakes. Mobile-first, dark by default, light mode available.

The `design/` folder holds the source of every artboard (`*.dc.html`: HTML with inline styles, `{{placeholders}}` filled by a small script block at the bottom) plus `motion.css`. They don't render on their own in a browser; view them on the MoveWise design canvas. Treat the source as the visual spec: copy exact colours, sizes, radii and copy text from it.

## Screens → design files

| # | Screen | File |
|---|---|---|
| — | Design system | `Main.dc.html` |
| — | Board component (all overlays) | `Board.dc.html` |
| 1 | Home (dark / light) | `Home.dc.html`, `HomeLight.dc.html` |
| 2 | Play setup (Elo 400–3000 step 200, colour, time) | `PlaySetup.dc.html` |
| 3 | Game | `Game.dc.html`, and every state in `GameScreen.dc.html` |
| 4 | Game review | `Review.dc.html` |
| 5 | Coach chat (live agent steps) | `Coach.dc.html` |
| 6 | Weakness stats | `Stats.dc.html` |
| 7 | Report card (share screen + 1080×1350 image) | `ShareReport.dc.html`, `ReportCard.dc.html` |
| 8 | Settings | `Settings.dc.html` |
| — | Game interaction states | `IX01…IX19-*.dc.html` (full motion), `RM01…RM13-*.dc.html` (reduced motion) |
| — | Result card, all endings | `ResultCards.dc.html` |
| — | Logo: directions, chosen mark, home screen, adaptive icon, monochrome | `LogoDir1-9`, `LogoChosen`, `LogoHome`, `LogoAdaptive`, `LogoMono` `.dc.html` |
| — | Motion timings table | `MotionSpec.dc.html` |

`GameScreen.dc.html` contains a table (`var S = {...}`) with the exact board state for every interaction frame. It's useful for test positions too.

## Logo (direction 9A, "the analyst's rook")

A rook (chess) whose three battlements rise like a bar chart (analysis); the tallest bar is brass (the best move) and a four-point spark is cut into the tower (the AI coach). Source: `Logo.dc.html` (variant `brand` = `9a`) and the `Logo*.dc.html` frames. Ready-made files are in `logo/`:

- `app_icon_dark.svg` / `app_icon_1024.png`: full app icon, tile #151B22, for iOS and the Play Store.
- `adaptive_foreground.svg` / `adaptive_foreground_432.png`: Android adaptive icon foreground (rook at 64%, inside the 66dp safe zone). Background layer = solid #151B22.
- `adaptive_monochrome.svg` / `adaptive_monochrome_432.png`: Android 13+ themed icon layer (spark is a real cut-out).
- `mark_dark.svg`, `mark_light.svg`, `mark_mono.svg`: the mark for in-app headers, light backgrounds and favicons.

With `flutter_launcher_icons`: `image_path: logo/app_icon_1024.png`, `adaptive_icon_background: "#151B22"`, `adaptive_icon_foreground: logo/adaptive_foreground_432.png`, `adaptive_icon_monochrome: logo/adaptive_monochrome_432.png`.
Wordmark: "MoveWise" in Sora 600, tracking −2.5%, beside the icon.

## Splash screens

Everything is in `splash/`:

- `splash_logo_light.png`, `splash_logo_dark.png` (592×592): the rook, centred on #F1F3F6 / #0E1217. Shows at 148 dp.
- `android12_icon_light.png`, `android12_icon_dark.png` (960×960): Android 12+ splash icon, rook inside the 640 px circle, on an icon background of #FFFFFF / #151B22.
- `branding_light.png`, `branding_dark.png` (800×200): the "MoveWise" wordmark shown at the bottom.
- `flutter_native_splash.yaml`: ready-made config. Copy the PNGs to `assets/splash/`, add the block to `pubspec.yaml` (or keep it as its own file), then run `dart run flutter_native_splash:create`.
- `movewise_intro.dart`: optional animated intro (about 1.2 s) that runs right after the native splash: the tower appears, the three battlements rise one by one, the AI spark pops in and the wordmark fades up. The logo sits in the same spot as the native splash, so the hand-off is seamless. It respects reduced motion. Needs the Sora font registered in `pubspec.yaml`.

Canvas frames: `SplashDark`, `SplashLight`, `SplashA12Dark`, `SplashA12Light`, `SplashIntro` `.dc.html`.

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

Checkmate (win/loss), stalemate, threefold repetition, 50-move rule, insufficient material, resignation, timeout. Actions: **Review with AI coach** (primary), Rematch, Share report card.

## Data and engines

- Chess rules: a Dart chess logic package (legal moves, FEN/PGN, draw detection).
- Engine: Stockfish on-device via a pub.dev Stockfish package (UCI). Elo levels 400–3000 map to `UCI_LimitStrength` / `UCI_Elo` (Stockfish's own floor is ~1320; below that use Skill Level + shallow depth).
- Chess.com import: public API, no auth: `https://api.chess.com/pub/player/{username}/games/archives`, then each monthly archive URL returns PGNs.
- Coach: Gemini with the user's own API key, stored in secure storage on device. The coach agent calls Stockfish as a tool and only states moves it has verified. Show each step live, as the Coach screen does.
