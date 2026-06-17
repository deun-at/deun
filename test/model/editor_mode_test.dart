import 'package:deun/pages/expenses/data/editor_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveEditorMode', () {
    test('a single entry with no explicit itemized override is Quick', () {
      expect(
        resolveEditorMode(entryCount: 1, itemizedOverride: false),
        EditorMode.quick,
      );
    });

    test('a single entry IS itemized when the toggle forces itemized', () {
      expect(
        resolveEditorMode(entryCount: 1, itemizedOverride: true),
        EditorMode.itemized,
      );
    });

    test('multiple entries are always itemized regardless of override', () {
      expect(
        resolveEditorMode(entryCount: 3, itemizedOverride: false),
        EditorMode.itemized,
      );
      expect(
        resolveEditorMode(entryCount: 2, itemizedOverride: true),
        EditorMode.itemized,
      );
    });
  });

  group('isSingleEntryQuick', () {
    test('true only when exactly one entry and not forced itemized', () {
      expect(isSingleEntryQuick(entryCount: 1, itemizedOverride: false), true);
      expect(isSingleEntryQuick(entryCount: 1, itemizedOverride: true), false);
      expect(isSingleEntryQuick(entryCount: 2, itemizedOverride: false), false);
    });
  });
}
