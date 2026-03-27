import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class RecognizedLine {
  final String text;
  final double top;
  final double bottom;
  final double left;
  final double right;
  final double centerY;

  const RecognizedLine({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  }) : centerY = (top + bottom) / 2;

  double get height => bottom - top;

  @override
  String toString() =>
      'RecognizedLine("$text" y:$centerY)';
}

class ParsedReceiptItem {
  final String name;
  final double price;
  final double confidence; // 0.0 - 1.0

  const ParsedReceiptItem({
    required this.name,
    required this.price,
    required this.confidence,
  });
}

class ParsedReceipt {
  final List<ParsedReceiptItem> items;
  final double? subtotal;
  final double? tax;
  final double? total;
  final String? storeName;

  const ParsedReceipt({
    required this.items,
    this.subtotal,
    this.tax,
    this.total,
    this.storeName,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class TextRecognitionService {
  final _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ── Step 1: Extract all lines with coordinates ──
  Future<List<RecognizedLine>> extractLines(
      File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized =
        await _recognizer.processImage(inputImage);

    final lines = <RecognizedLine>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final bbox = line.boundingBox;
        if (line.text.trim().isEmpty) continue;

        lines.add(RecognizedLine(
          text: line.text.trim(),
          top: bbox.top.toDouble(),
          bottom: bbox.bottom.toDouble(),
          left: bbox.left.toDouble(),
          right: bbox.right.toDouble(),
        ));
      }
    }

    // Sort top to bottom
    lines.sort((a, b) => a.top.compareTo(b.top));
    return lines;
  }

  // ── Step 2: Parse receipt from lines ───────────
  ParsedReceipt parseReceipt(
      List<RecognizedLine> lines) {
    if (lines.isEmpty) {
      return const ParsedReceipt(items: []);
    }

    final storeName = _detectStoreName(lines);
    final priceLines = _findPriceLines(lines);
    final items = _pairDescriptionsWithPrices(
        lines, priceLines);
    final totals = _extractTotals(lines, priceLines);

    return ParsedReceipt(
      items: items,
      subtotal: totals['subtotal'],
      tax: totals['tax'],
      total: totals['total'],
      storeName: storeName,
    );
  }

  // ── Full pipeline: image → ParsedReceipt ───────
  Future<ParsedReceipt> scanAndParse(
      File imageFile) async {
    final lines = await extractLines(imageFile);
    return parseReceipt(lines);
  }

  void dispose() {
    _recognizer.close();
  }

  // ─── Internal helpers ─────────────────────────

  // Price regex: matches $10.99, 10.99, 10.99 F, etc.
  static final _priceRegex = RegExp(
    r'^\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?|\d+\.\d{2})\s*[A-Z]?\s*$',
  );

  // Inline price: "Item Name    $10.99" on one line
  static final _inlinePriceRegex = RegExp(
    r'^(.+?)\s{2,}\$?(\d+\.\d{2})\s*[A-Z]?\s*$',
  );

  // Currency value extractor
  static final _currencyRegex = RegExp(
    r'\$?(\d+\.\d{2})',
  );

  static const _skipWords = [
    'subtotal', 'sub total', 'sub-total',
    'total', 'tax', 'tip', 'change', 'cash',
    'credit', 'debit', 'balance', 'amount',
    'thank', 'receipt', 'order', 'table',
    'visa', 'mastercard', 'approved', 'auth',
    'savings', 'rewards', 'points', 'member',
    'items sold', 'tc#', 'st#', 'op#', 'te#',
    'ref #', 'appr', 'terminal', 'eft',
    'change due', 'aid ', 'feedback', 'survey',
    'you pay', 'price', 'member savings', 'total savings',
  ];

  static const _storeKeywords = {
    'walmart': 'Walmart',
    'target': 'Target',
    'kroger': 'Kroger',
    'heb': 'HEB',
    'costco': 'Costco',
    'wholefoods': 'Whole Foods',
    'whole foods': 'Whole Foods',
    'trader joe': "Trader Joe's",
    'safeway': 'Safeway',
    'publix': 'Publix',
    'aldi': 'Aldi',
    'dollar tree': 'Dollar Tree',
  };

  String? _detectStoreName(
      List<RecognizedLine> lines) {
    // Check first 5 lines for store names
    for (final line
        in lines.take(5)) {
      final lower = line.text.toLowerCase();
      for (final entry in _storeKeywords.entries) {
        if (lower.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  bool _shouldSkip(String text) {
    final lower = text.toLowerCase();
    return _skipWords
        .any((w) => lower.contains(w));
  }

  bool _looksLikePrice(String text) {
    final trimmed = text.trim();
    return _priceRegex.hasMatch(trimmed);
  }

  double? _extractPrice(String text) {
    final match =
        _currencyRegex.firstMatch(text.trim());
    if (match == null) return null;
    final cleaned = match
        .group(1)!
        .replaceAll(',', '');
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0 || value > 9999) {
      return null;
    }
    return value;
  }

  // Find all lines that ARE prices (standalone)
  List<RecognizedLine> _findPriceLines(
      List<RecognizedLine> lines) {
    return lines
        .where((l) =>
            _looksLikePrice(l.text) &&
            !_shouldSkip(l.text))
        .toList();
  }

  // Core algorithm: pair item names with prices
  // Uses Y-axis proximity — price lines are matched
  // to the nearest description line above them
  List<ParsedReceiptItem> _pairDescriptionsWithPrices(
      List<RecognizedLine> allLines,
      List<RecognizedLine> priceLines) {
    final items = <ParsedReceiptItem>[];
    final usedLineIndices = <int>{};

    for (final priceLine in priceLines) {
      if (_shouldSkip(priceLine.text)) continue;

      final price = _extractPrice(priceLine.text);
      if (price == null) continue;

      // Find the closest description line ABOVE
      // this price line (within 3x line height)
      final maxDistance =
          priceLine.height * 3.0;
      RecognizedLine? bestMatch;
      double bestDistance = double.infinity;
      int bestIndex = -1;

      for (int i = 0; i < allLines.length; i++) {
        final line = allLines[i];

        // Must be above the price line
        if (line.centerY >= priceLine.centerY) {
          continue;
        }

        // Must not be a price itself
        if (_looksLikePrice(line.text)) continue;

        // Must not be a skip word
        if (_shouldSkip(line.text)) continue;

        // Must not already be used
        if (usedLineIndices.contains(i)) continue;

        // Must be within max distance
        final distance =
            priceLine.centerY - line.centerY;
        if (distance > maxDistance) continue;

        // Must look like an item name
        if (!_looksLikeName(line.text)) continue;

        if (distance < bestDistance) {
          bestDistance = distance;
          bestMatch = line;
          bestIndex = i;
        }
      }

      if (bestMatch != null) {
        usedLineIndices.add(bestIndex);
        final name = _formatName(bestMatch.text);
        items.add(ParsedReceiptItem(
          name: name,
          price: price,
          confidence: _calcConfidence(
              bestDistance, priceLine.height),
        ));
      }
    }

    // Also check for inline items (name + price on
    // the same line, separated by 2+ spaces)
    for (final line in allLines) {
      if (_shouldSkip(line.text)) continue;
      final match =
          _inlinePriceRegex.firstMatch(line.text);
      if (match != null) {
        final name = match.group(1)!.trim();
        final price =
            double.tryParse(match.group(2)!);
        if (price != null &&
            price > 0 &&
            price < 9999 &&
            _looksLikeName(name) &&
            !_shouldSkip(name)) {
          // Avoid duplicates
          final alreadyAdded = items.any((item) =>
              (item.name.toLowerCase() ==
                  _formatName(name).toLowerCase()));
          if (!alreadyAdded) {
            items.add(ParsedReceiptItem(
              name: _formatName(name),
              price: price,
              confidence: 0.9,
            ));
          }
        }
      }
    }

    // Remove duplicates by name+price
    final seen = <String>{};
    return items.where((item) {
      final key =
          '${item.name.toLowerCase()}_${item.price}';
      return seen.add(key);
    }).toList();
  }

  bool _looksLikeName(String text) {
    if (text.length < 2) return false;
    // Must start with a letter
    if (!RegExp(r'^[A-Za-z]').hasMatch(text)) {
      return false;
    }
    // Must not be only numbers
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return false;
    }
    // Must not be a barcode (long number string)
    if (RegExp(r'^\d{5,}').hasMatch(text)) {
      return false;
    }
    // Must have at least 2 letters
    final letterCount =
        text.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    return letterCount >= 2;
  }

  double _calcConfidence(
      double distance, double lineHeight) {
    // Closer = higher confidence
    if (distance <= lineHeight) return 0.95;
    if (distance <= lineHeight * 1.5) return 0.85;
    if (distance <= lineHeight * 2) return 0.75;
    return 0.6;
  }

  String _formatName(String raw) {
    // Remove leading/trailing spaces
    raw = raw.trim();
    // Remove trailing price if present
    raw = raw.replaceAll(
        RegExp(r'\s+\$?\d+\.\d{2}\s*$'), '');
    // Remove barcode numbers
    raw = raw.replaceAll(
        RegExp(r'\s+\d{5,}\s*$'), '');
    // Clean up extra spaces
    raw = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Proper case
    return raw
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : w[0].toUpperCase() +
                w.substring(1).toLowerCase())
        .join(' ');
  }

  Map<String, double?> _extractTotals(
      List<RecognizedLine> allLines,
      List<RecognizedLine> priceLines) {
    double? subtotal;
    double? tax;
    double? total;

    for (final line in allLines) {
      final lower = line.text.toLowerCase();

      // Look for price on same line or next line
      double? price = _extractPrice(line.text);

      // If no inline price, check next line
      if (price == null) {
        final idx = allLines.indexOf(line);
        if (idx < allLines.length - 1) {
          price = _extractPrice(
              allLines[idx + 1].text);
        }
      }

      if (price == null) continue;

      if (lower.contains('subtotal') ||
          lower.contains('sub total')) {
        subtotal = price;
      } else if (lower.contains('tax')) {
        tax = price;
      } else if (lower.contains('total') &&
          !lower.contains('subtotal')) {
        // Take the highest 'total' value found
        if (total == null || price > total) {
          total = price;
        }
      }
    }

    return {
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
    };
  }
}
