import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deun/l10n/app_localizations.dart';

import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';

import '../data/receipt_scan_result.dart';
import '../service/gemini_receipt_parser.dart';

/// Total to surface in the detected-items preview: the parser's [total] when it
/// reported one, otherwise the sum of the detected line-item amounts. Pure so it
/// can be unit-tested. Returns 0 for an empty result.
double receiptPreviewTotal(ReceiptScanResult result) {
  if (result.total != null) return result.total!;
  return result.lineItems.fold<double>(0, (sum, item) => sum + item.amount);
}

/// The discrete stages the scanner sheet moves through.
enum _ScanStage { idle, scanning, review, error }

class ReceiptScannerSheet extends StatefulWidget {
  const ReceiptScannerSheet({super.key});

  @override
  State<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends State<ReceiptScannerSheet> {
  _ScanStage _stage = _ScanStage.idle;
  ReceiptScanResult? _result;

  Future<void> _processImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() {
      _stage = _ScanStage.scanning;
      _result = null;
    });

    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Extract OCR lines for Gemini.
      final ocrLines = <String>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          ocrLines.add(line.text);
        }
      }

      final result = await GeminiReceiptParser.parse(ocrLines);
      if (result != null && !result.isEmpty && mounted) {
        // Hand control to the detected-items preview before returning.
        setState(() {
          _result = result;
          _stage = _ScanStage.review;
        });
      } else if (mounted) {
        setState(() => _stage = _ScanStage.error);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _stage = _ScanStage.error);
      }
    } finally {
      unawaited(textRecognizer.close());
    }
  }

  void _confirm() {
    final result = _result;
    if (result != null) Navigator.pop(context, result);
  }

  void _retake() => setState(() {
        _stage = _ScanStage.idle;
        _result = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // The detected-items preview owns its own confirm/retake footer, so it
    // renders the whole sheet body itself.
    if (_stage == _ScanStage.review && _result != null) {
      return ReceiptItemsPreview(
        result: _result!,
        onConfirm: _confirm,
        onRetake: _retake,
      );
    }

    return SheetScaffold(
      title: l10n.receiptScanTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_stage == _ScanStage.scanning) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(
              child: Text(
                l10n.receiptScanProcessing,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 24),
          ] else if (_stage == _ScanStage.error) ...[
            _ErrorBanner(message: l10n.receiptScanNoData),
            const SizedBox(height: 16),
            _CaptureActions(onPick: _processImage),
          ] else ...[
            Center(
              child: Text(
                l10n.receiptScanInstructions,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            _CaptureActions(onPick: _processImage),
          ],
        ],
      ),
    );
  }
}

/// The capture call-to-action pair (camera + gallery).
class _CaptureActions extends StatelessWidget {
  const _CaptureActions({required this.onPick});

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          key: const ValueKey('receipt_take_photo'),
          onPressed: () => onPick(ImageSource.camera),
          icon: Icons.camera_alt_outlined,
          label: l10n.receiptScanTakePhoto,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          key: const ValueKey('receipt_choose_gallery'),
          onPressed: () => onPick(ImageSource.gallery),
          icon: Icons.photo_library_outlined,
          label: l10n.receiptScanChooseGallery,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SoftCard(
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The detected-items preview: merchant header, a [SoftCard] list of parsed line
/// items (name + price via [MoneyText]) with a total row, and a sticky
/// confirm / retake footer. Confirming hands the unchanged [result] back to the
/// editor via [onConfirm]; [onRetake] returns to the capture state.
class ReceiptItemsPreview extends StatelessWidget {
  const ReceiptItemsPreview({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onRetake,
  });

  final ReceiptScanResult result;
  final VoidCallback onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = result.lineItems;
    final total = receiptPreviewTotal(result);

    return SheetScaffold(
      title: l10n.receiptScanReviewTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.merchantName != null &&
              result.merchantName!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.merchantName!,
                    style: textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SectionLabel(l10n.receiptScanItemCount(items.length)),
          const SizedBox(height: 8),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: colorScheme.outlineVariant),
                  _ItemRow(item: items[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.receiptScanTotalLabel,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              MoneyText(total, style: textTheme.titleLarge),
            ],
          ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              key: const ValueKey('receipt_retake'),
              onPressed: onRetake,
              icon: Icons.refresh,
              label: l10n.receiptScanRetake,
              fullWidth: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              key: const ValueKey('receipt_confirm'),
              onPressed: onConfirm,
              label: l10n.receiptScanUseItems,
              fullWidth: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ReceiptLineItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.quantity > 1)
                  Text(
                    '${item.quantity} × ',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MoneyText(item.amount, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}
