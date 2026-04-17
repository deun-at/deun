import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdBlock extends StatefulWidget {
  const NativeAdBlock({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<NativeAdBlock> createState() => _NativeAdBlockState();
}

class _NativeAdBlockState extends State<NativeAdBlock> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          maxWidth: double.infinity,
          minHeight: 50,
          maxHeight: 100,
        ),
        child: Padding(
          padding: EdgeInsets.only(left: 5, right: 5),
          child: (_nativeAdIsLoaded && _nativeAd != null) ? AdWidget(ad: _nativeAd!) : SizedBox(),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nativeAd != null) return;
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('$NativeAd loaded.');
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('$NativeAd failedToLoad: $error');
          ad.dispose();
          _nativeAd = null;
          _nativeAdIsLoaded = false;
          if (mounted) {
            Future.delayed(const Duration(seconds: 30), () {
              if (mounted && _nativeAd == null) {
                _loadAd();
              }
            });
          }
        },
        onAdOpened: (Ad ad) => debugPrint('$NativeAd onAdOpened.'),
        onAdClosed: (Ad ad) => debugPrint('$NativeAd onAdClosed.'),
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        callToActionTextStyle: NativeTemplateTextStyle(
          backgroundColor: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onPrimary,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _nativeAd = null;
    super.dispose();
  }
}
