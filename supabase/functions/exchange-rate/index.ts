// Historical reference rates for the expense editor's rate prefill.
//
// Server-side on purpose: the app has no HTTP client and no `http` dependency
// (see test/pages/groups/multi_currency_group_test.dart), every external call
// already goes through Supabase, and a client-side fetch is what broke
// conversion outright for a competitor when the provider issued a redirect
// without CORS headers. This function is also the only place a cache can live
// that is shared across users and devices.
//
// Source: Frankfurter (frankfurter.dev), ECB reference data, free, no API key.

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// The ECB reference set — the same 31 codes as `kSupportedCurrencies` in
// lib/helper/currency.dart. A code the app cannot pick is a code this function
// does not call upstream for.
const SUPPORTED = new Set([
  'EUR', 'USD', 'JPY', 'BGN', 'CZK', 'DKK', 'GBP', 'HUF', 'PLN', 'RON',
  'SEK', 'CHF', 'ISK', 'NOK', 'TRY', 'AUD', 'BRL', 'CAD', 'CNY', 'HKD',
  'IDR', 'ILS', 'INR', 'KRW', 'MXN', 'MYR', 'NZD', 'PHP', 'SGD', 'THB',
  'ZAR',
]);

const PROVIDER = 'https://api.frankfurter.dev/v1';

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const YEAR_MS = 365 * DAY_MS;

type Cached = { rate: number; date: string; expires: number };

// Per-instance cache. A historical rate can never change, so it is held for a
// year; today's can still move, so it is held for an hour.
const cache = new Map<string, Cached>();

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });

const today = () => new Date().toISOString().slice(0, 10);

const daysBetween = (from: string, to: string) =>
  Math.round((Date.parse(to) - Date.parse(from)) / DAY_MS);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: 'bad_request' }, 400);
  }

  const base = String(body?.base ?? '').toUpperCase();
  const quote = String(body?.quote ?? '').toUpperCase();
  const date = String(body?.date ?? '');

  if (!SUPPORTED.has(base) || !SUPPORTED.has(quote)) {
    return json({ error: 'unsupported_currency' }, 400);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return json({ error: 'bad_date' }, 400);
  }

  // A future date has no published rate. The provider answers it with the
  // LATEST rate it holds, which is exactly the silent today-for-that-date
  // substitution this feature exists to refuse — so it is refused here, where
  // the client can still see it as "no rate".
  //
  // One day of slack, because the two clocks disagree by design: the client
  // sends the DEVICE's local date (`ymd`, helper.dart) and this function runs on
  // UTC. Every user east of UTC is a day ahead for part of their morning — Tokyo
  // at 08:00 sends 2026-09-11 while UTC is still on 2026-09-10 — so a bare
  // `date > today()` refuses a same-day expense for the whole eastern-timezone
  // cohort, which is the travelling cohort this feature exists for.
  //
  // The slack cannot reintroduce the substitution it guards against: whatever
  // the provider answers carries an EFFECTIVE date, the walk-back window below
  // bounds how stale that may be, and the editor displays and freezes it. A rate
  // quoted on another day is therefore visible as such, never silent.
  if (daysBetween(today(), date) > 1) {
    return json({ error: 'no_rate' }, 404);
  }

  // Same currency is the identity, not a substituted 1:1 for a pair that has a
  // real rate. The editor never asks for it (an identity conversion has no rate
  // field), but the contract is cleaner with it answered than undefined.
  if (base === quote) {
    return json({ rate: 1, date, base, quote }, 200);
  }

  const key = `${base}|${quote}|${date}`;
  const hit = cache.get(key);
  if (hit && hit.expires > Date.now()) {
    return json({ rate: hit.rate, date: hit.date, base, quote, cached: true }, 200);
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${PROVIDER}/${date}?base=${base}&symbols=${quote}`);
  } catch (_) {
    return json({ error: 'upstream_unreachable' }, 502);
  }
  if (!upstream.ok) {
    return json({ error: 'upstream_error' }, 502);
  }

  const data = await upstream.json();
  const rate = data?.rates?.[quote];
  const effective = typeof data?.date === 'string' ? data.date : null;
  if (typeof rate !== 'number' || !isFinite(rate) || rate <= 0 || !effective) {
    return json({ error: 'no_rate' }, 404);
  }

  // The provider walks BACK to the last publication day, which is the answer we
  // want for a Saturday expense (Friday's rate) and emphatically not the answer
  // we want for a date before its coverage begins. A week is wider than any ECB
  // holiday gap and narrower than a decade of missing history.
  if (effective > date || daysBetween(effective, date) > 7) {
    return json({ error: 'no_rate' }, 404);
  }

  cache.set(key, {
    rate,
    date: effective,
    expires: Date.now() + (date < today() ? YEAR_MS : HOUR_MS),
  });

  return json({ rate, date: effective, base, quote }, 200);
});
