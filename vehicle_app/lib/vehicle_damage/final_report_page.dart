import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Map<String, dynamic>? extractClaimDamageImage(Map<String, dynamic> claim) {
  final aiResult = (claim['ai_result'] as Map?)?.cast<String, dynamic>() ?? {};
  final candidates = <dynamic>[
    claim['damage_image'],
    claim['damageImage'],
    aiResult['damage_image'],
    aiResult['damageImage'],
  ];

  for (final raw in candidates) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Ignore malformed JSON strings and continue checking fallbacks.
      }
    }
  }

  return null;
}

Uint8List? _decodeClaimDamageImageBytes(Map<String, dynamic>? damageImage) {
  var encoded =
      (damageImage?['data_base64'] ??
              damageImage?['base64'] ??
              damageImage?['bytes_base64'] ??
              damageImage?['data'])
          ?.toString()
          .trim();
  if (encoded == null || encoded.isEmpty) {
    return null;
  }

  if (encoded.startsWith('data:')) {
    final commaIndex = encoded.indexOf(',');
    if (commaIndex != -1 && commaIndex < encoded.length - 1) {
      encoded = encoded.substring(commaIndex + 1).trim();
    }
  }

  encoded = encoded.replaceAll(RegExp(r'\s+'), '');
  final remainder = encoded.length % 4;
  if (remainder != 0) {
    encoded = '$encoded${'=' * (4 - remainder)}';
  }

  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}

