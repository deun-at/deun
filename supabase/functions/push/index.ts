import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  getToken,
  GoogleAuth,
} from "https://deno.land/x/googlejwtsa@v0.1.8/mod.ts";
import pushKinds from './push_kinds.json' with { type: 'json' };

// The Firebase service account (the JSON file Firebase issues for it), read
// from the functions container's environment. The deployed copy inlined it;
// committed, it would let anyone push to every device.
const googleServiceAccountCredentials = JSON.parse(
  Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!,
);

type Lang = 'en' | 'de'

interface Template {
  key: string
  en: string
  de: string
}

interface Copy {
  title: Template
  body: Template
}

interface Kind {
  type: string
  scope: 'group' | 'expense' | 'friendship'
  copy: { default: Copy; on_behalf?: Copy }
  bindings: Record<string, string>
}

// push_kinds.json is the push kind table: each kind's routing type, scope,
// en/de copy (mirroring lib/l10n/app_en.arb and app_de.arb) and where each
// placeholder's text comes from. test/supabase/push_function_test.dart holds
// it to the ARB files, kSupportedCurrencies and the app's PushKind.
const KINDS = new Map<string, Kind>(
  Object.entries(pushKinds.kinds as unknown as Record<string, Kind>),
)
const ZERO_DECIMAL = new Set<string>(pushKinds.zero_decimal_currencies)

interface PushRecord {
  kind: string
  type: string
  object_id: string
  notification_receiver: string[]
  amount?: number
  paid_by?: string
  paid_for?: string
}

interface NotificationPayload {
  type: 'INSERT'
  table: string
  record: PushRecord
  schema: 'public'
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const reply = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })

// German exactly when the receiver's stored language subtag is `de`; null
// (the Settings "system default"), `en` and anything else read English.
const langOf = (locale: string | null): Lang =>
  (locale ?? '').toLowerCase().split(/[-_]/)[0] === 'de' ? 'de' : 'en'

