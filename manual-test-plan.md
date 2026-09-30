# MoveWise — Manual Test Plan

Tick each box as you go. **Expect** is what should happen; anything else is a bug.
IDs (e.g. `PLAY-07`) are there so you can note bugs as "PLAY-07 fails: …".

## 0. Before you start

- [ ] **SETUP-01** Run a debug build with your key: `flutter run --dart-define-from-file=.env`.
- [ ] **SETUP-02** Have ready: a Chess.com username with recent games (e.g. your own), a Lichess
      username, a username that doesn't exist (e.g. `zz_no_such_user_918273`), and a valid Gemini key.
- [ ] **SETUP-03** For first-run tests: uninstall the app (or clear its data) so it starts empty.
- [ ] **SETUP-04** Test on at least one Android and one iOS device if you can. Test a small phone as well as a large one.

## 1. Smoke test (15 min, run after every big change)

- [ ] **SMOKE-01** App launches: splash, then intro, then Home. No red error screens.
- [ ] **SMOKE-02** Play vs Computer at 800, make 5 moves, then resign. The result sheet appears.
- [ ] **SMOKE-03** "Review with AI Coach": the Stockfish analysis finishes and key moments show.
- [ ] **SMOKE-04** Tap "Explain key moments": the AI explanations appear.
- [ ] **SMOKE-05** Import 1 month from Chess.com: games appear in Games.
- [ ] **SMOKE-06** AI Coach: ask "What should I work on first?". Live steps show, then an answer.
- [ ] **SMOKE-07** Stats opens and shows numbers.
- [ ] **SMOKE-08** Report card: "Share image" opens the share sheet.
- [ ] **SMOKE-09** Kill the app and reopen it: everything above is still there.

---

## 2. Launch, splash and intro

- [ ] **LAUNCH-01** Cold start in phone dark mode. **Expect:** the native splash and the intro's first frame have the same background (no flash), and the intro is about 1.5 s: tower, battlements rise, spark, "MoveWise" / "Your AI Chess Coach".
- [ ] **LAUNCH-02** Cold start in phone light mode. **Expect:** light splash → light intro, no flash.
- [ ] **LAUNCH-03** Set in-app Appearance to Dark while the phone is in Light, then relaunch. **Expect:** the intro starts light and blends to dark, and Home is dark.
- [ ] **LAUNCH-04** Turn on the phone's reduce-motion setting (iOS: Reduce Motion; Android: Remove animations), then relaunch. **Expect:** the finished logo shows briefly (~0.4 s) with a fade and no drawing animation.
- [ ] **LAUNCH-05** On a fresh install (no games). **Expect:** Home shows no "Continue game" card, and Games/Stats show their empty states.
- [ ] **LAUNCH-06** Rotate the phone and use split screen on Android. **Expect:** no overflow stripes (yellow/black).

## 3. Home

- [ ] **HOME-01** Tiles: Play vs Computer ("Stockfish, 400 to 3000 Elo"), Pass & Play, Import Games, AI Coach, Stats, Games. Each one opens the right screen.
- [ ] **HOME-02** The Settings icon opens Settings.
- [ ] **HOME-03** Leave a Stockfish game mid-way (back button). **Expect:** a "Continue game" card: "vs Stockfish · <elo> · move N · your turn / Stockfish to move". "Resume" restores the same position and clocks.
- [ ] **HOME-04** Same as HOME-03 with Pass & Play. **Expect:** the card shows "<White> vs <Black> · Pass & Play · <name> to move".
- [ ] **HOME-05** Leave a practice game. **Expect:** the card shows "practice".
- [ ] **HOME-06** The Stats tile shows "TOP WEAKNESS …" once reviewed games exist. Otherwise it shows "Review a few games to find your patterns."
- [ ] **HOME-07** The Games tile count ("N saved") matches the Games list.
- [ ] **HOME-08** Android back on Home exits the app. It doesn't go to a blank screen.

## 4. Play vs Computer — setup

- [ ] **SETUP-P-01** Default: 1600 Elo, White, 10+0 (first run).
- [ ] **SETUP-P-02** The −/+ buttons change Elo by 200. The minimum is 400 and the maximum 3000; the buttons stop or disable at the ends.
- [ ] **SETUP-P-03** Drag the slider: it snaps to steps of 200 and the label follows.
- [ ] **SETUP-P-04** Play as White / Random / Black. Random gives both colours over several games.
- [ ] **SETUP-P-05** Clocks: 3+2, 5+0, 10+0, 15+10, 30+0, No clock. Summary line reads e.g. "Stockfish 1600 · you play White · your clock 10+0".
- [ ] **SETUP-P-06** Choose 1200, Black, 5+0, then start, leave the game and reopen setup. **Expect:** your choices are remembered, even after an app restart.
- [ ] **SETUP-P-07** With an unfinished game, tap "Start game". **Expect:** the "Abandon your current game?" dialog appears. "Keep it" does nothing; "Start new game" starts fresh and the old card disappears from Home.

