extension StringExtension on String {
  String toBloodGroup() {
    switch (toLowerCase()) {
      case 'ominus':
        return 'O-';
      case 'oplus':
        return 'O+';
      case 'aminus':
        return 'A-';
      case 'aplus':
        return 'A+';
      case 'bminus':
        return 'B-';
      case 'bplus':
        return 'B+';
      case 'abminus':
        return 'AB-';
      case 'abplus':
        return 'AB+';
      default:
        return this;
    }
  }
}
