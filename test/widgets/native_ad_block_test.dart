import 'package:deun/widgets/native_ad_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for design-audit findings F01, F02 and F33.
///
/// F01: a failed/unloaded AdMob native ad must mount NO platform-view, occupy
/// zero hit-test area, and never intercept taps meant for the sibling group
/// cards.
///
/// F02: in any non-loaded state (loading / failed / disposed) NO ad container
/// or banner may be visible — in particular the google_mobile_ads SDK's own red
/// "This ad may have not been loaded or has been disposed…" debug block must
/// never paint. That block is rendered by the platform-view that an [AdWidget]
/// mounts, so the invariant is simply: NO [AdWidget] exists in the tree unless
/// the ad genuinely reported "loaded".
///
/// F33: on a real device the SDK paints that same red debug block ("Ad with the
/// following id could not be found: 0") because debug/test builds have EMPTY ad
/// unit IDs, so the SDK never gets fill and shows its debug platform-view.
/// [NativeAdBlock] therefore must not even REQUEST an ad in debug builds
/// (`!kDebugMode`). The lifecycle tests below opt back into requesting via the
/// `requestInDebug: true` test seam so the loaded/failed/disposed paths can
/// still be exercised; the dedicated F33 test asserts the default (debug) build
/// dispatches no request at all.
const _channelName = 'plugins.flutter.io/google_mobile_ads';

/// Recovers the plain-int `adId` from a `loadNativeAd` method-call envelope
/// without depending on the plugin's private (non-exported) `AdMessageCodec`.
///
/// The envelope is `[method-name string][arguments map]`. The arguments map's
/// first entry is `'adId': <int>` (insertion order is preserved), written by
/// the inherited [StandardMessageCodec] before any custom plugin type. We parse
/// the map header and the first key/value with standard primitives and stop —
/// never touching the trailing custom-typed entries (AdRequest, template style)
/// that a full standard decode would choke on.
int? _adIdFromLoadNativeAd(ByteData message) {
  const codec = StandardMessageCodec();
  final buffer = ReadBuffer(message);
  final method = codec.readValue(buffer); // method name
  if (method != 'loadNativeAd') return null;

  final int typeByte = buffer.getUint8();
  if (typeByte != 13) return null; // 13 == map
  codec.readSize(buffer); // entry count (ignored — we read only the first)

  final key = codec.readValue(buffer);
  final value = codec.readValue(buffer);
  if (key == 'adId' && value is int) return value;
  return null;
}

/// Encodes an inbound `onAdEvent` / `onAdFailedToLoad` platform message exactly
/// as the native ads plugin would, including a genuine (non-null) `LoadAdError`.
///
/// The plugin's `AdMessageCodec` serializes a `LoadAdError` as the custom type
/// tag 133 followed by its `code` (int), `domain` (String), `message` (String)
/// and `responseInfo` (here null) — all standard-encoded. Everything else in
/// the envelope is standard, so we build it with [StandardMessageCodec]
/// primitives plus that one hand-written custom block. Delivering this drives
/// the widget's real `onAdFailedToLoad` callback (not a no-op), which is what
/// makes the failed→disposed teardown assertion meaningful.
ByteData _encodeFailedToLoadEvent({required int adId}) {
  const codec = StandardMessageCodec();
  const int valueLoadAdError = 133; // AdMessageCodec._valueLoadAdError
  final buffer = WriteBuffer();

  codec.writeValue(buffer, 'onAdEvent'); // method name

  // arguments map: { adId, eventName, loadAdError }
  buffer.putUint8(13); // map type
  codec.writeSize(buffer, 3);

  codec.writeValue(buffer, 'adId');
  codec.writeValue(buffer, adId);

  codec.writeValue(buffer, 'eventName');
  codec.writeValue(buffer, 'onAdFailedToLoad');

  codec.writeValue(buffer, 'loadAdError');
  buffer.putUint8(valueLoadAdError); // custom LoadAdError
  codec.writeValue(buffer, 1); // code
  codec.writeValue(buffer, 'test-domain'); // domain
  codec.writeValue(buffer, 'no fill (test)'); // message
  codec.writeValue(buffer, null); // responseInfo

  return buffer.done();
}

