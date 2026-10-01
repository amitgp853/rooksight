// Everything that decides what the AI costs the developer and the player, in
// one place. Change a number here and deploy; the app needs no update.

/** The things a player can ask the AI for. */
export const actionKinds = ['review', 'scan', 'coach'] as const;
export type ActionKind = (typeof actionKinds)[number];

/**
 * Per action: its price in credits, how many are free each week, and how
 * many model calls it may make (a coach question is up to 5 tool rounds and
 * an answer; a scan reads the photo, then may look again).
 */
export const actions: Record<ActionKind, { credits: number; freePerWeek: number; maxCalls: number }> = {
  review: { credits: 1, freePerWeek: 3, maxCalls: 1 },
  scan: { credits: 1, freePerWeek: 3, maxCalls: 2 },
  coach: { credits: 2, freePerWeek: 3, maxCalls: 6 },
};

/** An action's calls must all come within this time of its first. */
export const actionWindowMs = 10 * 60 * 1000;

/**
 * Daily spend stops, in US dollars, across all players (UTC days). Past the
 * first, free uses pause until tomorrow; past the second, everything does.
 * Google Cloud budgets only send alerts, so these are the real limit.
 */
export const freeSpendPerDayUsd = 1;
export const totalSpendPerDayUsd = 3;

/** Paid-tier prices in US dollars per million tokens. */
interface Price {
  input: number;
  output: number;
}

/**
 * The models the app may use, with their prices; any other is refused.
 * Thinking is billed as output. Prices from
 * https://ai.google.dev/gemini-api/docs/pricing (October 2026).
 */
export const models: Record<string, { price: Price; from2027?: Price }> = {
  'gemini-3.8-flash': { price: { input: 0.75, output: 3.75 }, from2027: { input: 1.5, output: 7.5 } },
  'gemini-3.5-flash-lite': { price: { input: 0.3, output: 2.5 } },
};

/** Cached prompt tokens cost this share of the input price. */
export const cachedInputShare = 0.1;

/** A cap on each reply, thinking included. */
export const maxOutputTokens = 8192;

/** Thinking levels the app may ask for; anything else becomes `low`. */
export const thinkingLevels = ['minimal', 'low'];

/** Pictures per request (a scan sends one). */
export const maxImages = 2;

/** Request body size, in bytes. */
export const maxBodyBytes = 4_000_000;
