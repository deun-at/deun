import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/claim_summary_view_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';

/// The dark summary card (hero style): your share, claimed/total progress,
/// unclaimed remainder and per-member totals. Mirrors the group balance hero's
/// tinted-surface treatment so it reads as the screen's focal card.
class ClaimSummaryCard extends StatelessWidget {
  const ClaimSummaryCard({
    super.key,
    required this.summary,
    required this.display,
    required this.currency,
  });

  final ClaimSummary summary;
  final MemberDisplay display;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    // DESIGN_SPEC §9: fixed dark-ink focal card (#16181A), not group-tinted —
    // ink/onInk stay dark in both brightnesses.
    final Color heroSurface = semantic.ink;
    final Color onHero = semantic.onInk;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    return Container(
      width: double.infinity,
      // F174(a): mockup padding is 18×20 (vertical × horizontal), not all(20).
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // F174(a): the header baseline-aligns the big amount (left) with a
          // stacked right column ("you claimed" over the item count).
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.claimYourShare,
                      style: textTheme.labelLarge?.copyWith(color: onHeroMuted),
                    ),
                    const SizedBox(height: 6),
                    MoneyText(
                      summary.yourShare,
                      currency: currency,
                      style: textTheme.displaySmall?.copyWith(color: onHero),
                      animate: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // F174(a): stacked right column — muted "you claimed" label over
              // the bold white item count, bottom-aligned with the amount.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.claimYouClaimedLabel,
                    style: textTheme.bodySmall?.copyWith(color: onHeroMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.claimYouClaimedItems(summary.yourClaimedCount),
                    style: textTheme.titleSmall?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // F174(a): track rgba(white,0.12) with 16/7 margins.
          const SizedBox(height: 16),
          // F128: green success fill on the dark card (not the on-ink tone).
          ProgressBar(
            value: summary.progress,
            fillColor: semantic.success,
            trackColor: onHero.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                l10n.claimProgressLabel(
                  l10n.toCurrency(summary.claimed, currency.code),
                  l10n.toCurrency(summary.total, currency.code),
                ),
                style: textTheme.bodySmall?.copyWith(color: onHeroMuted),
              ),
              const Spacer(),
              // F128/F174(a): remaining amount in amber "left" tone; once fully
              // claimed the figure flips to the green success tone (not muted).
              Text(
                summary.isFullyClaimed
                    ? l10n.claimAllClaimed
                    : l10n.claimLeftLabel(
                        l10n.toCurrency(summary.unclaimed, currency.code),
                      ),
                style: textTheme.bodySmall?.copyWith(
                  color: summary.isFullyClaimed
                      ? semantic.success
                      : semantic.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (summary.memberTotals.isNotEmpty) ...[
            // F174(a): divider rgba(white,0.1) with 14/12 margins.
            const SizedBox(height: 14),
            Divider(height: 1, color: onHero.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            // F129/F174(c): per-person totals are equal-width chips that always
            // fit the card (flex:1, 6px gaps) — no horizontal scroll, so nothing
            // paints past the rounded edge.
            Row(
              children: [
                for (final m in summary.memberTotals) ...[
                  Expanded(
                    child: _MemberTotalChip(
                      name: display.nameOf(m.email),
                      colorKey: m.email,
                      amount: m.amount,
                      isYou: display.isYou(m.email),
                      onHero: onHero,
                      currency: currency,
                    ),
                  ),
                  if (m != summary.memberTotals.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One member's claim total as a compact chip in the horizontal per-person
/// strip: avatar + amount only (no name/label, per the v3 handoff), on a faint
/// tinted background (the "you" accent for the current persona). Lives on the
/// dark-ink hero card, so tints are keyed off [onHero] / primary and read
/// correctly in both themes.
class _MemberTotalChip extends StatelessWidget {
  const _MemberTotalChip({
    required this.name,
    required this.colorKey,
    required this.amount,
    required this.isYou,
    required this.onHero,
    required this.currency,
  });

  final String name;
  final String colorKey;
  final double amount;
  final bool isYou;
  final Color onHero;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final chipBg = isYou
        ? primary.withValues(alpha: 0.22)
        : onHero.withValues(alpha: 0.08);
    // F174(b): the chip is a vertical stack — 28px avatar on top, then the
    // amount underneath — with a 13px radius and 9×4 padding (mockup L1224-1227).
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberAvatar(
            name: name,
            colorKey: colorKey,
            radius: 14,
            isYou: isYou,
          ),
          const SizedBox(height: 5),
          MoneyText(
            amount,
            currency: currency,
            style: textTheme.bodySmall?.copyWith(
              color: onHero,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
