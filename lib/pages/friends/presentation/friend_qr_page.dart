import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../widgets/restyle/app_segmented_control.dart';
import '../../../widgets/restyle/member_avatar.dart';
import '../../../widgets/restyle/soft_card.dart';

/// Restyled friend-QR page (E5-T3). Presents the user's add-friend QR on a white
/// card with a profile row plus Copy/Share, and a camera viewfinder for scanning
/// a friend's code, behind a segmented My-code / Scan switch.
///
/// QR payload, scan/add-friend handling and the `/friend/qr` route are unchanged
/// from the original screen — only the chrome is restyled.
class FriendQrPage extends ConsumerStatefulWidget {
  const FriendQrPage({super.key});

  /// Builds the add-friend deep link a friend opens / scans.
  ///
  /// Always username+code based — never email, which would leak the address
  /// through QR codes, share sheets and clipboard history. Returns null when the
  /// user has no username yet.
  static Uri? buildFriendQrLink(SupaUser user) {
    if (user.username == null || user.usernameCode == null) return null;
    return Uri.parse(
      '$kWebAppBaseUrl/#/friend/accept?u=${Uri.encodeComponent(user.username!)}&c=${Uri.encodeComponent(user.usernameCode!)}',
    );
  }

  @override
  ConsumerState<FriendQrPage> createState() => _FriendQrPageState();
}

