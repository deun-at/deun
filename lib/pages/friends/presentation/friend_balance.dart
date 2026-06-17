import 'package:deun/widgets/restyle/balance_pill.dart';

/// Maps a friend's net [shareAmount] to a [BalanceState] for the balance label.
///
/// A positive amount means the friend owes you ([BalanceState.owed]); a negative
/// amount means you owe the friend ([BalanceState.owe]); zero is settled.
///
/// [shareAmount] is already normalized to exactly `0` below the 0.01 threshold by
/// `FriendshipRepository.fetchData`, so a plain equality check is sufficient.
BalanceState friendBalanceState(double shareAmount) {
  if (shareAmount > 0) return BalanceState.owed;
  if (shareAmount < 0) return BalanceState.owe;
  return BalanceState.settled;
}
