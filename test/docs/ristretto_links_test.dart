import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every relative Markdown link inside `docs/ristretto/` resolves to a file
/// that exists.
///
/// Archiving a plan moves it a directory deeper, which silently breaks both
/// directions at once: the links inside it that pointed at siblings, and the
/// links elsewhere that pointed at it. Fourteen had accumulated that way before
/// anyone looked — including every archived plan's link to manual-checks.md.
/// Nothing else in the gate reads these documents, so this is the only thing
/// that would notice.
void main() {
  test('no ristretto doc links to a file that does not exist', () {
    final root = Directory('docs/ristretto');
    expect(root.existsSync(), isTrue, reason: 'run from the repository root');

    // `[label](target.md)` with an optional #anchor.
    final link = RegExp(r'\]\(([^)\s]+\.md)(#[^)\s]*)?\)');
    final broken = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final dir = entity.parent.path;
      for (final match in link.allMatches(entity.readAsStringSync())) {
        final target = match.group(1)!;
        if (target.startsWith('http')) continue;
        if (File('$dir/$target').existsSync()) continue;
        broken.add('${entity.path.replaceAll(r'\', '/')} -> $target');
      }
    }

    expect(
      broken..sort(),
      isEmpty,
      reason:
          'a relative link points at a file that is not there — most often a '
          'plan that has since been archived, or an archived plan still '
          'linking as though it were one directory up',
    );
  });
}
