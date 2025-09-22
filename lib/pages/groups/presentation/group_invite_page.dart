import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../widgets/rounded_container.dart';
import '../data/group_model.dart';

class GroupInvitePage extends StatelessWidget {
  const GroupInvitePage({super.key, required this.group});

  final Group group;

  Uri _buildGroupInviteLink() {
    // Use hash fragment for in-app routing just like friends QR
    final uri = Uri.parse(
        'https://deun.app/#/group/join?groupId=${Uri.encodeComponent(group.id)}&name=${Uri.encodeComponent(group.name)}');
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final link = _buildGroupInviteLink();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      snap: true,
      builder: (context, scrollController) {
        return RoundedContainer(
          child: Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.groupInviteTitle,
                  style: GoogleFonts.robotoSerif(
                      textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: link.toString(),
                              version: QrVersions.auto,
                              size: 260.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.groupInviteLetFriendScan,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: link.toString()));
                                },
                                icon: const Icon(Icons.copy),
                                label: Text(AppLocalizations.of(context)!.copyLink),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  final url = link.toString();
                                  SharePlus.instance
                                      .share(ShareParams(text: AppLocalizations.of(context)!.friendQrShareLink(url)));
                                },
                                icon: const Icon(Icons.ios_share),
                                label: Text(AppLocalizations.of(context)!.share),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
