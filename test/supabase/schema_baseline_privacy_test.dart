// schema-baseline: the privacy guard. It runs on Jakob's dump in the working
// tree before anything under supabase/schema/ is staged — a secret that
// reaches git history stays there after a later redaction. Every sample below
// is invented.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rebuild_set.dart';

void main() {
  test('the data scan flags COPY, INSERT and setval at top level', () {
    const samples = {
      'COPY':
          'COPY public."user" (email, display_name) FROM stdin;\n'
          'guest+1@guest.invalid\tGuest\n'
          '\\.\n',
      'INSERT': 'INSERT INTO public."group" (name) VALUES (\'Trip\');\n',
      'setval':
          "SELECT pg_catalog.setval('public.payment_reminder_id_seq', 42, true);\n",
    };
    for (final MapEntry(key: shape, value: sql) in samples.entries) {
      expect(findDataStatements(sql), isNotEmpty, reason: shape);
    }
  });

  test('the secret scan flags each secret shape', () {
    const samples = {
      'JWT':
          "select 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.c2lnbmF0dXJlLXBsYWNlaG9sZGVy';",
      'Bearer token':
          "perform net.http_post(url := 'https://push.example/send', headers := jsonb_build_object('Authorization', 'Bearer abc.def-0123456789ghijkl'));",
      'URL with credentials':
          "select 'postgres://supabase_admin:hunter2@db:5432/postgres';",
      'private key':
          "select '-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBg\\n-----END PRIVATE KEY-----';",
      'role password': "CREATE ROLE app_writer LOGIN PASSWORD 'hunter2';",
      'user-mapping password':
          "CREATE USER MAPPING FOR postgres SERVER legacy OPTIONS (user 'app', password 'hunter2');",
      'conninfo password':
          "select dblink_connect('host=db dbname=postgres user=app password=hunter2');",
      'SCRAM hash':
          r"ALTER ROLE app_writer PASSWORD 'SCRAM-SHA-256$4096:c2FsdA==$a2V5:c2VydmVy';",
      'md5 hash':
          "ALTER ROLE app_writer ENCRYPTED PASSWORD 'md50123456789abcdef0123456789abcdef';",
      'bcrypt hash':
          r"select '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy';",
      'jwt_secret setting':
          'ALTER DATABASE postgres SET "app.settings.jwt_secret" TO \'not-a-real-secret-0123456789\';',
      'jwt_secret set_config':
          "select set_config('app.settings.jwt_secret', 'not-a-real-secret', false);",
      'vault secret literal':
          "select vault.create_secret('re_not_a_real_key', 'resend_api_key');",
      'email':
          "COMMENT ON TABLE public.\"user\" IS 'owner: someone@example.com';",
    };
    for (final MapEntry(key: shape, value: sql) in samples.entries) {
      expect(findSecrets(sql), isNotEmpty, reason: shape);
    }
  });

  test('neither scan fires on what a clean dump legitimately holds', () {
    const clean = r'''
\restrict 9pV3eZbQkq1nH0aXyR7tLwF2cM5sJ8uD4gK6oB1iE3vT0zYhN7mP2xC5rA8fW

CREATE FUNCTION public.pay_back(_group_id uuid, _paid_by text, _paid_for text, _amount numeric) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
declare
  _expense_id uuid;
begin
  insert into expense (group_id, paid_by, is_paid_back_row, name)
  values (_group_id, _paid_by, true, 'Payback')
  returning id into _expense_id;
  insert into expense_entry (expense_id, name, amount)
  values (_expense_id, 'Payback', _amount);
  return _expense_id;
end;
$$;

GRANT ALL ON FUNCTION public.pay_back(_group_id uuid, _paid_by text, _paid_for text, _amount numeric) TO service_role;
GRANT ALL ON FUNCTION extensions.sign(payload json, secret text, algorithm text) TO service_role;

CREATE TABLE _realtime.tenants (
    id uuid NOT NULL,
    jwt_secret text,
    encrypted_password character varying(255)
);

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$ begin return query select usename::text, passwd::text from pg_catalog.pg_shadow where usename = p_usename; end; $$;

SELECT pg_catalog.set_config('search_path', '', false);
COMMENT ON TABLE public."user" IS 'Guests look like guest+3f2a9c@guest.invalid; never real people';

\unrestrict 9pV3eZbQkq1nH0aXyR7tLwF2cM5sJ8uD4gK6oB1iE3vT0zYhN7mP2xC5rA8fW
''';
    expect(findDataStatements(clean), isEmpty);
    expect(findSecrets(clean), isEmpty);
  });

  test('the baseline in the working tree holds no row data and no secret', () {
    final sql = File('supabase/schema/baseline.sql').readAsStringSync();
    expect(findDataStatements(sql), isEmpty);
    expect(findSecrets(sql), isEmpty);
  });
}
