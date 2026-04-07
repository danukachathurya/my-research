String humanizeClaimStatus(String value) {
  final cleaned = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (cleaned.isEmpty) {
    return '';
  }
  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

String presentClaimStatusLabel(
  String? status, {
  bool hasClaimRecord = false,
}) {
  final normalized = status?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'sent_to_insurer':
      return 'Sent to insurer';
    case 'ai_generated':
      return 'Assessment saved';
    case 'ready_for_insurer_submission':
      return 'Ready for insurer submission';
    case 'ready_for_submission':
      return 'Ready for submission';
    case 'awaiting_more_photos':
      return 'More photos needed';
    case 'awaiting_operator_review':
      return 'Awaiting review';
    case 'pending_manual_review':
      return 'Pending manual review';
    case 'no_damage_detected':
      return 'No damage detected';
    default:
      if (normalized.isNotEmpty) {
        return humanizeClaimStatus(normalized);
      }
      return hasClaimRecord ? 'Assessment saved' : '';
  }
}

bool isClaimSentToInsurer(String? status) {
  return status?.trim().toLowerCase() == 'sent_to_insurer';
}