class _FriendQrPageState extends ConsumerState<FriendQrPage> {
  int _tabIndex = 1; // default to My Code
  late final MobileScannerController _cameraController;
  bool _handlingScan = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _restartScanner() {
    if (mounted) {
      _cameraController.start();
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_handlingScan) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handlingScan = true;
    unawaited(_cameraController.stop());
    try {
      // Try to interpret as URI
      Uri? uri;
      try {
        uri = Uri.parse(raw);
      } catch (_) {}

      if (uri != null) {
        final fragment = uri.fragment;
        if (fragment.isNotEmpty && mounted) {
          await GoRouter.of(context).push(fragment);
          _restartScanner();
          return;
        }

        // Also support direct route without fragment
        if (mounted && (uri.path == '/friend/accept' || uri.pathSegments.contains('friend'))) {
          final qp = uri.queryParameters;
          if (qp.containsKey('email')) {
            await GoRouter.of(context).push('/friend/accept?email=${Uri.encodeComponent(qp['email']!)}');
            _restartScanner();
            return;
          }
        }
      }

      // Fallback: if it's just an email in the QR
      if (raw.contains('@') && mounted) {
        await GoRouter.of(context).push('/friend/accept?email=${Uri.encodeComponent(raw)}');
        _restartScanner();
        return;
      }

      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.friendQrNotRecognized);
        _restartScanner();
      }
    } finally {
      _handlingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(userDetailProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.friendQrTitle,
          style: GoogleFonts.robotoSerif(
            textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: AppSegmentedControl<int>(
              value: _tabIndex,
              onChanged: (v) => setState(() => _tabIndex = v),
              segments: [
                AppSegment(value: 0, label: l10n.friendQrTabScan, icon: Icons.qr_code_scanner),
                AppSegment(value: 1, label: l10n.friendQrTabMyCode, icon: Icons.qr_code_2),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tabIndex == 0
                  ? _ScanView(
                      key: const ValueKey('scan'),
                      controller: _cameraController,
                      onDetect: _handleBarcode,
                      shareLink: () {
                        final u = userAsync.value;
                        return u == null ? null : FriendQrPage.buildFriendQrLink(u);
                      },
                    )
                  : _MyCodeView(
                      key: const ValueKey('mine'),
                      userAsync: userAsync,
                      onRetry: () => ref.invalidate(userDetailProvider),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "My code" tab: QR on a white card + profile row + Copy/Share.
class _MyCodeView extends StatelessWidget {
  const _MyCodeView({super.key, required this.userAsync, required this.onRetry});

  final AsyncValue<SupaUser> userAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _ErrorState(onRetry: onRetry),
      data: (user) {
        final link = FriendQrPage.buildFriendQrLink(user);
        if (link == null) {
          return _ErrorState(onRetry: onRetry);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR centered on a white rounded card. Kept dark-on-white even in
              // dark mode for scannability (per DESIGN_SPEC).
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: link.toString(),
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
              const SizedBox(height: 18),
              _ProfileRow(user: user),
              const SizedBox(height: 14),
              Text(
                l10n.friendQrLetFriendScan,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link.toString()));
                        if (context.mounted) {
                          showSnackBar(context, l10n.friendQrLinkCopied);
                        }
                      },
                      icon: const Icon(Icons.copy, size: 19),
                      label: Text(l10n.copyLink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await SharePlus.instance
                            .share(ShareParams(text: l10n.friendQrShareLink(link.toString())));
                      },
                      icon: const Icon(Icons.ios_share, size: 19),
                      label: Text(l10n.share),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Avatar + display name + @username#code.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.user});

  final SupaUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final name = user.displayName.isNotEmpty ? user.displayName : (user.username ?? '');
    final handle = (user.username != null && user.usernameCode != null)
        ? '@${user.username}#${user.usernameCode}'
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemberAvatar(name: name, colorKey: user.email, isYou: true, radius: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (handle != null)
              Text(
                handle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The "Scan" tab: the camera viewfinder with restyled corner-bracket framing.
class _ScanView extends StatelessWidget {
  const _ScanView({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.shareLink,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final Uri? Function() shareLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // Dark viewfinder surface in both themes (camera feed sits on dark chrome).
    const frameColor = Color(0xFF16181A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: frameColor,
              child: MobileScanner(
                controller: controller,
                onDetect: onDetect,
              ),
            ),
            // Corner brackets overlay (accent-colored).
            IgnorePointer(
              child: CustomPaint(
                painter: _ViewfinderPainter(color: colorScheme.primary),
              ),
            ),
            // Prompt centered over the viewfinder.
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 34, color: Colors.white70),
                    const SizedBox(height: 8),
                    Text(
                      l10n.friendQrScanPrompt,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Controls row.
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Row(
                children: [
                  _ScanCircleButton(
                    icon: Icons.flash_on,
                    tooltip: l10n.friendQrTorchToggle,
                    onTap: () => controller.toggleTorch(),
                  ),
                  const SizedBox(width: 8),
                  _ScanCircleButton(
                    icon: Icons.cameraswitch,
                    tooltip: l10n.friendQrSwitchCamera,
                    onTap: () => controller.switchCamera(),
                  ),
                  const Spacer(),
                  _ScanCircleButton(
                    icon: Icons.link,
                    filled: true,
                    tooltip: l10n.copyLink,
                    onTap: () async {
                      final url = shareLink()?.toString();
                      if (url == null) {
                        showSnackBar(context, l10n.generalError);
                        return;
                      }
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        showSnackBar(context, l10n.friendQrLinkCopiedInstruction);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round translucent (or filled-accent) control button over the viewfinder.
class _ScanCircleButton extends StatelessWidget {
  const _ScanCircleButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // The visible circle stays 42px, but the whole 48dp box is tappable (a11y
    // minimum hit area): the InkResponse fills 48x48 with the 42px circle
    // centered inside it.
    final target = Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        containedInkWell: false,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: filled ? colorScheme.primary : Colors.white24,
                shape: const CircleBorder(),
              ),
              child: Icon(icon, size: 21, color: filled ? colorScheme.onPrimary : Colors.white),
            ),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: target) : target;
  }
}

/// Paints four rounded corner brackets framing the viewfinder.
class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 24.0;
    const len = 34.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const left = inset;
    const top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    // Top-left
    canvas.drawLine(const Offset(left, top), const Offset(left + len, top), paint);
    canvas.drawLine(const Offset(left, top), const Offset(left, top + len), paint);
    // Top-right
    canvas.drawLine(Offset(right, top), Offset(right - len, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom), Offset(left + len, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(right, bottom), Offset(right - len, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - len), paint);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) => oldDelegate.color != color;
}

/// Error / no-username state with a retry action.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.generalError,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
