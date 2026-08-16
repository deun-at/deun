import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/users/user_model.dart';

import '../../../main.dart';

class Friendship {
  late SupaUser user;
  late String status;
  late bool isIncomingRequest;

  List<CurrencyAmount> _balances = const [];
  CurrencyBreakdown? _breakdown;

  /// This friend's outstanding amount in each mutual group, in that group's own
  /// currency, unsummed. The fold is [breakdown]'s job so nothing ever adds two
  /// currencies together.
  List<CurrencyAmount> get balances => _balances;
  set balances(List<CurrencyAmount> value) {
    _balances = value;
    _breakdown = null;
  }

  /// Primary-inline / remainder-collapsed view of [balances]. Cached: the row,
  /// the sheet and the sort all read it.
  CurrencyBreakdown get breakdown =>
      _breakdown ??= friendBalancesByCurrency([this]);

  /// The friend's balance in the PRIMARY currency. Direction, semantic colour,
  /// the PayPal link and the sort order all follow this one figure — never a
  /// sum across currencies. Already 0 when settled, because a settled currency
  /// is dropped from the breakdown.
  double get shareAmount => breakdown.primary.amount;

  /// The currency [shareAmount] is expressed in.
  Currency get currency => breakdown.primary.currency;

  void loadDataFromJson(Map<String, dynamic> json) {
    if (json["requester"]["email"] == supabase.auth.currentUser?.email) {
      isIncomingRequest = false;
      user = SupaUser.fromJson(json["addressee"]);
    } else {
      isIncomingRequest = true;
      user = SupaUser.fromJson(json["requester"]);
    }

    status = json["status"];
  }
}

/// Per-currency breakdown of the net balance across [friendships]. Called with
/// the single friendship behind a row or a sheet; the list form is what makes
/// the fold reusable and is the shape [Friendship.breakdown] delegates to.
CurrencyBreakdown friendBalancesByCurrency(List<Friendship> friendships) =>
    currencyBreakdownOf([for (final f in friendships) ...f.balances]);
