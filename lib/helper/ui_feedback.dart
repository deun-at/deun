import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  SnackBar snackBar = SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 2),
  );

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(snackBar);
}

void showMaterialBanner(
  BuildContext context,
  String message,
  Function onPressed,
) {
  final messenger = ScaffoldMessenger.of(context);

  final banner = MaterialBanner(
    content: Text(message),
    actions: <Widget>[
      TextButton(
        onPressed: () {
          onPressed();
          messenger.hideCurrentMaterialBanner();
        },
        child: Text(AppLocalizations.of(context)!.open),
      ),
      TextButton(
        onPressed: () {
          messenger.hideCurrentMaterialBanner();
        },
        child: Text(AppLocalizations.of(context)!.close),
      ),
    ],
  );

  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(banner);
}

void refreshSuggestions(SearchController searchController) {
  const String _zeroWidthSpace = '\u200B';
  final previousText = searchController.text;
  searchController.text =
      '$_zeroWidthSpace$previousText'; // This will trigger updateSuggestions and call `suggestionsBuilder`.
  searchController.text = previousText;
}
