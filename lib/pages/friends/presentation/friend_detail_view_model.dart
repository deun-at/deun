import 'package:deun/pages/users/user_model.dart';

/// A pay-back method a friend can be settled through, derived purely from the
/// friend's [SupaUser] contact fields.
///
/// Mirrors `PaymentMethod` from the group settle-up sheet (E4-T1) but for the
/// friend detail sheet: "mark paid" replaces the group sheet's "cash" as the
/// always-available option, since settling a friendship records the payment via
/// `GroupRepository.payBackAll`.
enum FriendPayBackMethod { paypal, iban, markPaid }

/// The pay-back methods the [user] can actually be settled through, filtered
/// from their `paypalMe` / `iban` contact fields. "Mark paid" is always offered.
/// PayPal/IBAN appear only when the friend has a non-empty value.
///
/// Same filtering convention as the group settle-up `paymentMethodsFor`
/// (blank/whitespace is treated as absent).
List<FriendPayBackMethod> friendPayBackMethods(SupaUser user) {
  final methods = <FriendPayBackMethod>[];
  if ((user.paypalMe ?? '').trim().isNotEmpty) {
    methods.add(FriendPayBackMethod.paypal);
  }
  if ((user.iban ?? '').trim().isNotEmpty) {
    methods.add(FriendPayBackMethod.iban);
  }
  methods.add(FriendPayBackMethod.markPaid);
  return methods;
}
