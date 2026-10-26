import 'package:supabase_flutter/supabase_flutter.dart';

/// True when a PostgREST call failed because a column doesn't exist on the
/// server yet (an older database without a feature's migration applied).
/// 42703 = Postgres undefined column, PGRST204 = PostgREST schema-cache miss.
bool isMissingColumnError(PostgrestException e) =>
    e.code == '42703' || e.code == 'PGRST204';
