// Rooksight's only server code: Gemini behind the developer's paid key, with
// a weekly free allowance and credits per player.
//
//   POST /ai/models/{model}:generateContent   Gemini's own request and reply
//   GET  /ai/status                            free uses and credits left
//
// Every request needs a Firebase ID token (`Authorization: Bearer …`, an
// anonymous user is enough) and an App Check token (`X-Firebase-AppCheck`),
// so only the real app can spend the key. Each generate call names its
// action (`X-Rooksight-Action: coach:<id>`): the first successful call of an
// action pays for it; its later calls (a coach question's tool rounds) are
// covered, up to the action's limit.

import { initializeApp } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onRequest, type Request, type Response as HttpResponse } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

import { actionKinds, actionWindowMs, actions, freeSpendPerDayUsd, maxBodyBytes, models, totalSpendPerDayUsd } from './limits.ts';
import {
  charge,
  costUsd,
  dayKey,
  freeLeft,
  inWeek,
  newAccount,
  parseAction,
  payment,
  sanitize,
  weekKey,
  type Account,
} from './rules.ts';

initializeApp();
const db = getFirestore();

/** Set with `firebase functions:secrets:set GEMINI_API_KEY`. */
const geminiKey = defineSecret('GEMINI_API_KEY');

/** An action in progress, in `users/{uid}/actions/{id}`. */
interface RunningAction {
  kind: string;
  calls: number;
  startedAt: number;
}


export const ai = onRequest(
  { secrets: [geminiKey], maxInstances: 10, timeoutSeconds: 180, memory: '256MiB' },
  async (req, res) => {
    const uid = await caller(req);
    if (!uid) return fail(res, 401, 'UNAUTHENTICATED');

    if (req.method === 'GET' && req.path === '/status') return status(uid, res);
    const model = /^\/models\/([a-z0-9.-]+):generateContent$/.exec(req.path)?.[1];
    if (req.method !== 'POST' || !model) return fail(res, 404, 'NOT_FOUND');
    return generate(uid, model, req, res);
  },
);

/** The player's uid, if both tokens check out. */
async function caller(req: Request): Promise<string | null> {
  const appCheck = req.header('X-Firebase-AppCheck');
  const idToken = /^Bearer (.+)$/.exec(req.header('Authorization') ?? '')?.[1];
  if (!appCheck || !idToken) return null;
  try {
    await getAppCheck().verifyToken(appCheck);
    return (await getAuth().verifyIdToken(idToken)).uid;
  } catch {
    return null;
  }
}

/** An error in Gemini's own shape, which the app already reads. */
function fail(res: HttpResponse, code: number, status: string): void {
  res.status(code).json({ error: { code, status } });
}

async function generate(uid: string, model: string, req: Request, res: HttpResponse): Promise<void> {
  const action = parseAction(req.header('X-Rooksight-Action'));
  if (!action) return fail(res, 400, 'BAD_ACTION');
  // An unknown model is refused like Gemini refuses one, so the app moves on
  // to its next model.
  if (!(model in models)) return fail(res, 400, 'UNKNOWN_MODEL');
  if ((req.rawBody?.length ?? 0) > maxBodyBytes) return fail(res, 413, 'TOO_LARGE');
  const body = sanitize(req.body);
  if (typeof body === 'string') return fail(res, 400, 'BAD_REQUEST');

  const now = new Date();
  const week = weekKey(now);
  const userRef = db.doc(`users/${uid}`);
  const actionRef = userRef.collection('actions').doc(action.id);
  const spendRef = db.doc(`spend/${dayKey(now)}`);

  const [actionSnap, userSnap, spendSnap] = await db.getAll(actionRef, userRef, spendRef);
  const spent: number = spendSnap.get('usd') ?? 0;
  const running = actionSnap.data() as RunningAction | undefined;
  if (running) {
    const over =
      running.kind !== action.kind ||
      running.calls >= actions[action.kind].maxCalls ||
      now.getTime() - running.startedAt > actionWindowMs;
    if (over) return fail(res, 409, 'ACTION_USED');
    if (spent >= totalSpendPerDayUsd) return fail(res, 402, 'PAUSED');
  } else {
    const account = inWeek((userSnap.data() as Account | undefined) ?? newAccount(week), week);
    const how = payment(account, action.kind, spent);
    if (how === 'out_of_uses') return fail(res, 402, 'OUT_OF_USES');
    if (how === 'paused') return fail(res, 402, 'PAUSED');
  }

  let reply: Response;
  try {
    reply = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'x-goog-api-key': geminiKey.value(), 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(150_000),
    });
  } catch (error) {
    logger.warn('Gemini unreachable', { model, error: String(error) });
    return fail(res, 504, 'GEMINI_UNREACHABLE');
  }
  const text = await reply.text();

  if (!reply.ok) {
    logger.warn('Gemini error', { model, status: reply.status, body: text.slice(0, 500) });
    // A problem with the developer's key isn't the player's: never pass it
    // on as one. A 429 keeps its body, which says how long to wait.
    const keyProblem = reply.status === 401 || reply.status === 403 || text.includes('API_KEY_INVALID');
    res.status(keyProblem ? 503 : reply.status).type('json').send(text);
    return;
  }

  let usage;
  try {
    usage = JSON.parse(text).usageMetadata;
  } catch {
    return fail(res, 502, 'BAD_REPLY');
  }
  const cost = costUsd(model, usage, now);

  await Promise.all([
    spendRef.set({ usd: FieldValue.increment(cost) }, { merge: true }),
    db.runTransaction(async (t) => {
      const [actionNow, userNow] = await Promise.all([t.get(actionRef), t.get(userRef)]);
      if (actionNow.exists) {
        t.update(actionRef, { calls: FieldValue.increment(1) });
        return;
      }
      const account = inWeek((userNow.data() as Account | undefined) ?? newAccount(week), week);
      const how = payment(account, action.kind, spent);
      t.set(userRef, charge(account, action.kind, how));
      t.set(actionRef, {
        kind: action.kind,
        calls: 1,
        startedAt: now.getTime(),
        paidWith: how,
        // For an optional Firestore TTL policy that deletes old actions.
        expireAt: Timestamp.fromMillis(now.getTime() + 86_400_000),
      });
    }),
  ]);
  logger.info('AI call', { uid, kind: action.kind, model, usd: cost });

  res.status(200).type('json').send(text);
}

/** Free uses left this week, credits, and whether free use is paused. */
async function status(uid: string, res: HttpResponse): Promise<void> {
  const now = new Date();
  const week = weekKey(now);
  const [userSnap, spendSnap] = await db.getAll(db.doc(`users/${uid}`), db.doc(`spend/${dayKey(now)}`));
  const account = inWeek((userSnap.data() as Account | undefined) ?? newAccount(week), week);
  const spent: number = spendSnap.get('usd') ?? 0;
  res.json({
    credits: account.credits,
    free: Object.fromEntries(actionKinds.map((kind) => [kind, freeLeft(account, kind)])),
    freePerWeek: Object.fromEntries(actionKinds.map((kind) => [kind, actions[kind].freePerWeek])),
    price: Object.fromEntries(actionKinds.map((kind) => [kind, actions[kind].credits])),
    paused: spent >= freeSpendPerDayUsd,
  });
}
