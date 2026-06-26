import 'package:deun/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../helper/helper.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../../widgets/restyle/primary_button.dart';
import '../../../widgets/restyle/sheet_scaffold.dart';
import '../data/group_model.dart';

/// Restyled group-invite sheet (E1-T4, F61). Surfaces the join LINK first — a
/// read-only link field + Copy action under the subtitle "Anyone with this link
/// can join the group." — with the QR code tucked behind a secondary toggle,
/// inside the shared [SheetScaffold]. Link/QR/Share behavior is unchanged from
/// the original screen — only the surfacing order is reorganized.
class GroupInvitePage extends StatefulWidget {
  const GroupInvitePage({super.key, required this.group});

  final Group group;

  /// Builds the deep link a friend opens / scans to join [group].
  ///
  /// Uses a hash fragment for in-app routing, mirroring the friend QR link.
  static Uri buildGroupInviteLink(Group group) {
    return Uri.parse(
        '$kWebAppBaseUrl/#/group/join?groupId=${Uri.encodeComponent(group.id)}&name=${Uri.encodeComponent(group.name)}');
  }

  @override
  State<GroupInvitePage> createState() => _GroupInvitePageState();
}

class _GroupInvitePageState extends State<GroupInvitePage> {
  bool _showQr = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final link = GroupInvitePage.buildGroupInviteLink(widget.group);
    final linkText = link.toString();

    return SheetScaffold(
      title: l10n.groupInviteTitleNamed(widget.group.name),
      titleTrailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
      // Footer action row (F62): a secondary "QR" button that toggles the same
      // QR reveal as the in-body "Show QR code" control + an indigo "Share link"
      // primary. flex 1:2 mirrors the v3 prototype's narrower QR / wider Share.
      footer: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              onPressed: () => setState(() => _showQr = !_showQr),
              icon: Icons.qr_code_2,
              label: l10n.inviteQrButton,
              fullWidth: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              onPressed: () async {
                await SharePlus.instance
                    .share(ShareParams(text: l10n.friendQrShareLink(linkText)));
              },
              icon: Icons.ios_share,
              label: l10n.inviteShareLink,
              fullWidth: false,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtitle: link is the primary surface; anyone with it can join.
          Text(
            l10n.groupInviteSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SectionLabel(l10n.groupInviteLinkLabel),
          const SizedBox(height: 8),
          // Copyable inset link field — surfaced first.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    linkText,
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: linkText));
                    if (context.mounted) {
                      showSnackBar(context, l10n.groupInviteLinkCopied);
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.copyLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // QR is secondary: collapsed behind a toggle, revealed on demand.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showQr = !_showQr),
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: Text(_showQr ? l10n.groupInviteHideQr : l10n.groupInviteShowQr),
            ),
          ),
          if (_showQr) ...[
            const SizedBox(height: 8),
            // QR code centered on a white rounded card. Kept dark-on-white even
            // in dark mode for scannability (per DESIGN_SPEC).
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: linkText,
                  version: QrVersions.auto,
                  size: 240.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.groupInviteLetFriendScan,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
