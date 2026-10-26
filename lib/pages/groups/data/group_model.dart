import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../helper/helper.dart';
import '../../expenses/data/expense_model.dart';
import '../data/group_member_model.dart';

class GroupSharesSummary {
  String displayName = '';
  String? paypalMe;
  String? iban;
  double shareAmount = 0;
}

/// A `group_shares_summary` amount: null, unparseable or non-finite reads as 0,
/// so one bad row can neither throw mid-calculation nor poison a balance with
/// NaN (group-model-parse-safety).
double _parseAmount(Object? value) {
  final parsed = double.tryParse('$value') ?? 0;
  return parsed.isFinite ? parsed : 0;
}

/// A row's `paid_by`/`paid_for` email, or null when there is none to key it by.
String? _rowEmail(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class Group {
  late String id;
  late String name;
  late int colorValue;
  late bool simplifiedExpenses;
  late String createdAt;
  late String? userId;

  /// ISO 4217 currency code all amounts in this group are expressed in.
  /// Backfilled to EUR for legacy rows and defaulted for new groups. Default-
  /// initialized (not `late`) so a Group built without JSON still formats.
  String currencyCode = kDefaultCurrencyCode;

  /// The group's current invite token (`group.invite_token`). Every invite
  /// link carries it, and `join_group` refuses any other. Only the group's
  /// members and its creator can read it. Empty on a Group built without JSON.
  String inviteToken = '';

  /// The group's currency as a value object — the single conversion point from
  /// the stored `currency_code` string to the type the money pipeline takes.
  Currency get currency => Currency.fromCode(currencyCode);

  late List<GroupMember> groupMembers;

  /// The summary outputs. Default-initialised (not `late`) so a calculation
  /// that throws inside [loadDataFromJson]'s guard leaves readable zeros, not a
  /// LateInitializationError on the group list (group-model-parse-safety).
  Map<String, GroupSharesSummary> groupSharesSummary = {};
  double totalExpenses = 0;
  double totalShareAmount = 0;

  late List<Expense>? expenses;

  /// Whether [email]'s own membership row is starred. A star another member
  /// set never counts; with nobody signed in nothing is starred.
  bool isFavoriteFor(String? email) {
    if (email == null) return false;
    return groupMembers.any((m) => m.email == email && m.isFavorite);
  }

  /// Members who are still part of the group. Every *picker* (new-expense
  /// paid-by, share/split, the group-edit roster) binds to this; the ledger, the
  /// group-detail balance list and past expenses keep binding to
  /// [groupMembers] so a removed member stays visible where they actually spent.
  List<GroupMember> get activeMembers =>
      groupMembers.where((m) => !m.isRemoved).toList();

  /// Emails of the members whose `group_member` row is soft-removed.
  ///
  /// They stay in [groupMembers] and in [groupSharesSummary] on purpose
  /// (group-member-removal), but they can no longer be a party to a payback —
  /// so every settle-up surface filters on this. See
  /// `PaymentPartition.fromSummary`.
  Set<String> get removedMemberEmails => {
    for (final member in groupMembers)
      if (member.isRemoved) member.email,
  };

  /// Every member's OWN net position in the group, keyed by email — the same
  /// `group_shares_summary.total_share_amount` `GroupRepository.removeMember`
  /// reads one row of, parsed from rows the detail fetch ALREADY returns.
  ///
  /// The value is identical across a member's rows (one net per `paid_for`), so
  /// this is a keyed read, not a sum. Deliberately NOT rounded: [isSettled] owns
  /// the epsilon, so the threshold is applied to one value in one place.
  ///
  /// Default-initialised (not `late`) so a Group built without JSON — every test
  /// fixture in this repo — still reads as all-zero rather than throwing.
  Map<String, double> memberBalances = {};

  /// A group nobody else has joined yet. The group-detail add-members call to
  /// action hangs off this: a solo group has exactly one thing worth doing.
  /// Counts ACTIVE members, so a group whose only other member was soft-removed
  /// is solo again.
  bool get isSolo => activeMembers.length < 2;

  /// The amount the current user should settle with [email] in this group, or
  /// null when there is nothing to settle — either the pair reads settled or the
  /// balance runs the other way (they owe the user).
  ///
  /// Positive = the user pays [email]. This is the SINGLE definition of "what a
  /// settle-up with this person is worth": the payment screen shows
  /// `PaymentEntry.amount` and `GroupRepository.payBackAll` settles this, and both
  /// read the already-rounded `groupSharesSummary` entry instead of
  /// re-accumulating it (`payBackAll` used to re-sum and re-round it against a
  /// hardcoded 0.01 of its own).
  double? amountToSettleWith(String email) {
    final summary = groupSharesSummary[email];
    if (summary == null) return null;
    if (isSettled(summary.shareAmount, currency)) return null;
    if (summary.shareAmount > 0) return null;
    return summary.shareAmount.abs();
  }

  static const groupSelectString =
      '*, group_shares_summary_helper:group_shares_summary!inner(*), group_shares_summary(*, ...paid_by(paid_by_display_name:display_name, paid_by_paypal_me:paypal_me, paid_by_iban:iban), ...paid_for(paid_for_display_name:display_name, paid_for_paypal_me:paypal_me, paid_for_iban:iban)), group_member(*, ...user(display_name:display_name, username:username, username_code:username_code, is_guest:is_guest))';

  void loadDataFromJson(
    Map<String, dynamic> json, {
    required String? currentUserEmail,
  }) {
    id = json["id"];
    // Defensive: a partially-written row could carry a null name. Never let one
    // bad row throw here — it would fail the whole list fetch (loadDataFromJson
    // runs per group). Fall back to an empty name so the group still loads and
    // can be renamed or deleted in-app.
    name = json["name"] ?? '';
    colorValue = json["color_value"] ?? ColorSeed.baseColor.color.toARGB32();
    simplifiedExpenses = json["simplified_expenses"] ?? false;
    createdAt = json["created_at"];
    userId = json["user_id"];
    currencyCode = json["currency_code"] ?? kDefaultCurrencyCode;
    inviteToken = json["invite_token"] ?? '';

    groupMembers = [];
    if (json["group_member"] != null) {
      for (var element in json["group_member"]) {
        GroupMember groupMember = GroupMember();
        groupMember.loadDataFromJson(element);
        groupMembers.add(groupMember);
      }
    }

    // group-member-add-flow: a bad row must never fail the whole group load —
    // the same rule the `name` and `display_name` fallbacks follow.
    memberBalances = {};
    if (json["group_shares_summary"] != null) {
      for (var element in json["group_shares_summary"]) {
        final email = _rowEmail(element['paid_for']);
        if (email == null) continue;
        memberBalances[email] = _parseAmount(element['total_share_amount']);
      }
    }

    try {
      if (simplifiedExpenses) {
        calculateGroupSharesSummarySimplified(json, currentUserEmail);
      } else {
        calculateGroupSharesSummaryDefault(json, currentUserEmail);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void calculateGroupSharesSummaryDefault(
    Map<String, dynamic> json,
    String? currentUserEmail,
  ) {
    totalExpenses = 0;
    totalShareAmount = 0;
    groupSharesSummary = {};
    if (json["group_shares_summary"] != null) {
      for (var element in json["group_shares_summary"]) {
        final paidBy = _rowEmail(element['paid_by']);
        final paidFor = _rowEmail(element['paid_for']);
        if (paidBy == null || paidFor == null) continue;

        if (paidFor == currentUserEmail) {
          totalExpenses += _parseAmount(element['total_expenses']);
          totalShareAmount = roundCurrency(
            _parseAmount(element['total_share_amount']),
            currency,
          );
        }

        if (paidBy == currentUserEmail && paidFor != currentUserEmail) {
          groupSharesSummary
              .putIfAbsent(paidFor, () => _party(element, 'paid_for', paidFor))
              .shareAmount += _parseAmount(
            element['share_amount'],
          );
        } else if (paidFor == currentUserEmail && paidBy != currentUserEmail) {
          groupSharesSummary
              .putIfAbsent(paidBy, () => _party(element, 'paid_by', paidBy))
              .shareAmount -= _parseAmount(
            element['share_amount'],
          );
        }
      }

      // settle-residue: round ONCE per counterparty, after every row of that
      // pair has been accumulated — the same rule `totalShareAmount` (the
      // server's already-summed net) has always used. Rounding after each row
      // let the two directions of a pair round in sequence, so a pair that
      // nets 3.3333… surfaced as 3.34 on the pairwise row while the group hero
      // showed 3.33. Settling 3.34 then left -0.0067 behind, which is the 0.01
      // "owes you" the user reported on 2026-08-11.
      totalExpenses = roundCurrency(totalExpenses, currency);
      for (final summary in groupSharesSummary.values) {
        summary.shareAmount = roundCurrency(summary.shareAmount, currency);
      }
    }
  }

  void calculateGroupSharesSummarySimplified(
    Map<String, dynamic> json,
    String? currentUserEmail,
  ) {
    totalExpenses = 0;
    totalShareAmount = 0;
    groupSharesSummary = {};

    final parties = <String, GroupSharesSummary>{};
    if (json["group_shares_summary"] != null) {
      Map<String, double> simplifiedExpenseArray = {};
      for (var element in json["group_shares_summary"]) {
        final paidBy = _rowEmail(element['paid_by']);
        final paidFor = _rowEmail(element['paid_for']);
        if (paidBy == null || paidFor == null) continue;

        if (paidFor == currentUserEmail) {
          totalExpenses += _parseAmount(element['total_expenses']);
          totalShareAmount = roundCurrency(
            _parseAmount(element['total_share_amount']),
            currency,
          );
        }

        // Round on load so the settlement loop below works on exact cent
        // values and its == 0 termination checks are reliable.
        simplifiedExpenseArray.putIfAbsent(
          paidFor,
          () => roundCurrency(
            _parseAmount(element['total_share_amount']),
            currency,
          ),
        );

        parties.putIfAbsent(paidBy, () => _party(element, 'paid_by', paidBy));
        parties.putIfAbsent(
          paidFor,
          () => _party(element, 'paid_for', paidFor),
        );
      }

      totalExpenses = roundCurrency(totalExpenses, currency);

      simplifiedExpenseArray = Map.fromEntries(
        simplifiedExpenseArray.entries.toList()
          ..sort((e1, e2) => e1.value.compareTo(e2.value)),
      );

      Map<String, double> finalSimplifiedExpenseArray = {};
      // Each iteration settles at least one member (set to 0 and removed), so
      // the loop is bounded by the member count. The guard is defensive: if a
      // future change breaks that invariant we bail out instead of hanging.
      int remainingIterations = simplifiedExpenseArray.length + 1;
      while (simplifiedExpenseArray.length > 1 && remainingIterations-- > 0) {
        var firstEntry = simplifiedExpenseArray.entries.first;
        var lastEntry = simplifiedExpenseArray.entries.last;

        if (firstEntry.value < lastEntry.value) {
          if (firstEntry.value.abs() <= lastEntry.value.abs()) {
            if (firstEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[lastEntry.key] = firstEntry.value;
            } else if (lastEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[firstEntry.key] = firstEntry.value
                  .abs();
            }

            simplifiedExpenseArray[firstEntry.key] = 0;
            simplifiedExpenseArray[lastEntry.key] = roundCurrency(
              lastEntry.value.abs() - firstEntry.value.abs(),
              currency,
            );
          } else {
            if (firstEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[lastEntry.key] = lastEntry.value * -1;
            } else if (lastEntry.key == currentUserEmail) {
              finalSimplifiedExpenseArray[firstEntry.key] = lastEntry.value;
            }

            simplifiedExpenseArray[firstEntry.key] = roundCurrency(
              lastEntry.value.abs() - firstEntry.value.abs(),
              currency,
            );
            simplifiedExpenseArray[lastEntry.key] = 0;
          }

          if (simplifiedExpenseArray[firstEntry.key] == 0) {
            simplifiedExpenseArray.remove(firstEntry.key);
          }

          if (simplifiedExpenseArray[lastEntry.key] == 0) {
            simplifiedExpenseArray.remove(lastEntry.key);
          }
        } else {
          break;
        }
      }

      finalSimplifiedExpenseArray.forEach((key, value) {
        groupSharesSummary[key] = parties[key]!..shareAmount = value;
      });
    }
  }

  /// The counterparty on [side] (`paid_by` / `paid_for`) of a summary row, with
  /// a zero share. A null display name (a deleted user row) falls back to the
  /// [email] it is keyed by — the `GroupMember` convention; an empty one stays.
  static GroupSharesSummary _party(
    Map<String, dynamic> element,
    String side,
    String email,
  ) => GroupSharesSummary()
    ..displayName = element['${side}_display_name'] ?? email
    ..paypalMe = element['${side}_paypal_me']
    ..iban = element['${side}_iban'];

  Map<String, dynamic> toJson() => {
    'name': name,
    'color_value': colorValue,
    'simplified_expenses': simplifiedExpenses,
    'currency_code': currencyCode,
  };
}

/// Whether [group]'s currency may still be changed, given [expenses] — the
/// group's expense rows as probed by
/// [ExpenseRepository.fetchCurrencyProbeRows].
///
/// The rule (Kittysplit's guardrail): a group's currency may be changed only
/// while every expense in it shares that currency; once any expense carries a
/// different ORIGINAL currency the picker locks, because a currency switch that
/// silently moves other people's settled balances is the single angriest review
/// class in the research.
///
/// With no evidence supplied the answer is "yes" — that is the honest reading of
/// "no expense is known to diverge", and it is what a pre-migration server (and
/// the group-create form, which has no expenses at all) produces.
bool canChangeGroupCurrency(Group group, {List<Expense> expenses = const []}) =>
    !expenses.any((e) => e.isForeignCurrencyIn(group.currency));
