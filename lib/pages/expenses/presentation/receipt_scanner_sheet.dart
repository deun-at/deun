import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../service/receipt_parser.dart';

class ReceiptScannerSheet extends StatefulWidget {
  const ReceiptScannerSheet({super.key});

  @override
  State<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends State<ReceiptScannerSheet> {
  bool _isProcessing = false;
  bool _hasError = false;

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
      _isProcessing = true;
      _hasError = false;
    });

    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final result = ReceiptParser.parse(recognizedText.blocks);
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasError = true;
        });
      }
    } finally {
      textRecognizer.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.receiptScanTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.receiptScanProcessing),
              const SizedBox(height: 16),
            ] else if (_hasError) ...[
              Text(
                l10n.receiptScanError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _hasError = false),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.receiptScanTitle),
              ),
              const SizedBox(height: 8),
            ] else ...[
              FilledButton.tonalIcon(
                onPressed: () => _processImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.receiptScanTakePhoto),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _processImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.receiptScanChooseGallery),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
