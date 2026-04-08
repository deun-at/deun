import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class FriendQrPage extends StatefulWidget {
  const FriendQrPage({super.key});

  @override
  State<FriendQrPage> createState() => _FriendQrPageState();
}

class _FriendQrPageState extends State<FriendQrPage> {
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
    _buildUsernameLink();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Uri _buildFriendLink() {
    // Use username+code instead of email for privacy
    final currentUser = supabase.auth.currentUser;
    // Try to build username-based link first (set after onboarding)
    // We need to fetch user data since auth metadata doesn't have username
    return _cachedLink ?? Uri.parse('https://deun.app/#/friend/accept?email=${currentUser?.email ?? ''}');
  }

  Uri? _cachedLink;

  Future<void> _buildUsernameLink() async {
    try {
      final email = supabase.auth.currentUser?.email ?? '';
      final user = await UserRepository.fetchDetail(email);
      if (user.username != null && user.usernameCode != null && mounted) {
        setState(() {
          _cachedLink = Uri.parse(
            'https://deun.app/#/friend/accept?u=${Uri.encodeComponent(user.username!)}&c=${Uri.encodeComponent(user.usernameCode!)}',
          );
        });
      }
    } catch (_) {
      // Fallback to email-based link (already set as default)
    }
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
    _cameraController.stop();
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
    final link = _buildFriendLink();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.friendQrTitle,
            style: GoogleFonts.robotoSerif(
                textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(AppLocalizations.of(context)!.friendQrTabScan)),
                ButtonSegment(value: 1, label: Text(AppLocalizations.of(context)!.friendQrTabMyCode)),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tabIndex == 0 ? _buildScanner() : _buildMyCode(context, link),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _handleBarcode,
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 24,
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => _cameraController.toggleTorch(),
                icon: const Icon(Icons.flash_on),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _cameraController.switchCamera(),
                icon: const Icon(Icons.cameraswitch),
              ),
              const Spacer(),
              // Open system camera app as alternative
              IconButton.filled(
                onPressed: () async {
                  final url = _buildFriendLink().toString();
                  // Opening system camera is not directly possible; instruct via copying the link
                  await Clipboard.setData(ClipboardData(text: url));
                  if (mounted) {
                    showSnackBar(
                        context, AppLocalizations.of(context)!.friendQrLinkCopiedInstruction);
                  }
                },
                icon: const Icon(Icons.link),
                tooltip: AppLocalizations.of(context)!.copyLink,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyCode(BuildContext context, Uri link) {
    return SingleChildScrollView(
        child: Center(
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
            AppLocalizations.of(context)!.friendQrLetFriendScan,
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
                  SharePlus.instance.share(ShareParams(text: AppLocalizations.of(context)!.friendQrShareLink(url)));
                },
                icon: const Icon(Icons.ios_share),
                label: Text(AppLocalizations.of(context)!.share),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}