## 5. Play vs Computer — the board

**Moving pieces**
- [ ] **PLAY-01** Tap a piece: it is selected and legal-move dots show. Tap a dot to move.
- [ ] **PLAY-02** Drag a piece: it lifts while dragged, lands without sliding, and legal dots show.
- [ ] **PLAY-03** Tap a piece, then tap another of your own pieces. **Expect:** the selection switches.
- [ ] **PLAY-04** Try an illegal move (e.g. a rook through a pawn). **Expect:** it is rejected with the illegal-move feedback (shake/haptic per spec) and the piece returns.
- [ ] **PLAY-05** You can't move during Stockfish's turn, and you can't move the opponent's pieces.
- [ ] **PLAY-06** Last-move highlight and check highlight on the king are visible.
- [ ] **PLAY-07** The captured-pieces tray updates ("No captures yet" at start).
- [ ] **PLAY-08** The move strip shows SAN moves and scrolls to the latest.

**Engine**
- [ ] **PLAY-10** At every level, Stockfish's reply takes at least ~0.4 s (never instant). The thinking dots appear only if it takes over 0.3 s.
- [ ] **PLAY-11** Play as Black. **Expect:** Stockfish makes the first move by itself and the board is oriented with Black at the bottom.
- [ ] **PLAY-12** 400 Elo: it plays noticeably weak moves and hangs pieces sometimes.
- [ ] **PLAY-13** 1200 vs 1400: both play reasonably (the switch point between manual weakening and `UCI_Elo`).
- [ ] **PLAY-14** 3000: strong play, replies within ~1.5 s, and the UI never freezes while it thinks (try scrolling the move strip).
- [ ] **PLAY-15** Move quickly several times in a row. **Expect:** no duplicated or skipped engine moves and no stuck "thinking".

