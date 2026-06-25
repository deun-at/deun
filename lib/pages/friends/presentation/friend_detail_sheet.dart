import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/friends/presentation/friend_detail_view_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Friend detail sheet (Screen 5 / "friend detail" sheet — restyle, E4-T2).
///
/// Shows the friend's avatar + identity and the net balance ([MoneyText],
/// semantic). When the current user owes the friend, the available pay-back
/// methods (PayPal / Copy IBAN, filtered by what the friend has, plus a
/// always-present "Mark as paid") are rendered as cards mirroring the group
/// settle-up sheet (E4-T1). A destructive "Remove as friend" action sits at the
/// bottom.
///
/// This is a presentation-only restyle: the pay-back (`GroupRepository`),
/// remove-friend (`FriendshipRepository.remove`) and PayPal/IBAN handling are
/// the same logic as the previous `openFriendshipDialog`.
class FriendDetailSheet extends StatelessWidget {
  const FriendDetailSheet({super.key, required this.friendship});

  final Friendship friendship;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = friendship.user;

    // Negative share = the current user owes the friend → pay-back options.
    final bool owesFriend = friendship.shareAmount < -0.01;
    final methods = owesFriend ? friendPayBackMethods(user) : const <FriendPayBackMethod>[];

    return SheetScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity + balance hero.
          Row(
            children: [
              MemberAvatar(name: user.displayName, colorKey: user.email, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.fullUsername,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyText(
                friendship.shareAmount,
                semantic: MoneySemantic.auto,
                style: textTheme.titleLarge,
              ),
            ],
          ),
          if (owesFriend) ...[
            const SizedBox(height: 20),
            SectionLabel(l10n.payBackDialog(user.displayName, friendship.shareAmount.abs())),
            const SizedBox(height: 10),
            for (final method in methods) ...[
              _PayBackCard(method: method, friendship: friendship),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 10),
          _RemoveFriendCard(user: user),
        ],
      ),
    );
  }
}

/// One pay-back method card (PayPal / Copy IBAN / Mark as paid). Mirrors the
/// group settle-up `_MethodCard` treatment (E4-T1).
class _PayBackCard extends StatelessWidget {
  const _PayBackCard({required this.method, required this.friendship});

  final FriendPayBackMethod method;
  final Friendship friendship;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final IconData icon;
    final String title;
    final String subtitle;
    final VoidCallback? onTap;
    final IconData trailing;

    switch (method) {
      case FriendPayBackMethod.paypal:
        icon = Icons.account_balance_wallet_outlined;
        title = l10n.paymentMethodPaypal;
        subtitle = l10n.paymentMethodPaypalSubtitle;
        trailing = Icons.open_in_new;
        onTap = () => _openPaypal(context);
        break;
      case FriendPayBackMethod.iban:
        icon = Icons.account_balance_outlined;
        title = l10n.paymentMethodIban;
        subtitle = l10n.paymentMethodIbanSubtitle;
        trailing = Icons.copy_outlined;
        onTap = () => _copyIban(context);
        break;
      case FriendPayBackMethod.markPaid:
        icon = Icons.credit_score_outlined;
        title = l10n.payBackDialogDone;
        subtitle = l10n.friendPayBackMarkPaidSubtitle;
        trailing = Icons.check_circle_outline;
        onTap = () => _markPaid(context);
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
          Icon(trailing, size: 18, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  /// Opens the friend's PayPal.me link prefilled with the owed amount
  /// (unchanged from the previous friend sheet).
  Future<void> _openPaypal(BuildContext context) async {
    final paypalMe = friendship.user.paypalMe;
    if (paypalMe == null || paypalMe.isEmpty) return;
    final paypalUri = Uri.parse('https://www.paypal.me/$paypalMe/${friendship.shareAmount.abs()}');
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

  /// Copies the friend's IBAN to the clipboard (unchanged logic; now with a
  /// confirmation snackbar reusing the E4-T1 key).
  Future<void> _copyIban(BuildContext context) async {
    final iban = friendship.user.iban;
    if (iban == null || iban.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: iban));
    if (context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.paymentIbanCopied);
    }
  }

  /// Records the payment via the existing [GroupRepository.payBackAll] RPC, then
  /// closes the sheet (same behavior as the previous friend sheet).
  Future<void> _markPaid(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final user = friendship.user;
    try {
      await GroupRepository.payBackAll(context, user.email);
      if (context.mounted) {
        showSnackBar(context, l10n.payBackSuccess(user.fullUsername, friendship.shareAmount.abs()));
      }
    } catch (e) {
      debugPrint(e.toString());
      if (context.mounted) {
        showSnackBar(context, l10n.payBackError);
      }
    } finally {
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}

/// Destructive "Remove as friend" action card.
class _RemoveFriendCard extends StatelessWidget {
  const _RemoveFriendCard({required this.user});

  final SupaUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return SoftCard(
      color: colorScheme.errorContainer.withValues(alpha: 0.4),
      onTap: () => _confirmRemove(context),
      child: Row(
        children: [
          Icon(Icons.person_remove_outlined, color: colorScheme.error),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.friendshipDialogRemoveAsFriend,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirm + remove. Reuses [FriendshipRepository.remove] and the original
  /// two-pop close (confirm dialog + sheet).
  void _confirmRemove(BuildContext sheetContext) {
    showDialog<void>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        content: Text(AppLocalizations.of(dialogContext)!.removeFriend(user.displayName)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () async {
              try {
                await FriendshipRepository.remove(user.email);
                if (dialogContext.mounted) {
                  showSnackBar(
                    dialogContext,
                    AppLocalizations.of(dialogContext)!.friendRemoved(user.displayName),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  showSnackBar(dialogContext, AppLocalizations.of(dialogContext)!.generalError);
                }
              } finally {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Close confirm dialog.
                }
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext); // Close the friend sheet.
                }
              }
            },
            child: Text(AppLocalizations.of(dialogContext)!.remove),
          ),
        ],
      ),
    );
  }
}

/// Opens the [FriendDetailSheet] as a modal bottom sheet.
void openFriendDetailSheet(BuildContext context, Friendship friendship) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    backgroundColor: Colors.transparent,
    builder: (_) => FriendDetailSheet(friendship: friendship),
  );
}
