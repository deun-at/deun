import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    WebViewController controller = WebViewController()..loadRequest(Uri.parse('https://deun.app/privacy_policy'));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsPrivacyPolicy),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: 30),
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
