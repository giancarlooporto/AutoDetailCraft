// Stub implementation for non-web platforms (VM tests, iOS, Android)
import 'dart:typed_data';

Future<({Uint8List? bytes, String? name})> pickImageFromDevice() async {
  // Not implemented for non-web — returns null gracefully
  return (bytes: null, name: null);
}

Future<List<({Uint8List bytes, String name})>> pickMultipleImagesFromDevice() async {
  // Not implemented for non-web — returns empty list gracefully
  return [];
}

