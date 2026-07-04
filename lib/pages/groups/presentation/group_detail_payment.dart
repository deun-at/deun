import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/restyle/success_badge.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/reminder_repository.dart';
import '../provider/group_detail.dart';
import '../data/group_model.dart';
import '../data/group_repository.dart';
import 'payment_view_model.dart';

/// Screen 10 — Settle up / payment view (restyle).
///
/// A group-tinted color hero summarizing the overall balance, a "You pay"
/// section (members the user owes, each with a Pay action into a payment-method
/// detail sheet) and an "Owes you" section (members who owe the user, each with
/// a Remind action). Settlement amounts come straight from
/// [Group.groupSharesSummary] / [Group.totalShareAmount] computed in
/// `group_model.dart`; nothing is recomputed here.
///
/// F155/F58: this is a full-page drill-down (routed via [sharedAxisPage] like
/// the edit/statistics screens) with a [DeunHeader] back-arrow — not a routed
/// bottom sheet — so there is no drag-to-close ambiguity.
class GroupPaymentBottomSheet extends ConsumerWidget {
  const GroupPaymentBottomSheet({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ThemeBuilder(
      colorValue: group.colorValue,
      builder: (context) {
        return Scaffold(
          body: Column(
            children: [
              DeunHeader(title: l10n.paymentTitle),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final Group? detail = ref.watch(groupDetailProvider(group.id)).value;

                      if (detail == null) {
                        return const ShimmerCardList(height: 50, listEntryLength: 8);
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                        child: _PaymentBody(group: detail),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentBody extends StatelessWidget {
  const _PaymentBody({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final partition = PaymentPartition.fromSummary(group.groupSharesSummary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OverallHero(group: group),
        const SizedBox(height: 20),
        if (partition.isEmpty)
          _AllSettled(l10n: l10n)
        else ...[
          if (partition.youPay.isNotEmpty) ...[
            SectionLabel(l10n.paymentYouPay),
            const SizedBox(height: 10),
            for (final entry in partition.youPay)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PayRow(group: group, entry: entry),
              ),
          ],
          if (partition.owesYou.isNotEmpty) ...[
            if (partition.youPay.isNotEmpty) const SizedBox(height: 14),
            SectionLabel(l10n.paymentOwesYou),
            const SizedBox(height: 10),
            for (final entry in partition.owesYou)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OwesRow(group: group, entry: entry),
              ),
          ],
        ],
      ],
    );
  }
}

/// Group-tinted color hero showing the overall balance via [MoneyText].
class _OverallHero extends StatelessWidget {
  const _OverallHero({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color heroSurface = isDark ? colorScheme.primaryContainer : colorScheme.primary;
    final Color onHero = isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    final net = group.totalShareAmount;
    final bool settled = net.abs() < 0.005;

    final String leadLabel;
    if (settled) {
      leadLabel = l10n.balanceSettled;
    } else if (net > 0) {
      leadLabel = l10n.paymentBalanceOwed;
    } else {
      leadLabel = l10n.balanceOwe;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leadLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onHeroMuted),
          ),
          const SizedBox(height: 6),
          MoneyText(
            settled ? 0 : net.abs(),
            semantic: MoneySemantic.neutral,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: onHero),
            animate: true,
          ),
        ],
      ),
    );
  }
}

/// A "You pay" row: payee avatar + amount + a Pay action that opens the
/// payment-method detail sheet.
class _PayRow extends StatelessWidget {
  const _PayRow({required this.group, required this.entry});

  final Group group;
  final PaymentEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SoftCard(
      child: Row(
        children: [
          MemberAvatar(name: entry.summary.displayName, colorKey: entry.email),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.summary.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                MoneyText(
                  entry.amount,
                  semantic: MoneySemantic.negative,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: l10n.paymentPay,
            icon: Icons.payments_outlined,
            onPressed: () => _openMethodSheet(context),
            compact: true,
          ),
        ],
      ),
    );
  }

  void _openMethodSheet(BuildContext context) {
    // Capture the sheet's own context (the payment sheet) so we can pop it after
    // a successful settle, preserving the original two-pop close behavior.
    final modalContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: kSheetAnimationStyle,
      barrierColor: kSheetBarrierColor,
      builder: (_) => ThemeBuilder(
        colorValue: group.colorValue,
        builder: (_) => _PaymentMethodSheet(
          group: group,
          entry: entry,
          modalContext: modalContext,
        ),
      ),
    );
  }
}

/// An "Owes you" row: payee avatar + amount + a Remind action.
class _OwesRow extends StatefulWidget {
  const _OwesRow({required this.group, required this.entry});

  final Group group;
  final PaymentEntry entry;

