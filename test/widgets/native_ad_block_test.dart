import 'package:deun/widgets/native_ad_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for design-audit finding F01:
/// A failed/unloaded AdMob native ad must mount NO platform-view, occupy zero
/// hit-test area, and never intercept taps meant for the sibling group cards.
///
/// We stub the google_mobile_ads method channel so `.load()` does not throw and
/// no ad-loaded event is ever delivered — i.e. the ad stays in its unloaded
/// (pending / failed) state, which is exactly the state that previously
/// reserved a full-width >=50px interactive band over the list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'plugins.flutter.io/google_mobile_ads';

  setUp(() {
    // The ads plugin uses a custom message codec (AdMessageCodec), so we mock
    // at the raw-binary level and swallow every call, replying with a valid
    // "success: null" envelope (the standard codec encodes null identically to
    // AdMessageCodec). No onAdEvent is ever delivered, so the ad never reports
    // "loaded" — exactly the unloaded/failed state under test.
    final okReply = const StandardMethodCodec().encodeSuccessEnvelope(null);
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMessageHandler(channelName, (ByteData? message) async => okReply);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMessageHandler(channelName, null);
  });

  testWidgets('unloaded ad is zero-size and does not block taps on the sibling beneath it',
      (tester) async {
    var tappedBelow = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // A full-screen sibling "group card" sitting underneath the ad
              // slot. If the unloaded ad widget reserves a hit-test band, the
              // tap at its location would be swallowed and this stays false.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tappedBelow = true,
                  child: const SizedBox.expand(),
                ),
              ),
              // The ad block, pinned to the top where we will tap.
              const Align(
                alignment: Alignment.topCenter,
                child: NativeAdBlock(adUnitId: 'test-ad-unit'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // The unloaded ad collapses to a zero-size box.
    final size = tester.getSize(find.byType(NativeAdBlock));
    expect(size, Size.zero,
        reason: 'an unloaded/failed native ad must occupy zero layout + hit-test area');

    // A tap near the very top (where the ad slot lives) reaches the sibling
    // card underneath — the ad does not intercept it.
    await tester.tapAt(const Offset(200, 4));
    await tester.pump();
    expect(tappedBelow, isTrue,
        reason: 'sibling group card under the ad slot must remain tappable');
  });
}
