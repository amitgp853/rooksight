// The AI proxy's decisions, as pure functions (no Firebase), so they can be
// tested on their own.

import {
  actionKinds,
  actions,
  cachedInputShare,
  freeSpendPerDayUsd,
  maxImages,
  maxOutputTokens,
  models,
  thinkingLevels,
  totalSpendPerDayUsd,
  type ActionKind,
} from './limits.ts';

/** A player's account, as stored in `users/{uid}`. */
export interface Account {
  /** The week [used] counts, e.g. `2026-W40`. */
  week: string;
  used: Partial<Record<ActionKind, number>>;
  credits: number;
}

export const newAccount = (week: string): Account => ({ week, used: {}, credits: 0 });

/** The account as it stands in [week]: last week's free uses are gone. */
export function inWeek(account: Account, week: string): Account {
  return account.week === week ? account : { ...account, week, used: {} };
}

/** The UTC day, e.g. `2026-10-02`, that spend is counted by. */
export const dayKey = (date: Date): string => date.toISOString().slice(0, 10);

/** The ISO week (Monday to Sunday, UTC), e.g. `2026-W40`. */
export function weekKey(date: Date): string {
  // The week belongs to the year of its Thursday.
  const thursday = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  thursday.setUTCDate(thursday.getUTCDate() + 4 - (thursday.getUTCDay() || 7));
  const yearStart = Date.UTC(thursday.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((thursday.getTime() - yearStart) / 86_400_000 + 1) / 7);
  return `${thursday.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

/** Free uses of [kind] left this week. */
export const freeLeft = (account: Account, kind: ActionKind): number =>
  Math.max(0, actions[kind].freePerWeek - (account.used[kind] ?? 0));

/** How a new action would be paid for, or why it can't start. */
export type Payment = 'free' | 'credits' | 'out_of_uses' | 'paused';

/**
 * How [kind] would be paid for, with [spentToday] dollars already spent by
 * everyone today: a free use while any are left and free use isn't paused,
 * else credits.
 */
export function payment(account: Account, kind: ActionKind, spentToday: number): Payment {
  if (spentToday >= totalSpendPerDayUsd) return 'paused';
  if (freeLeft(account, kind) > 0 && spentToday < freeSpendPerDayUsd) return 'free';
  if (account.credits >= actions[kind].credits) return 'credits';
  return freeLeft(account, kind) > 0 ? 'paused' : 'out_of_uses';
}

/**
 * [account] after paying for [kind]. Two actions started at once can both
 * pass the check before either is charged; then the second still costs what
 * is left, never below zero.
 */
export function charge(account: Account, kind: ActionKind, how: Payment): Account {
  if (how === 'free') {
    return { ...account, used: { ...account.used, [kind]: (account.used[kind] ?? 0) + 1 } };
  }
  return { ...account, credits: Math.max(0, account.credits - actions[kind].credits) };
}

/** The `X-Rooksight-Action` header, `<kind>:<id>`, or null if malformed. */
export function parseAction(header: string | undefined): { kind: ActionKind; id: string } | null {
  const match = /^([a-z]+):([A-Za-z0-9_-]{8,64})$/.exec(header ?? '');
  if (!match) return null;
  const kind = actionKinds.find((k) => k === match[1]);
  return kind ? { kind, id: match[2] } : null;
}

/** Gemini's `usageMetadata`. */
export interface UsageMetadata {
  promptTokenCount?: number;
  cachedContentTokenCount?: number;
  candidatesTokenCount?: number;
  thoughtsTokenCount?: number;
}

/** What one reply from [model] cost, in US dollars, on [date]. */
export function costUsd(model: string, usage: UsageMetadata | undefined, date: Date): number {
  const entry = models[model];
  if (!entry || !usage) return 0;
  const price = entry.from2027 && date.getUTCFullYear() >= 2027 ? entry.from2027 : entry.price;
  const prompt = usage.promptTokenCount ?? 0;
  const cached = usage.cachedContentTokenCount ?? 0;
  const output = (usage.candidatesTokenCount ?? 0) + (usage.thoughtsTokenCount ?? 0);
  return ((prompt - cached) * price.input + cached * price.input * cachedInputShare + output * price.output) / 1e6;
}

type Json = Record<string, unknown>;

const isObject = (value: unknown): value is Json =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/**
 * A `generateContent` body cut down to what the app sends: text, pictures,
 * function tools and JSON output. Anything else (search grounding, cached
 * content, other tools) is dropped, replies are capped, and thinking stays
 * low. A string explains why a body is refused.
 */
export function sanitize(body: unknown): Json | string {
  if (!isObject(body) || !Array.isArray(body.contents)) return 'no contents';

  let images = 0;
  for (const content of body.contents) {
    const parts = isObject(content) && Array.isArray(content.parts) ? content.parts : [];
    images += parts.filter((part) => isObject(part) && 'inlineData' in part).length;
  }
  if (images > maxImages) return 'too many images';

  const tools = Array.isArray(body.tools) ? body.tools : [];
  const declarations = tools.flatMap((tool) =>
    isObject(tool) && Array.isArray(tool.functionDeclarations) ? tool.functionDeclarations : [],
  );

  const config = isObject(body.generationConfig) ? body.generationConfig : {};
  const thinking = isObject(config.thinkingConfig) ? config.thinkingConfig.thinkingLevel : undefined;
  const generationConfig: Json = { maxOutputTokens };
  for (const key of ['temperature', 'mediaResolution', 'responseMimeType', 'responseJsonSchema']) {
    if (key in config) generationConfig[key] = config[key];
  }
  if (thinking !== undefined) {
    const level = typeof thinking === 'string' && thinkingLevels.includes(thinking) ? thinking : 'low';
    generationConfig.thinkingConfig = { thinkingLevel: level };
  }

  return {
    ...(isObject(body.systemInstruction) && { systemInstruction: body.systemInstruction }),
    contents: body.contents,
    ...(declarations.length > 0 && {
      tools: [{ functionDeclarations: declarations }],
      ...(isObject(body.toolConfig) && { toolConfig: body.toolConfig }),
    }),
    generationConfig,
  };
}
