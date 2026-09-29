# Prompts for Claude Code

Put this folder at `docs/design/ai-coach-chats/` in your project. Then send these one at a time, checking each result before you send the next.

1. **Plan**
   > Read docs/design/ai-coach-chats/AI_COACH_CHATS.md and look at the PNGs in its screens/ folder. Compare them with our current AI Coach code. Propose the data model, storage, and the list of widgets and routes to add or change. Don't write code yet.

2. **Storage**
   > Add local storage for AI Coach chats and messages as in the spec: save on first send, append each message, rename, delete (cascade to messages), search by title and text. Add unit tests.

3. **Chats list**
   > Build the Chats screen from design/CoachHistory.dc.html and screens/05–07: grouped list (This week / Earlier), search, row layout, options sheet with Rename and delete confirm, empty state. Add the history icon to the AI Coach header, and the "Pick up where you left off" card to the new chat state (screens/01).

4. **Saved chat + continue**
   > Build the saved chat screen from design/CoachThread.dc.html and screens/08–10: day dividers, collapsed steps, move cards, context chip, and the "Continue the chat…" composer. Opening a chat must never call the AI. Sending continues the conversation with the full history as context, then shows the live steps and answer. Add the offline and no-key states. Add a test that opening a saved chat makes no AI call.
