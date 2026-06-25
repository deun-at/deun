import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    WebViewController controller = WebViewController()..loadRequest(Uri.parse('https://deun.app/privacy_policy'));

    return Scaffold(
      body: Column(
        children: [
          DeunHeader(title: AppLocalizations.of(context)!.settingsPrivacyPolicy),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: WebViewWidget(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}