// The server mirror of the app's formatMoney: "<CODE> <number>", the code
// first, the receiver's grouping and decimal mark, the currency's own number
// of decimals.
const money = (amount: number, currencyCode: string | null, lang: Lang) => {
  const code = currencyCode ?? 'EUR'
  const digits = ZERO_DECIMAL.has(code) ? 0 : 2
  const number = new Intl.NumberFormat(lang, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(amount)
  return `${code} ${number}`
}

const render = (template: string, values: Record<string, string>) =>
  template.replace(/\{(\w+)\}/g, (_, placeholder: string) => values[placeholder] ?? '')

Deno.serve(async (req) => {
  const payload: NotificationPayload = await req.json()

  // The sender is whoever the bearer token belongs to, as the auth server
  // answers it; no body field names them. No user (the anon key the web
  // build ships included) sends nothing.
  const callerJwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  const { data: { user: caller } } = await supabase.auth.getUser(callerJwt)
  const callerEmail = caller?.email
  if (!callerEmail) {
    return reply({ error: 'not_signed_in' }, 401)
  }

  // The kind decides the routing type, the copy and who may receive it.
  const record = payload.record
  const kind = KINDS.get(record?.kind)
  if (!kind) {
    return reply({ error: 'unknown_kind' }, 400)
  }
  const usesAmount = Object.values(kind.bindings).includes('amount')
  if (usesAmount && !Number.isFinite(record.amount)) {
    return reply({ error: 'bad_request' }, 400)
  }

  const requested = [...new Set(record.notification_receiver ?? [])]
    .filter((email) => typeof email === 'string' && email !== '' && email !== callerEmail)

  // Who may hear about it. A group or expense push: the active members of its
  // own group (the object_id group, or the expense's group), and only if the
  // caller is one. A friendship push: whoever a friendship row of any status
  // links to the caller, in either direction.
  let receivers: string[]
  let group: { name: string | null; currency_code: string | null } | null = null
  let expenseName: string | null = null
  if (kind.scope === 'friendship') {
    const linked = new Set<string>()
    if (requested.length > 0) {
      const { data: asRequester } = await supabase
        .from('friendship')
        .select('addressee')
        .eq('requester', callerEmail)
        .in('addressee', requested)
      for (const row of asRequester ?? []) linked.add(row.addressee)
      const { data: asAddressee } = await supabase
        .from('friendship')
        .select('requester')
        .eq('addressee', callerEmail)
        .in('requester', requested)
      for (const row of asAddressee ?? []) linked.add(row.requester)
    }
    receivers = requested.filter((email) => linked.has(email))
  } else {
    let groupId = record.object_id
    if (kind.scope === 'expense') {
      const { data: expense } = await supabase
        .from('expense')
        .select('name, group_id')
        .eq('id', record.object_id)
        .maybeSingle()
      if (!expense) {
        return reply({ error: 'not_found' }, 404)
      }
      expenseName = expense.name
      groupId = expense.group_id
    }
    const { data: groupRow } = await supabase
      .from('group')
      .select('name, currency_code')
      .eq('id', groupId)
      .maybeSingle()
    if (!groupRow) {
      return reply({ error: 'not_found' }, 404)
    }
    group = groupRow
    const { data: members } = await supabase
      .from('group_member')
      .select('email')
      .eq('group_id', groupId)
      .is('removed_at', null)
    const active = new Set((members ?? []).map((row) => row.email))
    if (!active.has(callerEmail)) {
      return reply({ error: 'not_a_member' }, 403)
    }
    // A payback names both parties: each has to be an active member too.
    if (record.kind === 'payback_recorded' &&
        !(active.has(record.paid_by ?? '') && active.has(record.paid_for ?? ''))) {
      return reply({ error: 'not_a_member' }, 403)
    }
    receivers = requested.filter((email) => active.has(email))
  }

  if (receivers.length === 0) {
    return reply({ error: 'no_permitted_receivers' }, 403)
  }

  // One read for every receiver's language and devices and every name a push
  // can show: the caller's and, for a payback, both parties'.
  const people = [callerEmail, ...receivers, record.paid_by, record.paid_for]
    .filter((email): email is string => typeof email === 'string' && email !== '')
  const { data } = await supabase
    .from('user')
    .select('email, display_name, locale, device_tokens(token)')
    .in('email', [...new Set(people)])

  if (!data) {
    return reply({ error: "No users found" }, 404)
  }
  const users = new Map(data.map((user) => [user.email, user]))
  const nameOf = (email?: string) => users.get(email ?? '')?.display_name ?? ''

  // Every value a push shows is read from rows here, except the amount: the
  // one number the request carries.
  const copy = kind.copy.on_behalf && callerEmail !== record.paid_by
    ? kind.copy.on_behalf
    : kind.copy.default
  const compose = (lang: Lang) => {
    const source: Record<string, string> = {
      'caller.display_name': nameOf(callerEmail),
      'paid_by.display_name': nameOf(record.paid_by),
      'paid_for.display_name': nameOf(record.paid_for),
      'group.name': group?.name ?? '',
      'expense.name': expenseName ?? '',
      'amount': usesAmount ? money(record.amount!, group?.currency_code ?? null, lang) : '',
    }
    const values: Record<string, string> = {}
    for (const [placeholder, from] of Object.entries(kind.bindings)) {
      values[placeholder] = source[from] ?? ''
    }
    return {
      title: render(copy.title[lang], values),
      body: render(copy.body[lang], values),
    }
  }
  const text = { en: compose('en'), de: compose('de') }

  // Each receiver's push is written in that receiver's own stored language.
  const messages = receivers.flatMap((email) => {
    const receiver = users.get(email)
    if (!receiver) return []
    const { title, body } = text[langOf(receiver.locale)]
    return receiver.device_tokens.map((d: { token: string }) => ({ token: d.token, title, body }))
  })

  if (messages.length === 0) {
    return reply({ error: "No device tokens found" }, 400)
  }

  const googleAuthOptions = {
    scope: ["https://www.googleapis.com/auth/firebase.messaging"],
  };

  const jwt: GoogleAuth = await getToken(
    JSON.stringify(googleServiceAccountCredentials),
    googleAuthOptions,
  );

  // Sends one push to one device.
  const sendNotification = async (
    { token, title, body }: { token: string; title: string; body: string },
  ) => {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${googleServiceAccountCredentials.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${jwt.access_token}`,
        },
        body: JSON.stringify({
          message: {
            token,
            data: {
              type: kind.type,
              expense_id: record.object_id
            },
            notification: {
              title,
              body,
            },
          },
        }),
      }
    );

    const resData = await res.json();
    // FCM answers 404 (UNREGISTERED) for a token it no longer knows: drop
    // every row holding it.
    if (res.status == 404) {
      await supabase
        .from('device_tokens')
        .delete()
        .eq('token', token);
    }
    return resData;
  };

  try {
    // Send notifications in parallel
    const results = await Promise.all(messages.map(sendNotification));
    return reply(results, 200)
  } catch (error) {
    return reply({ error: (error as Error).message }, 500)
  }
})
