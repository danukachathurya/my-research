String humanizeRoadResqLabel(String value) {
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
