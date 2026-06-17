import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/restyle/stepper_control.dart';
import 'package:flutter/material.dart';

/// Throwaway QA gallery for the E0-T4 shared restyle widgets. Renders each
/// widget with sample data so they can be eyeballed in light and dark (the
/// app's themeMode drives brightness). Not part of any user flow — reachable
/// only via the dev route `/dev/gallery`.
class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});

  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  String _segment = 'quick';
  int _qty = 1;
  double _progress = 0.4;

  static const _members = [
    AvatarStackMember(name: 'You', colorKey: 'you@deun.app', isYou: true),
    AvatarStackMember(name: 'Sam Lee', colorKey: 'sam@deun.app'),
    AvatarStackMember(name: 'Priya Nair', colorKey: 'priya@deun.app'),
    AvatarStackMember(name: 'Jonas Berg', colorKey: 'jonas@deun.app'),
    AvatarStackMember(name: 'Lena Vogt', colorKey: 'lena@deun.app'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget gallery (dev)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _section('MemberAvatar', const [
            Row(
              children: [
                MemberAvatar(name: 'You', colorKey: 'you@deun.app', isYou: true),
                SizedBox(width: 12),
                MemberAvatar(name: 'Sam Lee', colorKey: 'sam@deun.app'),
                SizedBox(width: 12),
                MemberAvatar(name: 'Priya Nair', colorKey: 'priya@deun.app', radius: 24),
                SizedBox(width: 12),
                MemberAvatar(name: 'Guest', colorKey: 'guest', ringWidth: 2),
              ],
            ),
          ]),
          _section('AvatarStack', const [
            AvatarStack(members: _members, maxVisible: 3),
            SizedBox(height: 12),
            AvatarStack(members: _members, maxVisible: 5, radius: 18),
          ]),
          _section('MoneyText', const [
            MoneyText(124.5, semantic: MoneySemantic.auto),
            MoneyText(-42.0, semantic: MoneySemantic.auto),
            MoneyText(0, semantic: MoneySemantic.auto),
            MoneyText(8.25, semantic: MoneySemantic.positive, showSign: true),
          ]),
          _section('BalancePill', const [
            BalancePill(label: 'You are owed', state: BalanceState.owed, amount: 32.5),
            SizedBox(height: 8),
            BalancePill(label: 'You owe', state: BalanceState.owe, amount: -12.0),
            SizedBox(height: 8),
            BalancePill(label: 'Settled', state: BalanceState.settled),
          ]),
          _section('AppSegmentedControl', [
            AppSegmentedControl<String>(
              value: _segment,
              segments: const [
                AppSegment(value: 'quick', label: 'Quick split', icon: Icons.flash_on),
                AppSegment(value: 'itemized', label: 'Itemized', icon: Icons.list_alt),
              ],
              onChanged: (v) => setState(() => _segment = v),
            ),
          ]),
          _section('SectionLabel', [
            SectionLabel(
              'Your groups',
              trailing: TextButton(onPressed: () {}, child: const Text('New')),
            ),
          ]),
          _section('SoftCard', const [
            SoftCard(child: Text('A soft card — the base list-card container.')),
          ]),
          _section('StepperControl', [
            StepperControl(
              value: '$_qty',
              canDecrement: _qty > 0,
              onIncrement: () => setState(() => _qty++),
              onDecrement: () => setState(() => _qty--),
            ),
          ]),
          _section('ProgressBar', [
            ProgressBar(value: _progress),
            const SizedBox(height: 12),
            Slider(
              value: _progress,
              onChanged: (v) => setState(() => _progress = v),
            ),
          ]),
          _section('SheetScaffold', [
            FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                sheetAnimationStyle: kSheetAnimationStyle,
                backgroundColor: Colors.transparent,
                builder: (_) => SheetScaffold(
                  title: 'Pick a category',
                  body: Column(
                    children: List.generate(
                      6,
                      (i) => ListTile(
                        leading: const Icon(Icons.category),
                        title: Text('Category ${i + 1}'),
                      ),
                    ),
                  ),
                  footer: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
