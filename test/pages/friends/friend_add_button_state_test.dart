import 'package:deun/pages/friends/presentation/friend_add_button_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendAddButtonState', () {
    test('returns add when the email is not in the requested set', () {
      final state = friendAddButtonState(
        'alice@example.com',
        const {'bob@example.com'},
      );
      expect(state, FriendAddButtonState.add);
    });

    test('returns requested when the email is in the requested set', () {
      final state = friendAddButtonState(
        'bob@example.com',
        const {'bob@example.com'},
      );
      expect(state, FriendAddButtonState.requested);
    });

    test('is case-insensitive on the email', () {
      final state = friendAddButtonState(
        'Bob@Example.com',
        const {'bob@example.com'},
      );
      expect(state, FriendAddButtonState.requested);
    });

    test('returns add for an empty requested set', () {
      final state = friendAddButtonState('alice@example.com', const {});
      expect(state, FriendAddButtonState.add);
    });
  });
}
