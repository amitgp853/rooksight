# MoveWise: AI Coach chat history

Feature: every AI Coach conversation is saved on the phone. You can see past chats, reopen one and read everything, then continue it. This spec sits on top of `docs/design/HANDOFF.md` and uses the same tokens, fonts and rules.

- `screens/`: PNG of every state (390 wide, 2x), rendered with stand-in fonts. Use the real Sora / Instrument Sans / JetBrains Mono in the app.
- `design/`: source of each screen (`*.dc.html`). Copy exact colours, sizes, radii and text from it. `Board`, `Logo`, `GameRows` and `motion.css` are the shared parts these screens use.

## Rules (non-negotiable)

1. **Opening a saved chat never calls the AI.** The AI runs only when the user sends a message: typing it, tapping a suggestion, or tapping send. The same opt-in rule applies everywhere else in the app.
2. **Chats live only on the phone**, in local storage, next to games. There's no sync and no account.
3. Every move the AI mentions is still checked by Stockfish before it's shown. Saved answers keep their checked move cards.
4. The name is "AI Coach" everywhere. Buttons use sentence case ("New chat", "Delete chat").

## Flow

```
Home ─▶ AI Coach (new chat) ──[history icon]──▶ Chats (list)
          │  "Pick up where you left off" card ──▶ Saved chat
          │  "All chats" ─────────────────────────▶ Chats
Chats ─[row]─▶ Saved chat ─[send]─▶ Continuing (steps run live, answer appends)
Chats ─[… on a row]─▶ Options sheet: Rename · Delete (confirm)
Chats (none yet) ─▶ Empty state ─[Ask the AI Coach]─▶ AI Coach (new chat)
Saved chat, offline ─▶ read only, composer disabled + banner
```

## Screens → files

| # | Screen | PNG | Source |
|---|---|---|---|
| 1 | AI Coach, new chat (with the latest chat card) | `01-coach-new-chat.png` | `Coach.dc.html` view=empty (`CoachEmpty`) |
| 2 | Pick a game sheet | `02-coach-pick-game.png` | view=picker (`CoachPicker`) |
| 3 | New chat with a game attached | `03-coach-game-attached.png` | view=emptyGame (`CoachEmptyGame`) |
| 4 | Live answer | `04-coach-answer.png` | view=answer (`Coach`) |
| 5 | Chats list | `05-chats-list.png` | `CoachHistory.dc.html` view=list |
| 6 | Chat options + delete confirm | `06-chat-options-delete.png` | view=delete (`CoachHistoryDelete`) |
| 7 | No chats yet | `07-chats-empty.png` | view=empty (`CoachHistoryEmpty`) |
| 8 | Saved chat reopened | `08-saved-chat-reopened.png` | `CoachThread.dc.html` view=saved |
| 9 | Continuing a saved chat | `09-continuing-chat.png` | view=continuing (`CoachThreadContinue`) |
| 10 | Saved chat, offline | `10-saved-chat-offline.png` | view=offline (`CoachThreadOffline`) |

## AI Coach screen: changes

- **Header:** back, "AI Coach" / "Every move claim checked by Stockfish", then a new **history icon button** (44×44, `aria-label="Your chats"`) that opens Chats, then the "New chat" pill. The subtitle ellipsizes on one line and the pill never wraps.
- **New chat state:** between the intro and "Try asking" there's a section:
  - Label "PICK UP WHERE YOU LEFT OFF" with an "All chats" link.
  - One card for the most recent chat: mini board (40, radius 6), the title on one line with ellipsis, "Today · 4 messages" and a chevron. Tapping it opens the saved chat.
  - The section is hidden when there are no saved chats, and when a game is already attached.
- **New chat:** starts a fresh, unsaved conversation. A chat is saved when the first message is sent.

## Chats list (`CoachHistory`)

- **App bar:** back (to AI Coach), "Chats" / "6 chats · saved on this phone", and a "New chat" pill.
- **Search field:** 44 high, pill shape, search icon inside, placeholder "Search chats". It filters by title and message text.
- **Groups:** "THIS WEEK", then "EARLIER" (older than 7 days). Newest first, by last activity.
- **Row:**
  - Height about 80, padding 12/16.
  - Leading: a 44×44 mini board (radius 8) of the chat's game at the key position. With no game (a question about many games), a 44×44 tile in `bg.elevated` with a chart icon in focus blue.
  - Title: 15/600, one line, ellipsis. The default title is the first question; the user can rename it.
  - Right of the title: time, 12 `text.tertiary` ("Today", "Yesterday", weekday within 7 days, else "19 Sep").
  - Preview: 13 `text.secondary`, one line: the start of the last AI answer.
  - Meta: 12 `text.tertiary`: what the chat is about ("vs Stockfish 1000 · 28 Sep", "vs pawnstorm_ · Lichess", "vs Opponent · Pass & Play", "Your last 20 games") · "4 messages".
  - Trailing "…" button (44×44, `aria-label="Options for {title}"`).
