import 'package:deun/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../helper/helper.dart';
import '../../../widgets/restyle/section_label.dart';
import '../../../widgets/restyle/sheet_scaffold.dart';
import '../data/group_model.dart';

/// Restyled group-invite sheet (E1-T4). Presents the group join link as a QR
/// code on a white card plus a copyable link field and Share action, inside the
/// shared [SheetScaffold]. Link/QR/Share behavior is unchanged from the
/// original screen — only the chrome is restyled.
class GroupInvitePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final link = buildGroupInviteLink(group);
    final linkText = link.toString();

    return SheetScaffold(
      title: l10n.groupInviteTitleNamed(group.name),
      titleTrailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
      footer: FilledButton.icon(
        onPressed: () async {
          await SharePlus.instance
              .share(ShareParams(text: l10n.friendQrShareLink(linkText)));
        },
        icon: const Icon(Icons.ios_share),
        label: Text(l10n.share),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),
          Text(
            l10n.groupInviteLetFriendScan,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SectionLabel(l10n.groupInviteLinkLabel),
          const SizedBox(height: 8),
          // Copyable inset link field.
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
        ],
      ),
    );
  }
}
