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
  final int? quantity;

  const ParsedReceiptItem({
    required this.name,
    required this.price,
    required this.confidence,
    this.quantity,
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
    final excludedLineIndices = _collectExcludedLineIndices(lines);
    final priceLines = _findPriceLines(lines, excludedLineIndices);
    final items = _pairDescriptionsWithPrices(
      lines,
      priceLines,
      excludedLineIndices: excludedLineIndices,
    );
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

  // Quantity patterns: "2 @", "x2", "qty 2"
  static final _qtyAtRegex = RegExp(r'(\d+)\s*@');
  static final _qtyXRegex = RegExp(r'[xX]\s*(\d+)\b');
  static final _qtyLabelRegex = RegExp(r'qty\s*(\d+)', caseSensitive: false);

  // Card masking: ****1234, 1234****5678, etc.
  static final _cardMaskRegex = RegExp(r'\*{2,}');

  // OCR artifacts and non-item numeric lines
  static final _zeroValueArtifactRegex = RegExp(r'^\$?0[,.]00\s*$');

  // Unit/quantity metadata: "25 ea", "3.04 lb 0.49"
  static final _unitOnlyRegex = RegExp(
    r'^\d+(?:\.\d+)?\s*(?:ea|each|pk|pkg|ct|oz|lb|lbs|kg|g|ml|l)\.?\s*$',
    caseSensitive: false,
  );
  static final _unitWithPriceRegex = RegExp(
    r'^\d+(?:\.\d+)?\s*(?:lb|lbs|oz|kg|g|ea|each)\s+\d+(?:\.\d{2})?\s*$',
    caseSensitive: false,
  );
  static final _unitQtyRegex = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(?:ea|each|pk|pkg|ct)\.?\s*$',
    caseSensitive: false,
  );

  static final _trailingUnitRegex = RegExp(
    r'(?:\s+|^)\d+(?:\.\d+)?\s*(?:ea|each|pk|pkg|ct|oz|lb|lbs|kg|g|ml|l)\.?\s*$',
    caseSensitive: false,
  );
  static final _trailingUnitWithPriceRegex = RegExp(
    r'(?:\s+|^)\d+(?:\.\d+)?\s*(?:lb|lbs|oz|kg|g|ea|each)\s+\d+(?:\.\d{2})?\s*$',
    caseSensitive: false,
  );

  // PLU/SKU product codes: pure 4-5 digit strings
  static final _skuMetadataRegex = RegExp(r'^\d{4,5}$');

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
    'ending in', 'card number', 'account number', 'masked',
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
    final trimmed = text.trim();
    if (_isCardMask(trimmed)) return true;
    if (_isOcrArtifact(trimmed)) return true;

    final lower = trimmed.toLowerCase();
    return _skipWords.any((w) => lower.contains(w));
  }

  bool _isCardMask(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('****')) return true;
    if (_cardMaskRegex.hasMatch(trimmed) &&
        RegExp(r'\d').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  bool _isTotalsLabel(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('subtotal') ||
        lower.contains('sub total') ||
        lower.contains('sub-total')) {
      return true;
    }
    if (RegExp(r'\btax\b').hasMatch(lower)) return true;
    if (RegExp(r'\btotal\b').hasMatch(lower) &&
        !lower.contains('subtotal')) {
      return true;
    }
    return false;
  }

  bool _isOcrArtifact(String text) {
    final trimmed = text.trim();
    if (_zeroValueArtifactRegex.hasMatch(trimmed)) return true;

    // Comma-decimal OCR noise like "0,00" or "12,99" without a currency symbol
    if (RegExp(r'^\d+[,.]\d{2}\s*$').hasMatch(trimmed)) {
      final normalized =
          trimmed.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
      final value = double.tryParse(normalized);
      if (value == null || value == 0) return true;
    }

    return false;
  }

  bool _isUnitMetadataLine(String text) {
    final trimmed = text.trim();
    return _unitOnlyRegex.hasMatch(trimmed) ||
        _unitWithPriceRegex.hasMatch(trimmed);
  }

  bool _isSkuMetadataLine(String text) {
    return _skuMetadataRegex.hasMatch(text.trim());
  }

  bool _isItemMetadataLine(String text) {
    return _isUnitMetadataLine(text) || _isSkuMetadataLine(text);
  }

  bool _samePriceRow(RecognizedLine a, RecognizedLine b) {
    final tolerance = ((a.height + b.height) / 2) * 0.6;
    return (a.centerY - b.centerY).abs() <= tolerance;
  }

  Set<int> _collectExcludedLineIndices(List<RecognizedLine> lines) {
    final excluded = <int>{};

    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].text;

      if (_isCardMask(text) ||
          _isOcrArtifact(text) ||
          _isItemMetadataLine(text)) {
        excluded.add(i);
      }

      if (!_isTotalsLabel(text)) continue;

      excluded.add(i);

      // Exclude nearby standalone prices tied to subtotal/tax/total rows
      for (int j = i; j <= i + 2 && j < lines.length; j++) {
        final candidate = lines[j].text;
        if (_looksLikePrice(candidate) ||
            _isOcrArtifact(candidate) ||
            (_extractPrice(candidate) != null && _isTotalsLabel(text))) {
          excluded.add(j);
        }
      }
    }

    for (int i = 0; i < lines.length; i++) {
      if (!_looksLikePrice(lines[i].text)) continue;
      if (_isTotalsPriceLine(lines, i)) {
        excluded.add(i);
      }
    }

    return excluded;
  }

  bool _isTotalsPriceLine(List<RecognizedLine> lines, int priceIndex) {
    for (int j = priceIndex - 1; j >= 0 && j >= priceIndex - 3; j--) {
      if (_isTotalsLabel(lines[j].text)) return true;

      final between = lines[j].text.trim();
      if (between.isEmpty ||
          _isItemMetadataLine(between) ||
          _isOcrArtifact(between)) {
        continue;
      }

      if (!_looksLikePrice(between)) return false;
    }
    return false;
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
      List<RecognizedLine> lines, Set<int> excludedLineIndices) {
    return lines
        .asMap()
        .entries
        .where((entry) =>
            !excludedLineIndices.contains(entry.key) &&
            _looksLikePrice(entry.value.text) &&
            !_shouldSkip(entry.value.text))
        .map((entry) => entry.value)
        .toList();
  }

  /// When unit price and line total share a row, keep only the highest price.
  Set<int> _findSuppressedPriceIndices(
    List<RecognizedLine> allLines,
    List<RecognizedLine> priceLines,
  ) {
    final suppressed = <int>{};
    final processed = <int>{};

    for (final anchor in priceLines) {
      final anchorIndex = allLines.indexOf(anchor);
      if (anchorIndex == -1 || processed.contains(anchorIndex)) continue;

      final sameRowIndices = <int>[anchorIndex];
      for (final candidate in priceLines) {
        final candidateIndex = allLines.indexOf(candidate);
        if (candidateIndex == -1 || candidateIndex == anchorIndex) continue;
        if (_samePriceRow(anchor, candidate)) {
          sameRowIndices.add(candidateIndex);
        }
      }

      if (sameRowIndices.length <= 1) {
        processed.add(anchorIndex);
        continue;
      }

      var bestIndex = sameRowIndices.first;
      var bestPrice = _extractPrice(allLines[bestIndex].text) ?? 0;

      for (final index in sameRowIndices) {
        processed.add(index);
        final price = _extractPrice(allLines[index].text) ?? 0;
        if (price > bestPrice) {
          bestPrice = price;
          bestIndex = index;
        }
      }

      for (final index in sameRowIndices) {
        if (index != bestIndex) suppressed.add(index);
      }
    }

    return suppressed;
  }

  // Core algorithm: pair item names with prices
  // Uses Y-axis proximity — price lines are matched
  // to the nearest description line above them
  List<ParsedReceiptItem> _pairDescriptionsWithPrices(
      List<RecognizedLine> allLines,
      List<RecognizedLine> priceLines, {
      required Set<int> excludedLineIndices,
    }) {
    final items = <ParsedReceiptItem>[];
    final usedLineIndices = <int>{...excludedLineIndices};
    usedLineIndices.addAll(
      _findSuppressedPriceIndices(allLines, priceLines),
    );

    for (final priceLine in priceLines) {
      final priceIndex = allLines.indexOf(priceLine);
      if (priceIndex == -1) continue;
      if (usedLineIndices.contains(priceIndex)) continue;
      if (_shouldSkip(priceLine.text)) continue;

      final price = _extractPrice(priceLine.text);
      if (price == null) continue;

      final match = _findDescriptionForPrice(
        allLines: allLines,
        priceLine: priceLine,
        priceIndex: priceIndex,
        usedLineIndices: usedLineIndices,
      );

      if (match != null) {
        usedLineIndices.add(match.index);
        final metadata = _collectItemMetadataBetween(
          allLines: allLines,
          startIndex: match.index,
          endIndex: priceIndex,
          usedLineIndices: usedLineIndices,
        );

        items.add(_buildParsedItem(
          rawName: _appendMetadata(match.line.text, metadata.text),
          price: price,
          distance: match.distance,
          lineHeight: priceLine.height,
          isFallback: match.isFallback,
          quantityOverride: metadata.quantity,
        ));
      }
    }

    // Also check for inline items (name + price on
    // the same line, separated by 2+ spaces)
    for (int i = 0; i < allLines.length; i++) {
      final line = allLines[i];
      if (usedLineIndices.contains(i)) continue;
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
            final metadata = _collectItemMetadataBetween(
              allLines: allLines,
              startIndex: i,
              endIndex: i + 1,
              usedLineIndices: usedLineIndices,
            );

            items.add(_buildParsedItem(
              rawName: _appendMetadata(name, metadata.text),
              price: price,
              distance: 0,
              lineHeight: line.height,
              isFallback: false,
              inlineConfidence: 0.9,
              quantityOverride: metadata.quantity,
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

  /// Primary pass: description directly above the price (within 3x line height).
  /// Fallback pass: sliding window over nearby lines for the nearest non-price text.
  _DescriptionMatch? _findDescriptionForPrice({
    required List<RecognizedLine> allLines,
    required RecognizedLine priceLine,
    required int priceIndex,
    required Set<int> usedLineIndices,
  }) {
    final strictWindow = priceLine.height * 3.0;

    RecognizedLine? bestMatch;
    double bestDistance = double.infinity;
    int bestIndex = -1;

    // Pass 1: strict vertical match — description above the price line
    for (int i = 0; i < allLines.length; i++) {
      final line = allLines[i];
      if (line.centerY >= priceLine.centerY) continue;
      if (_looksLikePrice(line.text)) continue;
      if (_shouldSkip(line.text)) continue;
      if (_isItemMetadataLine(line.text)) continue;
      if (usedLineIndices.contains(i)) continue;

      final distance = priceLine.centerY - line.centerY;
      if (distance > strictWindow) continue;
      if (!_looksLikeName(line.text)) continue;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = line;
        bestIndex = i;
      }
    }

    if (bestMatch != null) {
      return _DescriptionMatch(
        line: bestMatch,
        index: bestIndex,
        distance: bestDistance,
        isFallback: false,
      );
    }

    // Pass 2: sliding window — nearest non-price text around the price line
    const windowRadius = 6;
    final windowStart = (priceIndex - windowRadius).clamp(0, allLines.length - 1);
    final windowEnd = (priceIndex + windowRadius).clamp(0, allLines.length - 1);
    final expandedWindow = priceLine.height * 5.0;

    bestMatch = null;
    bestDistance = double.infinity;
    bestIndex = -1;

    for (int i = windowStart; i <= windowEnd; i++) {
      final line = allLines[i];
      if (line == priceLine) continue;
      if (_looksLikePrice(line.text)) continue;
      if (_shouldSkip(line.text)) continue;
      if (_isItemMetadataLine(line.text)) continue;
      if (usedLineIndices.contains(i)) continue;

      final distance = (priceLine.centerY - line.centerY).abs();
      if (distance > expandedWindow) continue;
      if (!_looksLikeName(line.text)) continue;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = line;
        bestIndex = i;
      }
    }

    if (bestMatch == null) return null;

    return _DescriptionMatch(
      line: bestMatch,
      index: bestIndex,
      distance: bestDistance,
      isFallback: true,
    );
  }

  _UnitMetadata _collectItemMetadataBetween({
    required List<RecognizedLine> allLines,
    required int startIndex,
    required int endIndex,
    required Set<int> usedLineIndices,
  }) {
    final metadataParts = <String>[];
    int? quantity;

    for (int i = startIndex + 1; i < endIndex && i < allLines.length; i++) {
      final lineText = allLines[i].text.trim();

      if (_isSkuMetadataLine(lineText)) {
        usedLineIndices.add(i);
        continue;
      }

      if (!_isUnitMetadataLine(lineText)) continue;

      usedLineIndices.add(i);
      metadataParts.add(lineText);
      quantity ??= _extractQuantityFromUnitLine(lineText);
    }

    return _UnitMetadata(
      text: metadataParts.join(' '),
      quantity: quantity,
    );
  }

  String _appendMetadata(String rawName, String metadata) {
    if (metadata.isEmpty) return rawName;
    return '$rawName $metadata';
  }

  ParsedReceiptItem _buildParsedItem({
    required String rawName,
    required double price,
    required double distance,
    required double lineHeight,
    required bool isFallback,
    double? inlineConfidence,
    int? quantityOverride,
  }) {
    final confidence = inlineConfidence ??
        _calcConfidence(distance, lineHeight) *
            (isFallback ? 0.85 : 1.0);

    return ParsedReceiptItem(
      name: _formatName(rawName),
      price: price,
      confidence: confidence,
      quantity: quantityOverride ?? _extractQuantity(rawName),
    );
  }

  int? _extractQuantityFromUnitLine(String text) {
    final unitMatch = _unitQtyRegex.firstMatch(text.trim());
    if (unitMatch == null) return null;

    final qty = double.tryParse(unitMatch.group(1)!);
    if (qty == null || qty <= 0 || qty >= 1000) return null;
    return qty.round();
  }

  int? _extractQuantity(String text) {
    final patterns = [_qtyAtRegex, _qtyXRegex, _qtyLabelRegex];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      final qty = int.tryParse(match.group(1)!);
      if (qty != null && qty > 0 && qty < 1000) {
        return qty;
      }
    }
    return null;
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
    // Must not be a PLU/SKU code
    if (_isSkuMetadataLine(text.trim())) return false;
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
    // Strip unit metadata fragments before name cleanup
    raw = raw.replaceAll(_trailingUnitRegex, '');
    raw = raw.replaceAll(_trailingUnitWithPriceRegex, '');
    // Remove quantity markers before other cleanup
    raw = raw.replaceAll(_qtyAtRegex, '');
    raw = raw.replaceAll(_qtyXRegex, '');
    raw = raw.replaceAll(_qtyLabelRegex, '');
    // Remove trailing price if present
    raw = raw.replaceAll(
        RegExp(r'\s+\$?\d+\.\d{2}\s*$'), '');
    // Remove trailing PLU/SKU codes and barcodes
    raw = raw.replaceAll(RegExp(r'\s+\d{4,5}\s*$'), '');
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

class _DescriptionMatch {
  final RecognizedLine line;
  final int index;
  final double distance;
  final bool isFallback;

  const _DescriptionMatch({
    required this.line,
    required this.index,
    required this.distance,
    required this.isFallback,
  });
}

class _UnitMetadata {
  final String text;
  final int? quantity;

  const _UnitMetadata({
    required this.text,
    this.quantity,
  });
}