  @override
  State<_OwesRow> createState() => _OwesRowState();
}

class _OwesRowState extends State<_OwesRow> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SoftCard(
      child: Row(
        children: [
          MemberAvatar(name: widget.entry.summary.displayName, colorKey: widget.entry.email),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry.summary.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // F181: lead with muted "owes you" copy, amount stays semantic
                // green (v3 mockup L1092, design_10).
                Row(
                  children: [
                    Text(
                      '${l10n.paymentOwesYouInline} ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    MoneyText(
                      widget.entry.amount,
                      semantic: MoneySemantic.positive,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // v3 (F59): plain gray tonal pill, no icon. surfaceContainer/onSurface
          // map to the prototype's #F1EFE9 / #16181A and adapt in dark mode.
          SecondaryButton(
            label: l10n.paymentRemind,
            onPressed: _sending ? null : _remind,
            background: Theme.of(context).colorScheme.surfaceContainer,
            foreground: Theme.of(context).colorScheme.onSurface,
            compact: true,
          ),
        ],
      ),
    );
  }

  /// Reuses the existing reminder path (24h cooldown + push notification +
  /// snackbar) from group_detail.dart.
  Future<void> _remind() async {
    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final lastReminder = await ReminderRepository.getLastReminder(widget.group.id, widget.entry.email);
      if (lastReminder != null && DateTime.now().difference(lastReminder).inHours < 24) {
        if (mounted) showSnackBar(context, l10n.reminderCooldown);
        return;
      }

      await ReminderRepository.sendReminder(widget.group.id, widget.entry.email);

      if (mounted) {
        sendPaymentReminderNotification(
          context,
          widget.group.id,
          {widget.entry.email},
          widget.entry.amount,
        );
        showSnackBar(context, l10n.reminderSent(widget.entry.summary.displayName));
      }
    } catch (e) {
      debugPrint('Reminder failed for ${widget.entry.email}: $e');
      if (mounted) showSnackBar(context, l10n.generalError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

/// Empty / all-settled state.
class _AllSettled extends StatelessWidget {
  const _AllSettled({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          SuccessBadge(icon: Icons.check_circle_outline, size: 48, color: semantic.success),
          const SizedBox(height: 12),
          Text(
            l10n.paymentAllSettled,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// The payment-method detail sheet for a single payee: only the methods the
/// payee actually has (filtered via [paymentMethodsFor]) plus a sticky CTA.
class _PaymentMethodSheet extends StatelessWidget {
  const _PaymentMethodSheet({
    required this.group,
    required this.entry,
    required this.modalContext,
  });

  final Group group;
  final PaymentEntry entry;

  /// The payment sheet's context, popped together with this sheet once the
  /// balance is settled (so the now-stale row disappears).
  final BuildContext modalContext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final methods = paymentMethodsFor(entry.summary);

    return SheetScaffold(
      title: entry.summary.displayName,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoneyText(
            entry.amount,
            semantic: MoneySemantic.negative,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final method in methods) ...[
            _MethodCard(method: method, entry: entry),
            const SizedBox(height: 10),
          ],
        ],
      ),
      footer: PrimaryButton(
        onPressed: () => _settle(context),
        label: l10n.paymentPayAmount(entry.amount),
      ),
    );
  }

  /// Records the payment via the existing [GroupRepository.payBack] RPC, then
  /// closes both this sheet and the parent payment sheet.
  Future<void> _settle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await GroupRepository.payBack(modalContext, group.id, entry.email, entry.amount);
      if (modalContext.mounted) {
        showSnackBar(modalContext, l10n.payBackSuccess(entry.summary.displayName, entry.amount));
      }
    } catch (e) {
      if (context.mounted) showSnackBar(context, l10n.payBackError);
    } finally {
      // Pop the method sheet and the payment sheet (the settled row is gone).
      if (context.mounted) Navigator.pop(context);
      if (modalContext.mounted) Navigator.pop(modalContext);
    }
  }
}

/// One payment-method card (PayPal / IBAN / Cash) with method-specific tap
/// behavior (open PayPal.me link, copy IBAN, or no-op for cash).
class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.method, required this.entry});

  final PaymentMethod method;
  final PaymentEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final IconData icon;
    final String title;
    final String subtitle;
    final VoidCallback? onTap;

    switch (method) {
      case PaymentMethod.paypal:
        icon = Icons.account_balance_wallet_outlined;
        title = l10n.paymentMethodPaypal;
        subtitle = l10n.paymentMethodPaypalSubtitle;
        onTap = () => _openPaypal(context);
        break;
      case PaymentMethod.iban:
        icon = Icons.account_balance_outlined;
        title = l10n.paymentMethodIban;
        subtitle = l10n.paymentMethodIbanSubtitle;
        onTap = () => _copyIban(context);
        break;
      case PaymentMethod.cash:
        icon = Icons.payments_outlined;
        title = l10n.paymentMethodCash;
        subtitle = l10n.paymentMethodCashSubtitle;
        onTap = null;
        break;
    }

    return SoftCard(
      color: colorScheme.surfaceContainerHigh,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              method == PaymentMethod.iban ? Icons.copy_outlined : Icons.open_in_new,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  Future<void> _openPaypal(BuildContext context) async {
    final paypalMe = entry.summary.paypalMe;
    if (paypalMe == null || paypalMe.isEmpty) return;
    final paypalUri = Uri.parse('https://www.paypal.me/$paypalMe/${entry.amount}');
    bool launched = false;
    try {
      launched = await launchUrl(paypalUri);
    } catch (e) {
      debugPrint('Could not launch PayPal link: $e');
    }
    if (!launched && context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.generalError);
    }
  }

  Future<void> _copyIban(BuildContext context) async {
    final iban = entry.summary.iban;
    if (iban == null || iban.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: iban));
    if (context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.paymentIbanCopied);
    }
  }
}
