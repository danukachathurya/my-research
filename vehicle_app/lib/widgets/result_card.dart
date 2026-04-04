import 'package:flutter/material.dart';
import '../services/classifier_service.dart';
import '../models/warning_info.dart';

class ResultCard extends StatelessWidget {
  final PredictionResult result;
  final WarningInfo? warningInfo;

  const ResultCard({super.key, required this.result, this.warningInfo});

  @override
  Widget build(BuildContext context) {
    if (result.isOOD) {
      return _OODCard();
    }

    final info = warningInfo;
    final severityColor = info != null
        ? WarningDatabase.getSeverityColor(info.severity)
        : Colors.blueGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main prediction card ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: severityColor.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: emoji + name + severity badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info?.emoji ?? '⚠️',
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info?.displayName ?? _formatLabel(result.prediction!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (info != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: severityColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              info.severity.toUpperCase(),
                              style: TextStyle(
                                color: severityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Confidence bar
              _ConfidenceBar(
                confidence: result.confidence,
                color: severityColor,
              ),

              const SizedBox(height: 20),

              // Description
              if (info != null) ...[
                _SectionTitle('What it means'),
                const SizedBox(height: 6),
                Text(
                  info.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Advice
                _SectionTitle('What to do'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: severityColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates,
                        color: severityColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          info.advice,
                          style: TextStyle(
                            color: severityColor.withOpacity(0.9),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Top 3 scores ─────────────────────────────────────
        _TopScoresCard(scores: result.allScores),
      ],
    );
  }

  String _formatLabel(String label) {
    return label
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ─────────────────────────────────────────────
// Confidence progress bar
// ─────────────────────────────────────────────
class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  final Color color;

  const _ConfidenceBar({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Confidence',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Text(
              '${(confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Top 3 class scores
// ─────────────────────────────────────────────
class _TopScoresCard extends StatelessWidget {
  final Map<String, double> scores;

  const _TopScoresCard({required this.scores});

  @override
  Widget build(BuildContext context) {
    final top3 = scores.entries.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Predictions',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...top3.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final info = WarningDatabase.getWarning(e.key);
            final color = i == 0 ? const Color(0xFF5C6BC0) : Colors.white24;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    info?.emoji ?? '•',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info?.displayName ??
                              e.key
                                  .split('_')
                                  .map(
                                    (w) => w[0].toUpperCase() + w.substring(1),
                                  )
                                  .join(' '),
                          style: TextStyle(
                            color: i == 0 ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: i == 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: e.value,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(e.value * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: i == 0 ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OOD (unknown image) card
// ─────────────────────────────────────────────
class _OODCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Not a Dashboard Indicator',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The image does not appear to be a recognized vehicle dashboard warning indicator. Please take a clear, close-up photo of a dashboard warning light.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tips: Make sure the warning light is clearly visible and centred in the photo.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section title helper
// ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
