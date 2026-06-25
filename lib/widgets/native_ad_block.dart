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
    // Until the ad has actually loaded (and while it is failed/disposed) mount
    // NOTHING: a zero-size widget that reserves no layout band and, crucially,
    // no hit-test area. Building the Align/ConstrainedBox chrome unconditionally
    // would reserve a full-width >=50px band over the group list; combined with
    // the platform-view that the AdWidget mounts, a failed ad would paint the
    // SDK debug error block AND swallow taps meant for the sibling group cards.
    // The AdWidget (and thus the platform-view) is only built once load succeeds.
    if (!_nativeAdIsLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Clip + bound the AdWidget so the opaque platform-view's render (and
    // therefore hit-test) box is exactly this ad slot and can never extend over
    // sibling widgets.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ClipRect(
        child: SizedBox(
          width: double.infinity,
          height: 100,
          child: AdWidget(ad: _nativeAd!),
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
      request: const AdRequest(),
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
          if (mounted) {
            // Rebuild so any previously-mounted AdWidget/platform-view is torn
            // down and the widget collapses to a zero-size, non-hit-testing box.
            setState(() {
              _nativeAd = null;
              _nativeAdIsLoaded = false;
            });
            Future.delayed(const Duration(seconds: 30), () {
              if (mounted && _nativeAd == null) {
                _loadAd();
              }
            });
          } else {
            _nativeAd = null;
            _nativeAdIsLoaded = false;
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
