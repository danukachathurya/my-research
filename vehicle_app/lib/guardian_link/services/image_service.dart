import 'dart:convert';
import 'dart:io';

class ImageService {
  /// Convert an image file to base64 string
  static String fileToBase64(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    return base64Encode(bytes);
  }

  /// Convert base64 string back to bytes
  static List<int> base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }

  /// Get image file size in KB
  static double getFileSizeInKB(File imageFile) {
    return imageFile.lengthSync() / 1024;
  }

  /// Check if base64 string is valid
  static bool isValidBase64(String str) {
    try {
      base64Decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }
}
