import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { freeSpendPerDayUsd, maxOutputTokens, totalSpendPerDayUsd } from '../src/limits.ts';
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
} from '../src/rules.ts';

describe('weekKey', () => {
  it('counts ISO weeks from Monday, in UTC', () => {
    assert.equal(weekKey(new Date('2026-10-02T12:00:00Z')), '2026-W40'); // Friday
    assert.equal(weekKey(new Date('2026-10-04T23:59:59Z')), '2026-W40'); // Sunday
    assert.equal(weekKey(new Date('2026-10-05T00:00:00Z')), '2026-W41'); // Monday
  });

  it('gives the first days of January to the week of their Thursday', () => {
    assert.equal(weekKey(new Date('2027-01-01T00:00:00Z')), '2026-W53');
    assert.equal(weekKey(new Date('2027-01-04T00:00:00Z')), '2027-W01');
    assert.equal(weekKey(new Date('2025-12-29T00:00:00Z')), '2026-W01');
  });
});

describe('dayKey', () => {
  it('is the UTC date', () => assert.equal(dayKey(new Date('2026-10-02T23:30:00Z')), '2026-10-02'));
});

describe('allowance', () => {
  const week = '2026-W40';

  it('starts each week with every free use back, keeping credits', () => {
    const last = { week: '2026-W39', used: { review: 3 }, credits: 5 };
    assert.deepEqual(inWeek(last, week), { week, used: {}, credits: 5 });
  });

  it('uses free uses first, then credits, then runs out', () => {
    let account = { ...newAccount(week), credits: 3 };
    for (let i = 0; i < 3; i++) {
      assert.equal(payment(account, 'coach', 0), 'free');
      account = charge(account, 'coach', 'free');
    }
    assert.equal(freeLeft(account, 'coach'), 0);
    assert.equal(payment(account, 'coach', 0), 'credits');
    account = charge(account, 'coach', 'credits');
    assert.equal(account.credits, 1);
    // A coach question costs 2 credits; a review 1.
    assert.equal(payment(account, 'coach', 0), 'out_of_uses');
    assert.equal(payment(account, 'review', 0), 'free');
  });

  it('pauses free use past the day’s free spend, but not credits', () => {
    const account = { ...newAccount(week), credits: 1 };
    assert.equal(payment(newAccount(week), 'scan', freeSpendPerDayUsd), 'paused');
    assert.equal(payment(account, 'scan', freeSpendPerDayUsd), 'credits');
  });

  it('pauses everything past the day’s total spend', () => {
    const account = { ...newAccount(week), credits: 100 };
    assert.equal(payment(account, 'review', totalSpendPerDayUsd), 'paused');
  });

  it('never takes credits below zero', () => {
    assert.equal(charge(newAccount(week), 'coach', 'credits').credits, 0);
  });
});

describe('parseAction', () => {
  it('reads kind and id', () => {
    assert.deepEqual(parseAction('coach:abcDEF12_-'), { kind: 'coach', id: 'abcDEF12_-' });
  });

  it('refuses unknown kinds, short ids and odd characters', () => {
    for (const header of [undefined, '', 'chat:abcdefgh', 'coach:short', 'coach:abc/defgh', 'coach']) {
      assert.equal(parseAction(header), null, String(header));
    }
  });
});

describe('costUsd', () => {
  const usage = { promptTokenCount: 1_000_000, candidatesTokenCount: 600_000, thoughtsTokenCount: 400_000 };

  it('bills thinking as output', () => {
    assert.equal(costUsd('gemini-3.8-flash', usage, new Date('2026-10-02')), 0.75 + 3.75);
  });

  it('uses 2027 prices from 2027', () => {
    assert.equal(costUsd('gemini-3.8-flash', usage, new Date('2027-01-01')), 1.5 + 7.5);
  });

  it('bills cached input at a tenth', () => {
    const cached = { promptTokenCount: 1_000_000, cachedContentTokenCount: 1_000_000 };
    assert.ok(Math.abs(costUsd('gemini-3.8-flash', cached, new Date('2026-10-02')) - 0.075) < 1e-9);
  });

  it('is zero for unknown models or missing usage', () => {
    assert.equal(costUsd('other', usage, new Date()), 0);
    assert.equal(costUsd('gemini-3.8-flash', undefined, new Date()), 0);
  });
});

describe('sanitize', () => {
  const contents = [{ role: 'user', parts: [{ text: 'Hi' }] }];

  it('refuses a body without contents', () => {
    assert.equal(typeof sanitize({}), 'string');
    assert.equal(typeof sanitize(null), 'string');
  });

  it('refuses too many pictures', () => {
    const image = { inlineData: { mimeType: 'image/jpeg', data: 'x' } };
    assert.equal(typeof sanitize({ contents: [{ parts: [image, image, image] }] }), 'string');
  });

  it('keeps function tools and drops others', () => {
    const body = sanitize({
      contents,
      tools: [{ googleSearch: {} }, { functionDeclarations: [{ name: 'analyze_position' }] }],
      toolConfig: { functionCallingConfig: { mode: 'AUTO' } },
      cachedContent: 'cachedContents/x',
    });
    assert.deepEqual(body, {
      contents,
      tools: [{ functionDeclarations: [{ name: 'analyze_position' }] }],
      toolConfig: { functionCallingConfig: { mode: 'AUTO' } },
      generationConfig: { maxOutputTokens },
    });
  });

  it('caps replies and keeps thinking low', () => {
    const body = sanitize({
      contents,
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 100_000,
        thinkingConfig: { thinkingLevel: 'high' },
        responseMimeType: 'application/json',
      },
    });
    assert.deepEqual(body, {
      contents,
      generationConfig: {
        maxOutputTokens,
        temperature: 0.4,
        responseMimeType: 'application/json',
        thinkingConfig: { thinkingLevel: 'low' },
      },
    });
  });
});
