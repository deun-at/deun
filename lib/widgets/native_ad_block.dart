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
          minWidth: 350,
          maxWidth: 350,
          minHeight: 100,
          maxHeight: 100,
        ),
        child: (_nativeAdIsLoaded && _nativeAd != null) ? AdWidget(ad: _nativeAd!) : SizedBox(),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create the ad objects and load ads.
    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('$NativeAd loaded.');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('$NativeAd failedToLoad: $error');
          ad.dispose();
        },
        onAdOpened: (Ad ad) => debugPrint('$NativeAd onAdOpened.'),
        onAdClosed: (Ad ad) => debugPrint('$NativeAd onAdClosed.'),
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.white12,
        callToActionTextStyle: NativeTemplateTextStyle(
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black38,
          backgroundColor: Colors.white70,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    super.dispose();
    _nativeAd?.dispose();
  }
}
