import 'package:deun/pages/groups/presentation/group_share_view_model.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Use the real light semantic palette so the test pins the intended roles.
  const s = SemanticColors.light;

  group('shareBalanceColor', () {
    test('positive amount (you are owed / settled) -> success', () {
      expect(shareBalanceColor(12.50, s), s.success);
    });

    test('negative amount (you owe) -> danger', () {
      expect(shareBalanceColor(-12.50, s), s.danger);
    });

    test('settled (zero / below rounding threshold) -> success', () {
      expect(shareBalanceColor(0, s), s.success);
      expect(shareBalanceColor(0.004, s), s.success);
      expect(shareBalanceColor(-0.004, s), s.success);
    });
  });
}
