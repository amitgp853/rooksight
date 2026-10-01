# Rooksight server

One Firebase function, `ai`, that calls Gemini with the developer's paid key so
players don't need their own. Each install signs in silently (Firebase
anonymous auth), and App Check makes sure requests come from the real app.

- `POST /ai/models/{model}:generateContent`: Gemini's own request and reply.
  The `X-Rooksight-Action: <review|scan|coach>:<id>` header names what the call
  is for. The first successful call of an action pays for it, with a free use
  if any are left this week, else credits. Its later calls are covered.
- `GET /ai/status`: free uses left this week, credits, and whether free use is
  paused.

Every number (free uses, prices in credits, daily spend stops, allowed models)
is in [`src/limits.ts`](src/limits.ts).

Firestore holds only `users/{uid}` (week, free uses, credits),
`users/{uid}/actions/{id}` (the calls made for each action) and `spend/{day}`
(dollars spent that UTC day). The app can't read or write the database; see
[`../firestore.rules`](../firestore.rules).

## One-time setup

1. `npm install -g firebase-tools`, then `firebase login`.
2. Create a Firebase project (e.g. `rooksight`) and switch it to the Blaze plan.
3. From the repo root: `firebase use --add` and pick the project.
4. Connect the app: `dart pub global activate flutterfire_cli`, then
   `flutterfire configure --project=<project-id> --platforms=android,ios`.
   This replaces the stand-in `lib/firebase_options.dart`.
5. In the console, turn on **Authentication › Sign-in method › Anonymous** and
   create a **Firestore** database (production mode).
6. Turn on **App Check** for both apps:
   - Android: Play Integrity (add the app's SHA-256 fingerprints).
   - iOS: App Attest (add the App Attest capability in Xcode), with
     DeviceCheck as the fallback.
   - Debug builds: put a token in `.env` as `APP_CHECK_DEBUG_TOKEN` and add it
     under App Check › Manage debug tokens.
7. Create a Gemini key in [Google AI Studio](https://aistudio.google.com/apikey)
   in the same Google Cloud project, then
   `firebase functions:secrets:set GEMINI_API_KEY`.
8. Set a budget alert in Cloud Billing. Alerts don't stop spending; the daily
   spend stops in `src/limits.ts` do.
9. Optional: a Firestore TTL policy on the `actions` collection group, field
   `expireAt`, to delete old actions.

## Develop and deploy

```sh
cd functions
npm install
npm test          # the rules in src/rules.ts
npm run build
npm run deploy    # the function and the Firestore rules
```

Logs: `firebase functions:log`. Each AI call logs its action, model and cost.