- **Footer note:** "Chats are saved only on this phone. Opening one never runs the AI; it answers again only when you send a message."

### Options sheet (on "…")

- Bottom sheet (radius 24 top, `bg.raised`, 60% scrim).
  - Chat title in 13 secondary.
  - "Rename" row (52 high, pencil icon).
  - A delete block in `bg.elevated`.
- Delete block:
  - Title: "Delete this chat?"
  - Body: "The conversation is removed from this phone. Your games and their reviews stay. This can't be undone."
  - Buttons: **Cancel** (outline) and **Delete chat** (coral #F2677A fill, dark text).
- The row behind the sheet is highlighted in `bg.raised`.

### Empty (no chats yet)

- Chat bubble icon in a 64 tile.
- "No chats yet" / "Your conversations with the AI Coach are kept here on your phone, so you can reopen one and carry on any time."
- Primary button: **Ask the AI Coach**, which goes to the new chat.
- No search field.

## Saved chat (`CoachThread`)

- **App bar:** back (to Chats), the chat title (16/600, one line, ellipsis) over "Started 26 Sep · 4 messages", and a "…" options button (same sheet as the list).
- **Context row** under the app bar: "About" plus a chip (22 mini board and "vs Stockfish 1000 · 28 Sep"). Tapping the chip opens that game's Review. The row is hidden for chats with no game.
- **Transcript:**
  - Opens scrolled to the bottom.
  - Day dividers ("Sat 26 Sep", "Today"): a centred 12px label between hairlines.
  - User bubbles: right-aligned, `#2A3A5E`, radius 18/18/6/18, max width 290.
  - AI answers, as in the live screen: logo 26, a bold headline, body text, and move cards (44 board, "15. g3?? → Qg5") that open the position in Review.
  - **Finished agent steps are collapsed** into one 40-high row: a check in a focus-blue circle, "WORKED THROUGH 3 STEPS" and a chevron. Tapping it expands the saved steps (read only, no spinners).
  - Below the last message: "Continue this chat below. The AI Coach remembers everything above." (12, tertiary, centred).
- **Composer:** same as the new chat (+ attach, pill input, mic, send). The placeholder is "Continue the chat…".

### Continuing

- Sending adds a "Today" divider if the day changed.
- Then the user bubble, then the live steps card (spinner → check, as in the live screen), then the answer.
- The request includes the whole saved conversation (plus the attached game), so the coach remembers the context. Save each message as it completes.
- The header count updates ("6 messages") and the chat moves to the top of the list.

### Offline

- The transcript stays fully readable.
- A banner sits above the composer (`bg.raised`, border, brass wifi-off icon): "You're offline. You can read this chat; continuing it needs the internet."
- The composer is disabled: 45% opacity, and the send button is `bg.elevated` with a tertiary icon.
- With no AI key set, show the same banner pattern, with text pointing to Settings › Developer mode.

## Data model (suggested)

```dart
class CoachChat {
  final String id;              // uuid
  String title;                 // first question until renamed
  final DateTime createdAt;
  DateTime updatedAt;           // sort + grouping
  final String? gameId;         // attached game, null = many games
  final String? focusFen;       // position for the list thumbnail
  final String scopeLabel;      // "vs Stockfish 1000 · 28 Sep" / "Your last 20 games"
  final List<CoachMessage> messages;
}

class CoachMessage {
  final String id;
  final CoachRole role;         // user | coach
  final DateTime at;
  final String text;            // user text, or coach body
  final String? headline;       // coach only
  final List<CoachStep> steps;  // coach only, saved as done
  final List<MoveCard> moves;   // verified moves: san, bestSan, fen, gameId, ply
}
```

- Store chats in the same local database as games (e.g. drift / isar / hive), one table for chats and one for messages. Delete cascades to the messages. **Deleting a game does not delete chats**: the chip then reads "Game deleted" and isn't tappable.
- Search is a local text search over titles and message text.
- There's no cap on the number of chats. Add paging if the list gets long.

## Motion

- Rows, sheets and banners use the existing tokens: sheet 320ms slide up, scrim 200ms.
- Opening a chat: a standard page push. Collapsed steps expand with a 200ms size animation.
- New messages fade up 4px over 300ms (`mw-in`).
- Reduced motion: fades only.