Uint8List buildFinalReportPdf(
  Map<String, dynamic> claim,
  String Function(dynamic) formatDate,
) {
  final aiResult = (claim['ai_result'] as Map?)?.cast<String, dynamic>() ?? {};
  final damageDetection =
      (aiResult['damage_detection'] as Map?)?.cast<String, dynamic>() ?? {};
  final priceEstimation =
      (aiResult['price_estimation'] as Map?)?.cast<String, dynamic>() ?? {};
  final partMapping =
      (aiResult['part_mapping'] as Map?)?.cast<String, dynamic>() ?? {};
  final vehicle = (claim['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};
  final damages =
      (damageDetection['detected_damages'] as List?)
          ?.map((item) => item.toString())
          .toList() ??
      <String>[];
  final confidences = damageDetection['confidences'] as Map? ?? {};
  final breakdown = priceEstimation['breakdown'] as Map? ?? {};
  final affectedPart = partMapping['affected_part']?.toString().trim() ?? '';
  final currency = priceEstimation['currency']?.toString() ?? 'LKR';
  final damageImage = extractClaimDamageImage(claim);
  final damageImageBytes = _decodeClaimDamageImageBytes(damageImage);
  final damageImageContentType =
      damageImage?['content_type']?.toString().trim() ?? 'image/jpeg';
  final imageWidth = damageImage?['width'] is num
      ? (damageImage!['width'] as num).toDouble()
      : 960.0;
  final imageHeight = damageImage?['height'] is num
      ? (damageImage!['height'] as num).toDouble()
      : 540.0;
  final hasJpegImage = damageImageBytes != null &&
      (damageImageContentType.toLowerCase().contains('jpeg') ||
          damageImageContentType.toLowerCase().contains('jpg'));

  String pdfEsc(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');

  String money(dynamic value) {
    if (value is num) {
      return NumberFormat('#,##0.00', 'en_US').format(value);
    }
    return 'N/A';
  }

  final claimId =
      claim['id']?.toString() ?? aiResult['claim_id']?.toString() ?? 'N/A';
  final vehicleLabel =
      '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''} ${vehicle['year'] ?? ''}'
          .trim();
  final decision = claim['decision']?.toString() ?? '';
  final generatedAt = DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.now());
  final finalCost = claim['final_cost'];
  final estimatedPrice = priceEstimation['estimated_price'];

  final lines = <_PdfLine>[
    _PdfLine('Claim Assessment Report', bold: true, size: 20),
    _PdfLine(vehicleLabel.isEmpty ? 'Unknown Vehicle' : vehicleLabel),
    _PdfLine(''),
    _PdfLine('Report Summary', bold: true, size: 15),
    _PdfLine('Claim ID: $claimId'),
    _PdfLine('Generated: $generatedAt'),
    _PdfLine(''),
    _PdfLine('Vehicle Details', bold: true, size: 15),
    _PdfLine('Brand: ${vehicle['brand']?.toString() ?? 'N/A'}'),
    _PdfLine('Model: ${vehicle['model']?.toString() ?? 'N/A'}'),
    _PdfLine('Year: ${vehicle['year']?.toString() ?? 'N/A'}'),
    _PdfLine(''),
    _PdfLine('Claim Timeline', bold: true, size: 15),
    _PdfLine('Submitted: ${formatDate(claim['created_at'])}'),
    if (claim['sent_at'] != null)
      _PdfLine('Sent to insurer: ${formatDate(claim['sent_at'])}'),
    if (claim['decided_at'] != null)
      _PdfLine('Decision submitted: ${formatDate(claim['decided_at'])}'),
    _PdfLine(''),
    _PdfLine('AI Damage Assessment', bold: true, size: 15),
    if (damages.isEmpty)
      _PdfLine('No damages detected')
    else
      ...damages.map((damage) {
        final confidence = confidences[damage];
        final confidenceLabel = confidence is num
            ? ' (${(confidence * 100).toStringAsFixed(1)}%)'
            : '';
        return _PdfLine(
          '- ${damage.replaceAll('_', ' ').toUpperCase()}$confidenceLabel',
        );
      }),
    if (affectedPart.isNotEmpty)
      _PdfLine('Affected Part: ${affectedPart.replaceAll('_', ' ').toUpperCase()}'),
    _PdfLine(''),
    _PdfLine('Predicted Cost Breakdown', bold: true, size: 15),
    _PdfLine(
      'Parts & Materials: ${breakdown['parts'] is num ? '$currency ${money(breakdown['parts'])}' : 'N/A'}',
    ),
    _PdfLine(
      'Paint & Finishing: ${breakdown['paint'] is num ? '$currency ${money(breakdown['paint'])}' : 'N/A'}',
    ),
    _PdfLine(
      'AI Predicted Total: ${estimatedPrice is num ? '$currency ${money(estimatedPrice)}' : 'N/A'}',
    ),
    _PdfLine(''),
    _PdfLine('Insurer Decision', bold: true, size: 15),
    _PdfLine(
      'Status: ${decision == 'confirmed' ? 'AI Estimate Confirmed' : decision == 'adjusted' ? 'Cost Adjusted by Insurer' : 'Pending'}',
    ),
    _PdfLine(
      'Final Approved Cost: ${finalCost is num ? '$currency ${money(finalCost)}' : 'N/A'}',
    ),
    if (claim['notes']?.toString().trim().isNotEmpty == true)
      _PdfLine('Insurer Notes: ${claim['notes'].toString().trim()}'),
  ];

  final wrappedLines = <_PdfLine>[];
  for (final line in lines) {
    wrappedLines.addAll(_wrapPdfLine(line));
  }

  const pageWidth = 595.0;
  const pageHeight = 842.0;
  const margin = 40.0;
  final stream = StringBuffer();
  var currentY = pageHeight - margin;

  if (hasJpegImage) {
    final maxWidth = pageWidth - (margin * 2);
    const maxHeight = 220.0;
    final scale = math.min(maxWidth / imageWidth, maxHeight / imageHeight);
    final drawWidth = imageWidth * scale;
    final drawHeight = imageHeight * scale;
    final imageX = (pageWidth - drawWidth) / 2;
    final imageY = currentY - drawHeight;
    stream.writeln(
      'q ${drawWidth.toStringAsFixed(2)} 0 0 ${drawHeight.toStringAsFixed(2)} ${imageX.toStringAsFixed(2)} ${imageY.toStringAsFixed(2)} cm /Im1 Do Q',
    );
    currentY = imageY - 24;
  }

  for (final line in wrappedLines) {
    final font = line.bold ? '/F2' : '/F1';
    final lineHeight = line.size + 4.0;
    if (line.text.isEmpty) {
      currentY -= lineHeight / 2;
      continue;
    }

    stream.writeln(
      'BT $font ${line.size.toStringAsFixed(2)} Tf ${margin.toStringAsFixed(2)} ${currentY.toStringAsFixed(2)} Td (${pdfEsc(line.text)}) Tj ET',
    );
    currentY -= lineHeight;
  }

  final objects = <int, Uint8List>{};
  void addObject(int id, String content) {
    objects[id] = Uint8List.fromList(utf8.encode(content));
  }

  void addStreamObject(int id, String header, Uint8List bytes) {
    final builder = BytesBuilder()
      ..add(utf8.encode(header))
      ..add(bytes)
      ..add(utf8.encode('\nendstream'));
    objects[id] = builder.toBytes();
  }

  addObject(1, '<< /Type /Catalog /Pages 2 0 R >>');
  addObject(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  addObject(4, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  addObject(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

  final contentObjectId = hasJpegImage ? 7 : 6;
  if (hasJpegImage) {
    addStreamObject(
      6,
      '<< /Type /XObject /Subtype /Image /Width ${imageWidth.round()} /Height ${imageHeight.round()} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${damageImageBytes.length} >>\nstream\n',
      damageImageBytes,
    );
  }

  final contentBytes = Uint8List.fromList(utf8.encode(stream.toString()));
  addStreamObject(
    contentObjectId,
    '<< /Length ${contentBytes.length} >>\nstream\n',
    contentBytes,
  );

  final resources = hasJpegImage
      ? '<< /Font << /F1 4 0 R /F2 5 0 R >> /XObject << /Im1 6 0 R >> >>'
      : '<< /Font << /F1 4 0 R /F2 5 0 R >> >>';
  addObject(
    3,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight] /Resources $resources /Contents $contentObjectId 0 R >>',
  );

  final output = BytesBuilder()..add(utf8.encode('%PDF-1.4\n'));
  final offsets = <int, int>{};
  final objectIds = objects.keys.toList()..sort();

  for (final id in objectIds) {
    offsets[id] = output.length;
    output.add(utf8.encode('$id 0 obj\n'));
    output.add(objects[id]!);
    output.add(utf8.encode('\nendobj\n'));
  }

  final xrefStart = output.length;
  output.add(utf8.encode('xref\n0 ${objectIds.length + 1}\n'));
  output.add(utf8.encode('0000000000 65535 f \n'));
  for (final id in objectIds) {
    final offset = offsets[id] ?? 0;
    output.add(utf8.encode('${offset.toString().padLeft(10, '0')} 00000 n \n'));
  }

  output.add(
    utf8.encode(
      'trailer\n<< /Size ${objectIds.length + 1} /Root 1 0 R >>\nstartxref\n$xrefStart\n%%EOF',
    ),
  );

  return output.toBytes();
}

class _PdfLine {
  final String text;
  final bool bold;
  final double size;

  const _PdfLine(
    this.text, {
    this.bold = false,
    this.size = 12,
  });
}

List<_PdfLine> _wrapPdfLine(_PdfLine line) {
  if (line.text.isEmpty) {
    return [line];
  }

  final maxChars = line.bold ? 58 : 82;
  if (line.text.length <= maxChars) {
    return [line];
  }

  final words = line.text.split(' ');
  final wrapped = <_PdfLine>[];
  var current = '';

  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length <= maxChars) {
      current = candidate;
    } else {
      if (current.isNotEmpty) {
        wrapped.add(_PdfLine(current, bold: line.bold, size: line.size));
      }
      current = word;
    }
  }

  if (current.isNotEmpty) {
    wrapped.add(_PdfLine(current, bold: line.bold, size: line.size));
  }

  return wrapped;
}

class FinalReportPage extends StatelessWidget {
  final Map<String, dynamic> claim;
  final String Function(dynamic) formatDate;

  const FinalReportPage({
    super.key,
    required this.claim,
    required this.formatDate,
  });

  Map<String, dynamic> get _aiResult =>
      (claim['ai_result'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _dd =>
      (_aiResult['damage_detection'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _pe =>
      (_aiResult['price_estimation'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _pm =>
      (_aiResult['part_mapping'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _vehicle =>
      (claim['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};

  List<String> get _damages =>
      (_dd['detected_damages'] as List?)?.map((d) => d.toString()).toList() ??
      [];

  Map get _confidences => (_dd['confidences'] as Map?) ?? {};

  Map get _breakdown => (_pe['breakdown'] as Map?) ?? {};

  double? get _aiPrice {
    final p = _pe['estimated_price'];
    return p != null ? (p as num).toDouble() : null;
  }

  double? get _finalCost {
    final f = claim['final_cost'];
    return f != null ? (f as num).toDouble() : null;
  }

  String get _currency => _pe['currency']?.toString() ?? 'LKR';

  String get _claimId =>
      claim['id']?.toString() ?? _aiResult['claim_id']?.toString() ?? 'N/A';

  String get _decision => claim['decision']?.toString() ?? '';

  String get _vehicleLabel {
    final b = _vehicle['brand'] ?? '';
    final m = _vehicle['model'] ?? '';
    final y = _vehicle['year'] ?? '';
    return '$b $m $y'.trim().isEmpty ? 'Unknown Vehicle' : '$b $m $y'.trim();
  }

  Map<String, dynamic>? get _damageImage {
    return extractClaimDamageImage(claim);
  }

  Uint8List? get _damageImageBytes => _decodeClaimDamageImageBytes(_damageImage);

  String _fmt(num value) => NumberFormat('#,##0.00', 'en_US').format(value);

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Final Report'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ReportCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.summarize,
                          color: Colors.indigo[700],
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Claim Assessment Report',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _vehicleLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _kv('Claim ID', _claimId, monospace: true),
                  _kv('Generated', now),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_damageImageBytes != null) ...[
              _ReportSection(
                icon: Icons.photo_camera_outlined,
                iconColor: Colors.indigo[700]!,
                title: 'Uploaded Damage Photo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _damageImageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 220,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _ReportSection(
              icon: Icons.directions_car,
              iconColor: Colors.blue[700]!,
              title: 'Vehicle Details',
              child: Column(
                children: [
                  _kv('Brand', _vehicle['brand']?.toString() ?? 'N/A'),
                  _kv('Model', _vehicle['model']?.toString() ?? 'N/A'),
                  _kv('Year', _vehicle['year']?.toString() ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ReportSection(
              icon: Icons.timeline,
              iconColor: Colors.teal[700]!,
              title: 'Claim Timeline',
              child: Column(
                children: [
                  _TimelineEvent(
                    icon: Icons.upload_file,
                    color: Colors.blue[700]!,
                    label: 'Submitted',
                    date: formatDate(claim['created_at']),
                  ),
                  if (claim['sent_at'] != null)
                    _TimelineEvent(
                      icon: Icons.send,
                      color: Colors.orange[700]!,
                      label: 'Sent to insurer',
                      date: formatDate(claim['sent_at']),
                    ),
                  if (claim['decided_at'] != null)
                    _TimelineEvent(
                      icon: Icons.gavel,
                      color: Colors.green[700]!,
                      label: 'Decision submitted',
                      date: formatDate(claim['decided_at']),
                      isLast: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ReportSection(
              icon: Icons.auto_awesome,
              iconColor: Colors.orange[700]!,
              title: 'AI Damage Assessment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_damages.isEmpty)
                    const Text(
                      'No damages detected',
                      style: TextStyle(color: Colors.green),
                    )
                  else
                    ..._damages.map((damage) {
                      final conf = _confidences[damage];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              damage.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (conf != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${((conf as num) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  if (_pm['affected_part'] != null &&
                      _pm['affected_part'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.build, size: 15, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          const Text(
                            'Affected Part: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _pm['affected_part']
                                .toString()
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ReportSection(
              icon: Icons.receipt_long,
              iconColor: Colors.orange[700]!,
              title: 'Predicted Cost Breakdown',
              child: Column(
                children: [
                  if (_breakdown['parts'] != null)
                    _CostRow(
                      icon: Icons.build_circle,
                      iconColor: Colors.blue[700]!,
                      bgColor: Colors.blue[50]!,
                      label: 'Parts & Materials',
                      value: '$_currency ${_fmt(_breakdown['parts'] as num)}',
                    ),
                  if (_breakdown['paint'] != null)
                    _CostRow(
                      icon: Icons.format_paint,
                      iconColor: Colors.purple[700]!,
                      bgColor: Colors.purple[50]!,
                      label: 'Paint & Finishing',
                      value: '$_currency ${_fmt(_breakdown['paint'] as num)}',
                    ),
                  if (_aiPrice != null) ...[
                    const Divider(thickness: 1.5),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI PREDICTED TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$_currency ${_fmt(_aiPrice!)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ReportSection(
              icon: Icons.gavel,
              iconColor: _decision == 'confirmed'
                  ? Colors.green[700]!
                  : Colors.blue[700]!,
              title: 'Insurer Decision',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _decision == 'confirmed'
                          ? Colors.green[50]
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _decision == 'confirmed'
                            ? Colors.green[300]!
                            : Colors.blue[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _decision == 'confirmed'
                              ? Icons.check_circle
                              : Icons.edit_note,
                          color: _decision == 'confirmed'
                              ? Colors.green[700]
                              : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _decision == 'confirmed'
                              ? 'AI Estimate Confirmed'
                              : 'Cost Adjusted by Insurer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _decision == 'confirmed'
                                ? Colors.green[800]
                                : Colors.blue[800],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_finalCost != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FINAL APPROVED COST',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_currency ${_fmt(_finalCost!)}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (claim['notes'] != null &&
                      claim['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notes,
                                size: 15,
                                color: Colors.amber[800],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Insurer Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            claim['notes'].toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_decision == 'adjusted' &&
                _aiPrice != null &&
                _finalCost != null) ...[
              _ReportSection(
                icon: Icons.compare_arrows,
                iconColor: Colors.indigo[700]!,
                title: 'Cost Comparison',
                child: Column(
                  children: [
                    _CompareRow(
                      label: 'AI Predicted',
                      value: '$_currency ${_fmt(_aiPrice!)}',
                      valueColor: Colors.orange[800]!,
                    ),
                    _CompareRow(
                      label: 'Final (Insurer)',
                      value: '$_currency ${_fmt(_finalCost!)}',
                      valueColor: Colors.blue[800]!,
                    ),
                    const Divider(thickness: 1),
                    Builder(
                      builder: (context) {
                        final diff = _finalCost! - _aiPrice!;
                        final isHigher = diff > 0;
                        final diffStr =
                            '${isHigher ? '+' : ''}$_currency ${_fmt(diff.abs())}';
                        return _CompareRow(
                          label: 'Difference',
                          value: isHigher ? '^ $diffStr' : 'v $diffStr',
                          valueColor:
                              isHigher ? Colors.red[700]! : Colors.green[700]!,
                          bold: true,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'This report was generated by the Chathurya AI Assessment System.\n'
                'AI predictions are indicative only. Final cost is determined by the insurer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$key:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: monospace
                ? SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  )
                : Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReportSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _ReportSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String date;
  final bool isLast;

  const _TimelineEvent({
    required this.icon,
    required this.color,
    required this.label,
    required this.date,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _CostRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _CompareRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
