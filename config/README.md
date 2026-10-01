# Remote config

`remote.json` is read by every installed copy of MoveWise from
`https://raw.githubusercontent.com/amitgp853/move_wise/main/config/remote.json`.
Push a change to `main` and phones pick it up within about an hour: they check
at launch and when brought back to the front, at most once an hour. GitHub
caches the file for about 5 minutes. Phones that
are offline keep the last copy they fetched, or the defaults built into the app.

| Field | Effect |
|---|---|
| `schema` | Always `1`. A higher number is ignored by this version of the app. |
| `update.<platform>.latestBuild` | Builds below it see an optional "Update available" card on Home. |
| `update.<platform>.minBuild` | Builds below it must update before they can be used. Never set it above `latestBuild`. |
| `update.<platform>.storeUrl` | The store page. Android defaults to Google Play; set it for iOS once the app is on the App Store. |
| `update.message` | What's new, shown with both prompts. Empty for none. |
| `llm.model` | The Gemini model. Must start with `gemini-`. |
| `llm.fallbackModel` | Used when the model is overloaded, out of quota or unknown. |
| `llm.thinkingLevel` | `minimal`, `low`, `medium`, `high`, or `""` for the model's default. |

Builds are the number after `+` in `pubspec.yaml` (`version: 0.1.0+1` is build 1).
Bump `latestBuild` only after the new build is live in the store.

A missing or invalid field falls back to the app's built-in value. If the
remote model doesn't exist, requests fall back to `fallbackModel`, then to the
built-in models. `--dart-define=GEMINI_MODEL=...` overrides the remote model
for development.
