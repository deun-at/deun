# Supabase Realtime

- **postgres_changes filter limits** An `in` filter accepts at most 100 values. Several filter conditions combine with AND only ("OR is not supported"), so a row that matches on column A or column B needs two subscriptions.
  source: https://supabase.com/docs/guides/realtime/postgres-changes (read 2026-10-22) · unconfirmed — proposed by prep code-review-2026-10, 2026-10-22
- **postgres_changes and DELETE** RLS policies are not applied to DELETE events, so every subscriber receives them. A DELETE event can only be filtered when the table has `replica identity full`. Every other event is authorized against each subscriber, so throughput scales with the number of subscribers.
  source: https://supabase.com/docs/guides/realtime/postgres-changes (read 2026-10-22) · unconfirmed — proposed by prep code-review-2026-10, 2026-10-22
