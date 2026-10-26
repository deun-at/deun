// schema-baseline: every database call lib/ makes names something the
// rebuild set has. Red means a rebuilt backend answers a client call with
// "relation/function does not exist", or accepts writes but never pushes the
// live refresh.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rebuild_set.dart';

List<String> _libSources() => [
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart')) f.readAsStringSync(),
];

void main() {
  test(
    'names an absent RPC and an absent table in each call form lib/ uses, and nothing when every target exists',
    () {
      final tmp = Directory.systemTemp.createTempSync('schema_drift_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final rebuild = loadFixture(tmp, r'''
-- dump-stamp: 20260701000000
CREATE TABLE public."user" (email text);
CREATE TABLE public.group_update_checker (group_id uuid);
CREATE TABLE public.expense_update_checker (expense_id uuid);
CREATE FUNCTION public.pay_back(_group_id uuid) RETURNS uuid
    LANGUAGE sql
    AS $$ select null::uuid $$;
CREATE FUNCTION public.delete_group(_group_id uuid) RETURNS void
    LANGUAGE sql
    AS $$ select 1 $$;
CREATE PUBLICATION supabase_realtime;
ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.group_update_checker;
''');

      const drifted = r"""
class Repo {
  static const String deleteRpcName = 'delete_missing';

  Future<void> calls() async {
    final xs = List.from(items);
    await supabase.from('ghost_table').select();
    await supabase
        .from("user")
        .select();
    await supabase.rpc(
      'ghost_rpc',
      params: {'_group_id': id},
    );
    await supabase.rpc(deleteRpcName, params: {});
    await _payBackRpc('ghost_payback', params);
    subscribeToChannel(
      ref: ref,
      channelName: 'expense_list:$groupId',
      table: 'expense_update_checker',
      onEvent: (payload) {},
    );
  }

  static Future<Object?> _payBackRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    return await supabase.rpc(function, params: params);
  }
}
""";
      expect(missingTargets(rebuild, [drifted]), [
        '.from ghost_table',
        '.rpc delete_missing',
        '.rpc ghost_payback',
        '.rpc ghost_rpc',
        'realtime expense_update_checker',
      ]);

      const clean = r"""
class Repo {
  static const String deleteRpcName = 'delete_group';

  Future<void> calls() async {
    await supabase.from('user').select();
    await supabase.rpc(deleteRpcName, params: {});
    await _payBackRpc('pay_back', params);
    syncInFilterChannels(
      ref: ref,
      prefix: 'group_list:checker',
      table: 'group_update_checker',
      column: 'group_id',
      values: ids,
      onEvent: (payload) {
        // the user's list reloads; a quote here must not end the call
      },
    );
  }
}
""";
      expect(missingTargets(rebuild, [clean]), isEmpty);
    },
  );

  group('the real tree', () {
    late RebuildSet rebuild;
    late List<String> lib;
    setUpAll(() {
      rebuild = RebuildSet.load();
      lib = _libSources();
    });

    test(
      'every .from relation and .rpc function lib/ reaches exists in the rebuild set',
      () {
        expect(lib.expand(clientRelations), isNotEmpty);
        expect(lib.expand(clientRpcs), isNotEmpty);
        expect(
          missingTargets(rebuild, lib).where((m) => !m.startsWith('realtime ')),
          isEmpty,
        );
      },
    );

    test(
      'every table lib/ subscribes to is in the supabase_realtime publication',
      () {
        expect(lib.expand(clientRealtimeTables), isNotEmpty);
        expect(
          missingTargets(rebuild, lib).where((m) => m.startsWith('realtime ')),
          isEmpty,
        );
      },
    );
  });
}
