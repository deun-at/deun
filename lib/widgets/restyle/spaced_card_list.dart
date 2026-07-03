import 'package:flutter/material.dart';

/// The gap between cards in the SPACED list preset (F143).
///
/// One value everywhere so the group list, friend-request lists, and any other
/// spaced card list share an identical rhythm — the inconsistency F143 fixes
/// was each list picking its own ad-hoc [Padding] gap.
const double kSpacedCardGap = 10;

/// SPACED card-list preset (F143): each item is its own card, separated from the
/// next by [kSpacedCardGap]. The companion to the NON-SPACED [CardColumn]
/// (joined rows, one card). Callers pass already-built cards (e.g. `SoftCard`s);
/// this only owns the consistent inter-card gap.
///
/// For lists that flatten their cards into a shared [ListView] alongside section
/// labels (and route them through the staggered entrance), use
/// [spacedCardItems] instead so the gap is applied to the flat item list.
class SpacedCardList extends StatelessWidget {
  const SpacedCardList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spacedCardItems(children),
    );
  }
}

/// Interleaves a [kSpacedCardGap] between each of [children] and returns the
/// flat list — for callers that splice spaced cards into an existing
/// [ListView]/`Column` (e.g. the friend list's section-labelled stagger).
List<Widget> spacedCardItems(List<Widget> children) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(const SizedBox(height: kSpacedCardGap));
    out.add(children[i]);
  }
  return out;
}
