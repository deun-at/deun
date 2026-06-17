import 'package:deun/pages/friends/presentation/friend_balance.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendBalanceState', () {
    test('positive shareAmount means the friend owes you (owed)', () {
      expect(friendBalanceState(12.5), BalanceState.owed);
    });

    test('negative shareAmount means you owe the friend (owe)', () {
      expect(friendBalanceState(-12.5), BalanceState.owe);
    });

    test('zero shareAmount is settled', () {
      expect(friendBalanceState(0), BalanceState.settled);
    });
  });
}