/// Encodes an inbound `onAdEvent` with eventName `onAdLoaded` for [adId],
/// driving the widget's real `onAdLoaded` callback so an [AdWidget] mounts.
ByteData _encodeLoadedEvent({required int adId}) {
  const codec = StandardMessageCodec();
  final buffer = WriteBuffer();

  codec.writeValue(buffer, 'onAdEvent'); // method name

  // arguments map: { adId, eventName }
  buffer.putUint8(13); // map type
  codec.writeSize(buffer, 2);

  codec.writeValue(buffer, 'adId');
  codec.writeValue(buffer, adId);

  codec.writeValue(buffer, 'eventName');
  codec.writeValue(buffer, 'onAdLoaded');

  return buffer.done();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Installs a mock handler for the outgoing ads channel that swallows every
  /// call with a "success: null" reply, and (when [onLoadNativeAd] is provided)
  /// reports the `adId` of each `loadNativeAd` invocation so the test can later
  /// drive a real failure event for that exact ad.
  void mockAdsChannel({void Function(int adId)? onLoadNativeAd}) {
    final okReply = const StandardMethodCodec().encodeSuccessEnvelope(null);
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMessageHandler(_channelName, (ByteData? message) async {
      if (onLoadNativeAd != null && message != null) {
        final adId = _adIdFromLoadNativeAd(message);
        if (adId != null) onLoadNativeAd(adId);
      }
      return okReply;
    });
  }

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMessageHandler(_channelName, null);
  });

  testWidgets(
      'F01: unloaded ad is zero-size and does not block taps on the sibling beneath it',
      (tester) async {
    mockAdsChannel();
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
                child: NativeAdBlock(
                    adUnitId: 'test-ad-unit', requestInDebug: true),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // No AdWidget / platform-view exists while the ad is unloaded, so the SDK
    // debug block cannot paint (F02 invariant, pending state).
    expect(find.byType(AdWidget), findsNothing,
        reason: 'no AdWidget may be mounted while the ad has not loaded');

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

  testWidgets(
      'F02: a failed-then-disposed ad mounts no AdWidget and paints nothing',
      (tester) async {
    int? capturedAdId;
    mockAdsChannel(onLoadNativeAd: (adId) => capturedAdId = adId);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: NativeAdBlock(
                adUnitId: 'test-ad-unit', requestInDebug: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedAdId, isNotNull,
        reason: 'NativeAdBlock should have dispatched a loadNativeAd request');
    // Sanity: nothing is mounted before the load resolves either.
    expect(find.byType(AdWidget), findsNothing);

    // Drive the REAL plugin failure path: deliver an inbound `onAdEvent` with
    // eventName 'onAdFailedToLoad' and a genuine (non-null) LoadAdError for the
    // captured adId. The plugin's instanceManager routes this to
    // NativeAdListener.onAdFailedToLoad, which disposes the ad and rebuilds
    // NativeAdBlock to its collapsed state.
    final failureEvent = _encodeFailedToLoadEvent(adId: capturedAdId!);
    await TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .handlePlatformMessage(_channelName, failureEvent, (_) {});
    await tester.pump();

    // After a genuine failure: still no AdWidget/platform-view anywhere, so the
    // SDK's red debug block can never paint, and the block reserves no space.
    expect(find.byType(AdWidget), findsNothing,
        reason: 'a failed/disposed ad must tear down its AdWidget entirely');
    final size = tester.getSize(find.byType(NativeAdBlock));
    expect(size, Size.zero,
        reason: 'a failed/disposed ad must occupy zero layout + hit-test area');

    // The failure path schedules a 30s retry (Future.delayed). Let it fire so
    // the test leaves no pending timer; the retried load is still unloaded, so
    // the invariant continues to hold afterwards.
    await tester.pump(const Duration(seconds: 31));
    expect(find.byType(AdWidget), findsNothing,
        reason: 'the retried (still-unloaded) ad must also mount no AdWidget');
  });

  testWidgets(
      'F33: in a debug build NO ad is requested and NO AdWidget ever mounts',
      (tester) async {
    int? capturedAdId;
    mockAdsChannel(onLoadNativeAd: (adId) => capturedAdId = adId);

    // Default constructor => requestInDebug is null => falls back to !kDebugMode.
    // Tests run in debug, so this is exactly the build the design audit sees.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: NativeAdBlock(adUnitId: 'test-ad-unit'),
          ),
        ),
      ),
    );
    await tester.pump();

    // The SDK is never even asked to load: no empty-unit-id "could not be
    // found: 0" debug platform-view can appear because no ad is requested.
    expect(capturedAdId, isNull,
        reason: 'a debug build must NOT dispatch a loadNativeAd request');
    expect(find.byType(AdWidget), findsNothing,
        reason: 'no AdWidget may mount in a debug build');
    expect(tester.getSize(find.byType(NativeAdBlock)), Size.zero,
        reason: 'the debug-gated ad block must occupy zero layout area');
  });

  testWidgets(
      'F33 race: an ad that loads then is disposed leaves no live AdWidget',
      (tester) async {
    int? capturedAdId;
    mockAdsChannel(onLoadNativeAd: (adId) => capturedAdId = adId);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: NativeAdBlock(
                adUnitId: 'test-ad-unit', requestInDebug: true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(capturedAdId, isNotNull);

    // 1) Drive a genuine load: onAdLoaded mounts a real AdWidget/platform-view.
    await TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .handlePlatformMessage(
            _channelName, _encodeLoadedEvent(adId: capturedAdId!), (_) {});
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget,
        reason: 'a genuinely-loaded ad mounts exactly one AdWidget');

    // 2) Now the underlying ad/platform-view goes away (dispose/rebuild race on
    // device). Simulate the SDK then reporting the SAME adId as failed — the
    // disposed path. The widget must tear the AdWidget down so no AdWidget can
    // reference a disposed ad (which is what paints "could not be found: 0").
    await TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .handlePlatformMessage(
            _channelName, _encodeFailedToLoadEvent(adId: capturedAdId!), (_) {});
    await tester.pump();

    expect(find.byType(AdWidget), findsNothing,
        reason: 'a disposed ad must leave no live AdWidget in the tree');
    expect(tester.getSize(find.byType(NativeAdBlock)), Size.zero,
        reason: 'after teardown the block collapses to zero size');

    // Flush the 30s retry so no timer leaks; still no AdWidget afterwards.
    await tester.pump(const Duration(seconds: 31));
    expect(find.byType(AdWidget), findsNothing);
  });
}
