import 'dart:io';
import '../models/models.dart';
import 'text_recognition_service.dart';

class OCRService {
  final _service = TextRecognitionService();

  // Main entry point — returns ReceiptItems
  // ready for ReviewItemsScreen
  Future<List<ReceiptItem>> scanReceipt(
      File imageFile) async {
    try {
      final receipt =
          await _service.scanAndParse(imageFile);

      final items = <ReceiptItem>[];
      int idx = 0;

      for (final parsed in receipt.items) {
        // Only include items with reasonable
        // confidence — user can fix the rest
        if (parsed.confidence < 0.5) continue;

        items.add(ReceiptItem(
          id: '${DateTime.now().millisecondsSinceEpoch}'
              '$idx',
          name: parsed.name,
          price: parsed.price,
        ));
        idx++;
      }

      return items;
    } catch (e) {
      // Return empty list on failure —
      // user adds items manually
      return [];
    }
  }

  String? detectStoreName(File imageFile) {
    // Synchronous store detection not available
    // Use scanAndParse for full results
    return null;
  }

  void dispose() {
    _service.dispose();
  }
}