**Action bar (Hint · Undo · Flip · More)**
- [ ] **PLAY-20** Hint on your turn shows a hint (arrow/text). Tapping Hint again doesn't stack hints, and making a move clears the hint.
- [ ] **PLAY-21** Undo is locked in a normal game.
- [ ] **PLAY-22** More → "Turn on practice mode" enables Undo ("Unlocks Undo for this game"). Undo takes back to your last turn (both your move and Stockfish's).
- [ ] **PLAY-23** Undo repeatedly back to move 0. **Expect:** the clock stops and waits for White's first move again.
- [ ] **PLAY-24** Undo while Stockfish is thinking. **Expect:** its pending reply is dropped and no ghost move appears.
- [ ] **PLAY-25** Flip rotates the board with animation; flip again to restore it. Moves still work while flipped.
- [ ] **PLAY-26** More → "Offer draw" before move 30. **Expect:** "Stockfish declined the draw."
- [ ] **PLAY-27** Offer a draw after move 30 in a level position (at a low Elo, trade down to an equal endgame). **Expect:** a "Draw agreed" result. In a position where Stockfish is winning, it declines.
- [ ] **PLAY-28** More → Resign. **Expect:** the result sheet says "You resigned" with the move number.

**Clock**
- [ ] **PLAY-30** The clock doesn't start until White's first move.
- [ ] **PLAY-31** 3+2: the increment adds 2 s after each of your moves.
- [ ] **PLAY-32** Your clock under 30 s shows the warning colour. Under 10 s it shows the critical colour, and at low time there's a haptic.
- [ ] **PLAY-33** Let your clock run out. **Expect:** "Stockfish won on time" / "Your clock ran out on move N".
- [ ] **PLAY-34** Time out when Stockfish has only a bare king. **Expect:** "Draw · Your clock ran out, but Stockfish can't mate." (Hard to set up; optional.)
- [ ] **PLAY-35** "No clock": no clocks are shown and nothing times out.
- [ ] **PLAY-36** Send the app to the background for 30 s mid-game, then return. **Expect:** your clock didn't run while it was hidden.
- [ ] **PLAY-37** Lock the screen on your turn, then unlock. Same result as PLAY-36.

**Resume and persistence**
- [ ] **PLAY-40** Make moves, then force-kill the app. Reopen it and tap Resume. **Expect:** the same position, clocks, hints and practice mode.
- [ ] **PLAY-41** Kill the app while Stockfish is thinking, then resume. **Expect:** Stockfish moves again. It doesn't hang.

## 6. Game end and result sheet

- [ ] **END-01** Win by checkmate (at 400 Elo). **Expect:** the final position holds ~0.6 s, then a "Checkmate · You won · You mated with …" sheet.
- [ ] **END-02** Get mated. **Expect:** "Stockfish won · Mate after …".
- [ ] **END-03** Dismiss the sheet. **Expect:** a "See result" link reopens it.
- [ ] **END-04** "Review with AI Coach" opens this game's review.
- [ ] **END-05** "Rematch" starts a fresh board with the same settings.
- [ ] **END-06** "Share report card" opens the report card for this game.
- [ ] **END-07** The finished game appears in Games straight away. A game resigned with zero moves is **not** saved.
- [ ] **END-08** In practice mode, finish, then undo and finish again. **Expect:** only **one** record in Games (it replaced the first), and it's labelled "Practice".
- [ ] **END-09** Sounds: separate sounds for move, capture, castle and check. Turn Sound off in Settings: everything is silent.

## 7. Chess rules (use Pass & Play: you control both sides)

Start Pass & Play with "Flip board after each move" **off**, so it's easier to test.

- [ ] **RULE-01 Fool's mate:** 1.f3 e5 2.g4 Qh4#. **Expect:** Checkmate, Black wins.
- [ ] **RULE-02 Scholar's mate:** 1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6 4.Qxf7#. **Expect:** Checkmate, White wins.
- [ ] **RULE-03 Kingside castling:** 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5, then drag the king e1→g1. **Expect:** the rook jumps to f1 with the castle sound. Also try tapping the king and then the rook.
- [ ] **RULE-04 Queenside castling:** 1.d4 d5 2.Nc3 Nc6 3.Bf4 Bf5 4.Qd2 Qd7 5.O-O-O. **Expect:** the king lands on c1 and the rook on d1.
- [ ] **RULE-05 No castling through check:** 1.e4 b6 2.Nf3 Ba6 3.g3 Nc6 4.Bg2 e6. **Expect:** White can't castle kingside (the a6 bishop attacks f1).
- [ ] **RULE-06 Castling rights lost:** move the king out and back (Ke2, Ke1). **Expect:** castling isn't offered any more.
- [ ] **RULE-07 En passant:** 1.e4 a6 2.e5 d5 3.exd6. **Expect:** the d5 pawn disappears. If you play another move first, en passant is no longer offered.
- [ ] **RULE-08 Promotion:** 1.a4 b5 2.axb5 a6 3.bxa6 Bb7 4.axb7 Nc6 5.bxa8. **Expect:** a picker with Q, R, B, N. Choose Q.
- [ ] **RULE-09 Under-promotion:** repeat RULE-08 and choose N. **Expect:** a knight appears. Try cancelling the picker (tap outside): the pawn stays.
- [ ] **RULE-10 Pinned piece:** 1.d4 e5 2.dxe5 Bb4+ 3.Nc3 Nc6. **Expect:** the c3 knight can't move.
- [ ] **RULE-11 Must answer check:** 1.e4 f6 2.Qh5+. **Expect:** only moves that stop the check are allowed (g6); other moves are rejected.
- [ ] **RULE-12 Stalemate:** 1.e3 a5 2.Qh5 Ra6 3.Qxa5 h5 4.h4 Rah6 5.Qxc7 f6 6.Qxd7+ Kf7 7.Qxb7 Qd3 8.Qxb8 Qh7 9.Qxc8 Kg6 10.Qe6. **Expect:** Stalemate, Draw.
- [ ] **RULE-13 Threefold repetition:** 1.Nf3 Nf6 2.Ng1 Ng8 3.Nf3 Nf6 4.Ng1 Ng8. **Expect:** Draw, "The same position appeared three times."
- [ ] **RULE-14 Insufficient material** (optional, long): trade down to K vs K or K+B vs K. **Expect:** an automatic draw.
- [ ] **RULE-15** Replay RULE-01, 07 and 08 against Stockfish when the chance arises. The same rules should apply in the vs-computer screen.

## 8. Pass & Play

**Setup**
- [ ] **PASS-01** Default names "You" / "Opponent", clock 10+5, "Flip board after each move" on.
- [ ] **PASS-02** Edit the names. Clear a name to blank. **Expect:** blank falls back to the default name.
- [ ] **PASS-03** "Swap colours" swaps who plays White, and "Pick colours at random" works. The start button says "Start · <name> plays White".
- [ ] **PASS-04** Turning on "Face-to-face layout" turns off "Flip board", and the reverse.
- [ ] **PASS-05** Settings are remembered next time (even after a restart).
- [ ] **PASS-06** With an unfinished pass game, starting a new one shows "Abandon your current game?".

**Playing**
- [ ] **PASS-10** Auto-flip on: after each move the board turns and shows "Board turned for <name>. Pass the phone."
- [ ] **PASS-11** Face-to-face: the top half is rotated 180° for the other player, and each side's controls work from their side.
- [ ] **PASS-12** Clocks: the first clock starts after White's first move, and the increment applies.
- [ ] **PASS-13** Pause: both clocks stop and the board is **hidden** ("Game paused"). "Resume · <name> to move" continues.
- [ ] **PASS-14** "Save and finish later" from the pause screen returns to Home with a Continue card that resumes correctly.
- [ ] **PASS-15** Background the app: it pauses by itself.
- [ ] **PASS-16** Takeback (with "Allow takebacks" on): the other player sees "Allow takeback" / "Decline". The clocks keep running while they decide. Accepting reverts the move; declining shows "<name> declined the takeback."
- [ ] **PASS-17** With "Allow takebacks" off, the Takeback button is hidden or disabled.
- [ ] **PASS-18** Draw offer: the other player can accept (Draw agreed) or decline ("<name> declined the draw.").
- [ ] **PASS-19** Resign: "<name> resigned on move N."
- [ ] **PASS-20** Timeout: "<name> wins on time".

**Result**
- [ ] **PASS-30** The result sheet shows "Saved to Your games", "Review with AI Coach", "Rematch · swap colours" and "Share report card".
- [ ] **PASS-31** Rematch swaps colours.
- [ ] **PASS-32** In Games, the game shows as "<name> · pass & play". Reviewing it treats the first player as "You".

## 9. Import games

**Chess.com**
- [ ] **IMP-01** Open Import. Chess.com is selected, with the "How far back" options Last month / 3 months / 12 months / Everything. The date caption reads e.g. "Since Jul 2026".
- [ ] **IMP-02** The Import button is disabled while the username is empty.
- [ ] **IMP-03** Import your username with "Last month". **Expect:** progress reads "Looking up …" → "Month 1 of 1 · N games so far" with a %, the form stays dimmed, and it ends with "N imported · From Chess.com, last month."
- [ ] **IMP-04** Run the same import again. **Expect:** "0 imported" and "N you already had were skipped."
- [ ] **IMP-05** "Last 12 months". **Expect:** it steps through month by month (sequentially), with no errors.
- [ ] **IMP-06** "Cancel import" mid-way. **Expect:** "Import stopped · N imported before you stopped." Those games are in Games.
- [ ] **IMP-07** Unknown username. **Expect:** "No Chess.com player called "…". Check the spelling and try again." Editing the field clears the message.
- [ ] **IMP-08** A user with no games in the period (or a new account). **Expect:** "No games found".
- [ ] **IMP-09** The username is saved: it's there when you reopen Import and in Settings → Game import.
- [ ] **IMP-10** Usernames with capitals or spaces around them are accepted.
- [ ] **IMP-11** Variant or daily games: variants are left out ("N variant or unfinished games left out"). Daily games show "Daily".

**Lichess**
- [ ] **IMP-20** Switch to Lichess: it keeps its own username, separate from Chess.com.
- [ ] **IMP-21** Import from Lichess. Progress shows "N games so far" (a count, not months).
- [ ] **IMP-22** Re-import: already-saved games are skipped.
- [ ] **IMP-23** Home's Import tile says "Chess.com · Lichess". The Games empty state has "Import from Chess.com or Lichess".

**Errors and network**
- [ ] **IMP-30** Airplane mode, then Import. **Expect:** "You're offline · Importing needs the internet. Your saved games, Stockfish and pass & play still work."
- [ ] **IMP-31** Turn off Wi-Fi mid-import. **Expect:** an offline/error message. Games already fetched are kept.
- [ ] **IMP-32** Rate limit (hard to force; try "Everything" on a big account). **Expect:** "Import paused", "<site> asked us to slow down", a countdown, and it carries on by itself. "Try now" skips the wait.
- [ ] **IMP-33** Leave the Import screen mid-import and come back. **Expect:** progress continues or is shown correctly, and there's no duplicate import.
- [ ] **IMP-34** After finishing, "See your games" opens Games and "Import more" resets the form.

## 10. Games list

- [ ] **GAMES-01** Empty state: "No games yet" with "Play vs Computer" and "Import from Chess.com or Lichess" buttons.
- [ ] **GAMES-02** Newest first. Each row shows opponent, source (MoveWise / Chess.com / Lichess), result colour, time control, end reason, date and move count.
- [ ] **GAMES-03** The All / Won / Lost filters work. Empty filters show "No wins here yet." / "No losses here."
- [ ] **GAMES-04** Tap a game: its review opens.
- [ ] **GAMES-05** Delete (swipe or menu) opens the "Delete this game?" sheet, which says its review and AI notes are deleted and it won't count in stats. "Cancel" keeps it; "Delete game" removes it.
- [ ] **GAMES-06** After deleting, Stats and the Home count update, and a Coach chat that referenced it shows "Game deleted".
- [ ] **GAMES-07** Scroll with 200+ games (after a big import): scrolling stays smooth.

## 11. Game review

**Analysis**
- [ ] **REV-01** Open an unreviewed game. **Expect:** "Analysing with Stockfish · Move N of M · you can look around meanwhile", and you can step through moves while it runs.
- [ ] **REV-02** Leave mid-analysis and come back. **Expect:** it resumes or finishes without a crash.
- [ ] **REV-03** Once done, you see the eval graph, eval bar, accuracy for both sides, a "Summary", "Work on" and key moments ("N of M moves").
- [ ] **REV-04** Reopen a reviewed game. **Expect:** it loads instantly with no re-analysis.
- [ ] **REV-05** Settings → review depth Fast (14) / Balanced (18) / Deep (22). Deep is noticeably slower on a new game.
- [ ] **REV-06** A clean short game. **Expect:** "No big mistakes and no standout finds: a steady game."

**Navigation**
- [ ] **REV-10** First / Previous / Next / Last buttons work. The header shows "<move> · move X of Y".
- [ ] **REV-11** Tap a point on the eval graph to jump to that move.
- [ ] **REV-12** Move table filters: All / Blunders / Mistakes / Inaccuracies / Good moves. An empty filter shows "No moves like that in this game."
- [ ] **REV-13** Quality marks: ?? blunder, ? mistake, ?! inaccuracy, ! best, !! brilliant. Spot-check that one blunder really loses 2+ pawns (the eval bar jumps).
- [ ] **REV-14** Opening at a specific move from Stats ("See N games") lands on that move.

**Key moments and your own lines**
- [ ] **REV-20** Key moment card: "Show best move" draws the arrow, and "Read more" expands the text.
- [ ] **REV-21** "Play the best move" plays Stockfish's line ("Stockfish's line · 1 of N"). "Back to the game" returns.
- [ ] **REV-22** Move a piece on the review board. **Expect:** "Your line" appears, and Stockfish rates your move ("Stockfish is checking…" → "Good move · +0.3" or "Mistake · …").
- [ ] **REV-23** "Back to key moments" / "Back to moves" return you to where you were.
- [ ] **REV-24** "Ask AI Coach about this move" opens the Coach with a prefilled question ("What went wrong with …, and what should I have played?").

**AI explanations (1 LLM call per review)**
- [ ] **REV-30** Tap "Explain key moments". **Expect:** "Asking AI about N moments…", then each card shows "Explained by AI", with "Explained by AI · moves and claims checked" at the bottom.
- [ ] **REV-31** Leave and reopen the review. **Expect:** explanations are still there with no new AI call (the cache works; check the key usage in AI Studio if you want to be sure).
- [ ] **REV-32** "Explain again" makes a fresh request.
- [ ] **REV-33** Every move named in an explanation exists in that position (spot-check 3).
- [ ] **REV-34** Airplane mode, then Explain. **Expect:** "Couldn't reach the AI. Check your connection." and a "Try again" button.
- [ ] **REV-35** Stockfish analysis itself works offline.

**Menu**
- [ ] **REV-40** "Ask AI Coach about this game" opens the Coach with the game attached.
- [ ] **REV-41** "Share report card" opens the report card.
- [ ] **REV-42** "Delete game" goes back to the list with the game gone.
- [ ] **REV-43** Open a review link for a deleted game (e.g. via a Coach chat). **Expect:** "This game couldn't be found."
- [ ] **REV-44** Step to a move and tap "Analyze this position". **Expect:** the analysis board opens on that move ("From your game · after …"), the game as its main line. Back returns to the same move.

## 11b. Scan a board and the analysis board

**Camera and crop** (needs a real phone)
- [ ] **SCAN-01** Home → "Scan a board". First time: the camera permission prompt. **Expect:** a dimmed preview with a square frame and "Fit the whole board inside the frame".
- [ ] **SCAN-02** Deny the camera. **Expect:** a message and "Upload a photo"; picking a photo reaches the crop.
- [ ] **SCAN-03** Flash turns the torch on and off; "Tips for a good scan" opens the tips sheet; tapping the preview focuses.
- [ ] **SCAN-04** Take a photo. **Expect:** a white flash (none with Reduce motion), then "Crop to the board". Drag a corner: the frame follows, then snaps back to a square. Rotate left/right turn the photo.
- [ ] **SCAN-05** The gallery button opens your photos; a book diagram works as well as a real board.

**Reading** (needs a Gemini key)
- [ ] **SCAN-10** "Scan board". **Expect:** "Reading your board" with a sweeping line and the steps appearing one by one (Finding the board → Identifying pieces → Checking the position is legal), then "Position ready".
- [ ] **SCAN-11** A board with a shadowy square (or a real misread). **Expect:** a brass "Double-checking e1 and g1…" step.
- [ ] **SCAN-12** "Cancel" mid-scan returns to the crop; nothing arrives later.
- [ ] **SCAN-13** A photo with no board (e.g. a wall). **Expect:** "We couldn't find a board" with tips, "Try again" and "Upload a photo".
- [ ] **SCAN-14** A very dark photo. **Expect:** "Too dark or too blurry".
- [ ] **SCAN-15** Airplane mode. **Expect:** "You're offline", "Set up the position by hand" and "Try again".
- [ ] **SCAN-16** Remove the key in Settings, scan. **Expect:** "Scanning needs your AI Coach key"; "Add key in Settings" opens Settings with Developer mode on; after saving a key and coming back, the scan carries on.

**Check the position**
- [ ] **SCAN-20** Doubtful squares have a brass ring and "?"; the banner names them. Tap the photo thumbnail: photo and board side by side; tap either to go back.
- [ ] **SCAN-21** Tap a square: the editor opens with it selected; pick a piece to place it there. The eraser removes pieces; tapping the same piece again removes it.
- [ ] **SCAN-22** Put a second white king on the board. **Expect:** a coral banner ("Each side needs exactly one king. White has two, on …"), coral rings, and Analyze disabled. "Reset to detected" brings the scan back.
- [ ] **SCAN-23** Side to move, castling (only offered when king and rook are at home) and "White is at the bottom" (turns the board round) all end up in the analysis.
- [ ] **SCAN-24** Error screen → "Set up the position by hand": an empty board in the editor; Analyze stays off until both kings are placed.

**Analysis board**
- [ ] **AN-01** Analyze. **Expect:** "From your scan · White to move", the eval bar with a signed number (+0.4 / −1.8 / M3), the win/draw/loss strip, three lines filling in, "thinking · depth N / 24" with a breathing dot, then "depth 24".
- [ ] **AN-02** The blue best-move arrow appears once depth reaches 12.
- [ ] **AN-03** Play a bad move. **Expect:** a chip pops on its square, and the feedback card ("?? Blunder · 7. Nxe5 +0.4 → −1.8 · Best was 7. Bg5") with "Take back", which removes it.
- [ ] **AN-04** Go back a move and play something else: it becomes a variation, indented under the move it replaces. Long-press it: Promote to main line / Copy line / Delete from here.
- [ ] **AN-05** Tap a move inside an engine line: the line up to it is played on the board.
- [ ] **AN-06** Threat on: a coral arrow and "Threat: …Na5, going after your bishop on c4" (or similar). Off hides both.
- [ ] **AN-07** Engine switch off: lines, arrows and the bar stop; on: they resume.
- [ ] **AN-08** ⋯ menu: Ask AI Coach (question prefilled with the FEN), Play from here vs Stockfish (setup opens with you as the side to move; the game starts from this position), Flip board, Edit position (back in the editor; Analyze returns with the new position), Copy FEN, Share position image.
- [ ] **AN-09** Stockfish analysis on the board works in airplane mode.

## 12. AI Coach

**Asking**
- [ ] **COACH-01** New chat shows the empty state, "TRY ASKING" suggestions ("Why do I keep losing?", …) and the "Ask about a move or a pattern…" hint.
- [ ] **COACH-02** Tap a suggestion to send it. **Expect:** live steps appear one by one ("Checking your last 20 games…", "Asking Stockfish about move 23…", "Verified best move: Rd1") with a "Working…" header, which then collapses to "Worked through N steps".
- [ ] **COACH-03** The answer shows a headline and body, an optional "Try this:", and a move card ("played → best", opponent, date). Tapping the move card opens that game's review at that move.
- [ ] **COACH-04** Tap + → "Ask about a game" picker: search by opponent works and reviewed games are marked "Reviewed". Pick one: the chip "Game: vs …" shows and the suggestions change to game questions.
- [ ] **COACH-05** Remove the attached game with ✕ ("Remove the game").
- [ ] **COACH-06** Ask about an **unreviewed** game. **Expect:** the coach says it isn't reviewed yet, or handles it gracefully. It doesn't invent moves.
- [ ] **COACH-07** Off-topic ("What's the capital of France?"). **Expect:** "I can only help with chess" with an example question.
- [ ] **COACH-08** A question that needs many tool calls ("Compare all my games and analyse every blunder"). **Expect:** at most 5 tool steps, then a final answer, not an endless loop.
- [ ] **COACH-09** Every move in an answer is legal in the position it refers to. Set up the board in the review to check 2–3.
- [ ] **COACH-10** Ask a follow-up in the same chat ("Why is that better?"). **Expect:** it remembers the earlier context.
- [ ] **COACH-11** Keep chatting until "Context memory is full. Please start a new chat." appears (~2000 tokens). Input is then blocked.
- [ ] **COACH-12** Send is disabled for an empty or whitespace-only question. Double-tapping Send doesn't send twice.

**Voice**
- [ ] **COACH-20** Tap the mic and allow permission. **Expect:** "Listening… tap ■ to stop", and the words appear in the field.
- [ ] **COACH-21** Deny mic permission. **Expect:** "To ask by voice, allow MoveWise to use the microphone in your phone's Settings."
- [ ] **COACH-22** Say nothing. **Expect:** "I didn't catch that. Tap the mic and try again."
- [ ] **COACH-23** Offline voice (Android). **Expect:** "Voice input needs an internet connection on this phone."

**Saved chats**
- [ ] **COACH-30** "Your chats" lists chats grouped into "This week" and "Earlier", each with a message count.
- [ ] **COACH-31** Search chats; clear search. "No chats match." shows when nothing matches.
- [ ] **COACH-32** Opening a saved chat **never** calls the AI (check offline: it still opens). The banner says "Continue this chat below…".
- [ ] **COACH-33** Chat options → Rename (Save/Cancel) → Delete ("Delete this chat?"). The chat is removed and games stay.
- [ ] **COACH-34** Home → AI Coach shows "Pick up where you left off" with the latest chat, and "All chats" works.
- [ ] **COACH-35** Kill the app mid-answer. **Expect:** on reopen the question shows "Not answered yet." with "Try again".

**Errors**
- [ ] **COACH-40** Offline. **Expect:** "You're offline. You can read this chat; continuing it needs the internet."
- [ ] **COACH-41** No key (release build, or remove the key in Settings and build without `.env`). **Expect:** "The AI Coach isn't set up on this phone yet. Add your key in Settings › Developer mode."
- [ ] **COACH-42** Invalid key (save `abc123`). **Expect:** "The AI key was rejected, so AI features aren't available right now."
- [ ] **COACH-43** Rate limit (send many questions quickly). **Expect:** "The AI limit is used up for now. Try again in a minute or two." No crash.

## 13. Stats

- [ ] **STATS-01** No games: "No games yet" with "Play vs Computer" and "Import games".
- [ ] **STATS-02** Period switch: Last 20 / Last 50 / All time. The caption reads "Your 20 most recent games · N reviewed".
- [ ] **STATS-03** Unreviewed games show "N games aren't reviewed yet" → "Review them". Progress reads "Reviewing game X of N", and the stats update after each game.
- [ ] **STATS-04** "Stop" during a bulk review: games that are already done are kept. Leaving the screen and coming back doesn't lose them.
- [ ] **STATS-05** Summary strip: Win rate, Accuracy, Blunders/game, Record W–D–L, with "vs previous 20" arrows (or "no trend yet").
- [ ] **STATS-06** Top 3 weaknesses: each shows "In X of Y games". "See N games" opens a filtered Games list ("SHOWING · Some games · each opens at the move", "Show all"). "Ask AI Coach" opens the Coach with that question.
- [ ] **STATS-07** With fewer than ~2 reviewed games: "Not enough reviewed games to spot patterns yet…"
- [ ] **STATS-08** Blunders by game phase: opening / middlegame / endgame bars and a summary sentence.
- [ ] **STATS-09** "When your games go wrong" chart: tap a bar for "Moves X–Y: N mistakes, M blunders".
- [ ] **STATS-10** Results by opening: White/Black split and a score %. Numbers look plausible against your games.
- [ ] **STATS-11** Personal bests: Best accuracy, Biggest comeback, Win streak, Peak rating (from Chess.com/Lichess). Tapping one opens that game.
- [ ] **STATS-12** Stats makes **no** AI calls (works in airplane mode).

## 14. Report card

- [ ] **CARD-01** Open for an unreviewed game. **Expect:** "Analysing your game… N%" first, then the card.
- [ ] **CARD-02** The card shows the MoveWise logo, "GAME REPORT", accuracy %, best move, worst blunder (or "None"), a summary and the date. It is always dark, even in light mode.
- [ ] **CARD-03** "Get AI verdict" replaces the summary with a one-line quoted verdict ("AI Coach verdict"). Reopening the card keeps it (cached).
- [ ] **CARD-04** "Share image" opens the share sheet with `movewise-report-<id>.png` (1080×1350). Share to Photos/WhatsApp and check it looks right.
- [ ] **CARD-05** "Copy PGN" shows "PGN copied". Paste into lichess.org/paste: the game loads correctly with the right result.
- [ ] **CARD-06** Verdict offline: an error with "Try again".

## 15. Settings

- [ ] **SET-01** Game import: set Chess.com/Lichess usernames. "Import" goes to the Import screen for that site.
- [ ] **SET-02** Board theme: Slate / Ink / Dusk / Ember. The preview updates and the change applies in the game, review and pass & play.
- [ ] **SET-03** Appearance: Dark / Light / System. Every screen is readable in Light (the design only covers Home in light, so look for low-contrast text).
- [ ] **SET-04** Sound off: silent. Haptic feedback off: no vibrations.
- [ ] **SET-05** Reduce motion on: pieces fade instead of sliding, and sheets and the intro are simplified. With the toggle off but the phone setting on, motion is still reduced.
- [ ] **SET-06** Review depth: Fast / Balanced / Deep is remembered.
- [ ] **SET-07** Developer mode off: the AI key section is hidden. On: "AI Coach key (Gemini)" appears.
- [ ] **SET-08** Paste a key → "Save key". **Expect:** it's masked (••••••last4), and "Show key"/"Hide key" toggle it.
- [ ] **SET-09** "Test key" shows "Testing…", then "Key works". With a bad key it shows a clear failure.
- [ ] **SET-10** "Remove" shows "Key removed" with Undo. Undo restores the key.
- [ ] **SET-11** "How to get a free key": the link opens aistudio.google.com in the browser. If the browser can't open, "Link copied."
- [ ] **SET-12** The key survives an app restart (secure storage) and is **not** in any exported PGN or shared image.
- [ ] **SET-13** The footer reads "MoveWise 0.1.0 · Stockfish runs on your device".
- [ ] **SET-14** Every setting survives a force-kill and restart.

## 16. Motion, sound and haptics (compare with `design/design-spec.md`)

- [ ] **MOT-01** Tap-select, drag lift, move slide, capture, castling (king and rook both animate), en passant, promotion, check pulse, engine move, hint arrow, flip rotation, options sheet and result sheet all look smooth (no jank, 60 fps).
- [ ] **MOT-02** Illegal move: shake/feedback per spec.
- [ ] **MOT-03** Repeat MOT-01 with Reduce motion on. Each has its reduced version (mostly fades).
- [ ] **MOT-04** The landing sound plays when the piece **arrives**, not when it starts moving.

## 17. Cross-cutting

- [ ] **X-01** Airplane mode for a whole session: play, pass & play, review (Stockfish), stats and games all work. Only import, AI explanations, the coach and voice fail, each with a friendly message.
- [ ] **X-02** Android system back from every screen goes to the previous screen and never exits a game without saving it.
- [ ] **X-03** iOS swipe-back works on pushed screens and doesn't break a game in progress.
- [ ] **X-04** Large system font size (accessibility): no clipped text or overflow on Home, Game, Review or Settings.
- [ ] **X-05** Screen reader (TalkBack/VoiceOver): the clock reads e.g. "Your clock, 4 minutes 12 seconds". Buttons have labels (First move, Next move, Send, Ask by voice…).
- [ ] **X-06** Incoming call or notification shade during a game: the clock pauses and nothing breaks.
- [ ] **X-07** Leave the app open on the review screen for 10 minutes: it doesn't overheat and the battery drain is reasonable (Stockfish stops when it's done).
- [ ] **X-08** Upgrade test: install the previous build, create games and chats, then install the new build over it. **Expect:** data is kept and the database migrates without a crash.

## 18. Release build checks

- [ ] **REL-01** `flutter build apk --release` (and iOS archive) installs and runs.
- [ ] **REL-02** In release, **no** built-in key: AI features say they aren't set up until you add your key in Settings › Developer mode.
- [ ] **REL-03** App icon, adaptive icon (Android themed icons) and splash look right.
- [ ] **REL-04** Stockfish works in release on a real device (not just the simulator).
- [ ] **REL-05** Chess.com requests send a descriptive User-Agent. Optional check with a proxy such as Proxyman or Charles.

---

## Bug note template

```
ID:        PLAY-24
Device:    Pixel 7, Android 15 (debug)
Steps:     practice on, move, tap Undo while Stockfish thinking
Expected:  reply dropped
Actual:    Stockfish's move appeared after undo
Frequency: 3/5
```
