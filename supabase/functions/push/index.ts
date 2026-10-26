import { createClient } from 'npm:@supabase/supabase-js@2'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  getToken,
  GoogleAuth,
} from "https://deno.land/x/googlejwtsa@v0.1.8/mod.ts";

// The Firebase service account (the JSON file Firebase issues for it), read
// from the functions container's environment. The deployed copy inlined it;
// committed, it would let anyone push to every device.
const googleServiceAccountCredentials = JSON.parse(
  Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!,
);

interface Notification {
  type: string
  object_id: string
  title: string
  body: string
  notification_receiver: string[]
}

interface NotificationPayload {
  type: 'INSERT'
  table: string
  record: Notification
  schema: 'public'
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  const payload: NotificationPayload = await req.json()

  // rls-stopgap 2026-10-25: only a signed-in caller may push, and only to people
  // who share a group or a friendship with them. push-server-compose replaces this.
  const callerJwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  const { data: { user: caller } } = await supabase.auth.getUser(callerJwt)
  const callerEmail = caller?.email
  if (!callerEmail) {
    return new Response(JSON.stringify({ error: "Not signed in" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const requested = [...new Set(payload.record?.notification_receiver ?? [])]
    .filter((email) => typeof email === 'string' && email !== '' && email !== callerEmail)
  const allowed = new Set<string>()
  if (requested.length > 0) {
    const { data: myGroups } = await supabase
      .from('group_member')
      .select('group_id')
      .eq('email', callerEmail)
    const groupIds = (myGroups ?? []).map((row) => row.group_id)
    if (groupIds.length > 0) {
      const { data: coMembers } = await supabase
        .from('group_member')
        .select('email')
        .in('group_id', groupIds)
        .in('email', requested)
      for (const row of coMembers ?? []) allowed.add(row.email)
    }
    const { data: asRequester } = await supabase
      .from('friendship')
      .select('addressee')
      .eq('requester', callerEmail)
      .in('addressee', requested)
    for (const row of asRequester ?? []) allowed.add(row.addressee)
    const { data: asAddressee } = await supabase
      .from('friendship')
      .select('requester')
      .eq('addressee', callerEmail)
      .in('requester', requested)
    for (const row of asAddressee ?? []) allowed.add(row.requester)
  }
  const receivers = requested.filter((email) => allowed.has(email))
  if (receivers.length === 0) {
    return new Response(JSON.stringify({ error: "No permitted receivers" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data } = await supabase
    .from('user')
    .select('device_tokens(token)')
    .in('email', receivers)

  if (!data) {
    return new Response(JSON.stringify({ error: "No users found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Flatten and extract all tokens
  const fcmTokens = data.flatMap((user) => user.device_tokens.map((d) => d.token));

  if (fcmTokens.length === 0) {
    return new Response(JSON.stringify({ error: "No device tokens found" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const googleAuthOptions = {
    scope: ["https://www.googleapis.com/auth/firebase.messaging"],
  };

  const jwt: GoogleAuth = await getToken(
    JSON.stringify(googleServiceAccountCredentials),
    googleAuthOptions,
  );
	
  // Function to send a notification to a single token
  const sendNotification = async (token: string) => {
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
              type: payload.record.type,
              expense_id: payload.record.object_id
            },
            notification: {
              title: payload.record.title,
              body: payload.record.body,
            },
          },
        }),
      }
    );

    const resData = await res.json();
    /*if (res.status < 200 || 299 < res.status) {
      throw new Error(`FCM error for token ${token}: ${JSON.stringify(resData)}`);
    }*/
	if(res.status == 404) {
		await supabase
    		.from('device_tokens')
    		.delete()
    		.eq('token', token);
	}
    return resData;
  };

  try {
    // Send notifications in parallel
    const results = await Promise.all(fcmTokens.map(sendNotification));
    return new Response(JSON.stringify(results), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
})