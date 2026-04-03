// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../services/text_recognition_service.dart';

class CameraScreen extends StatefulWidget {
  final List<Friend> selectedFriends;
  final String? groupId;

  const CameraScreen({
    super.key,
    required this.selectedFriends,
    this.groupId,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  bool _isScanning = false;
  String _scanStatus = '';
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer();

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final testFile = File('/sdcard/Download/receipt.jpg');

    if (await testFile.exists()) {
      if (!mounted) return;
      final bool? useTest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test Receipt Found!'),
          content: const Text('Use the local test receipt?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (useTest == true) {
        setState(() {
          _image = testFile;
          _isScanning = false;
          _scanStatus = '';
        });
        _scanReceipt();
        return;
      }
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _isScanning = false;
      _scanStatus = '';
    });
  }



  Future<void> _scanReceipt() async {
    if (_image == null) return;

    setState(() {
      _isScanning = true;
      _scanStatus = 'Reading receipt...';
    });

    try {
      final service = TextRecognitionService();

      setState(() => _scanStatus = 'Detecting text...');

      // Step 1: Extract all lines with coordinates
      final lines = await service.extractLines(_image!);

      setState(() => _scanStatus = 'Pairing items with prices...');

      // Step 2: Parse using coordinate-based logic
      final receipt = service.parseReceipt(lines);

      // Debug output in terminal
      debugPrint('=== OCR RESULT: ${lines.length} lines ===');
      for (final l in lines) {
        debugPrint('  [y:${l.centerY.toInt()}] ${l.text}');
      }
      debugPrint('=== PARSED: ${receipt.items.length} items ===');
      for (final item in receipt.items) {
        debugPrint(
            '  ${item.name} = \$${item.price} (conf: ${item.confidence.toStringAsFixed(2)})');
      }
      if (receipt.total != null) {
        debugPrint('  TOTAL: \$${receipt.total}');
      }
      debugPrint('=== END ===');

      service.dispose();

      if (!mounted) return;

      // Convert to ReceiptItem list
      final items = receipt.items
          .where((i) => i.confidence >= 0.5)
          .map((i) => ReceiptItem(
                id: '${DateTime.now().millisecondsSinceEpoch}'
                    '${receipt.items.indexOf(i)}',
                name: i.name,
                price: i.price,
              ))
          .toList();

      _goToReview(items);
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan failed. Try manual entry.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _goToReview(List<ReceiptItem> items) {
    setState(() {
      _isScanning = false;
      _scanStatus = '';
    });
    Navigator.pushNamed(
      context,
      AppRoutes.reviewItems,
      arguments: {
        'items': items,
        'friends': widget.selectedFriends,
        'groupId': widget.groupId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Scan Receipt', style: AppTextStyles.titleMedium),
      ),
      body: Column(
        children: [
          _StepIndicator(step: 2),
          Expanded(
            child: _isScanning
                ? _ScanningView(status: _scanStatus)
                : _image == null
                    ? _PickImageView(
                        onCamera: () => _pickImage(ImageSource.camera),
                        onGallery: () => _pickImage(ImageSource.gallery),
                        onManual: () => Navigator.pushNamed(
                          context,
                          AppRoutes.reviewItems,
                          arguments: {
                            'items': <ReceiptItem>[],
                            'friends': widget.selectedFriends,
                            'groupId': widget.groupId,
                          },
                        ),
                      )
                    : _ImagePreviewView(
                        image: _image!,
                        onRetake: () => setState(() => _image = null),
                        onScan: _scanReceipt,
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = ['People', 'Scan', 'Review', 'Assign', 'Done'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i + 1 == step;
          final isDone = i + 1 < step;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isDone || isActive
                        ? AppColors.accent
                        : AppColors.border,
                    borderRadius: AppRadius.pill,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isActive
                        ? AppColors.accent
                        : isDone
                            ? AppColors.textSecondary
                            : AppColors.textHint,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Pick Image View ──────────────────────────────────────────────────────────

class _PickImageView extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onManual;

  const _PickImageView({
    required this.onCamera,
    required this.onGallery,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.accent, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Scan your receipt', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Take a photo or upload from\nyour gallery.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: const Text('Take a photo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text('Upload from gallery'),
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onManual,
            child: Text(
              'Enter items manually instead',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image Preview View ───────────────────────────────────────────────────────

class _ImagePreviewView extends StatelessWidget {
  final File image;
  final VoidCallback onRetake;
  final VoidCallback onScan;

  const _ImagePreviewView({
    required this.image,
    required this.onRetake,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: AppRadius.lg,
              child: Image.file(
                image,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Scan items'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Scanning View ────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  final String status;
  const _ScanningView({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text(status, style: AppTextStyles.titleSmall),
          const SizedBox(height: 8),
          Text(
            'Reading your receipt...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
