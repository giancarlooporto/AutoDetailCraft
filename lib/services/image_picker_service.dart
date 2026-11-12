// Conditional export: uses dart:html on web, stub on all other platforms
import 'dart:typed_data';
import 'image_picker_service_stub.dart'
    if (dart.library.html) 'image_picker_service_web.dart' as platform;

/// Injectable mock single-image picker hook for offline unit and widget tests.
Future<({Uint8List? bytes, String? name})> Function()? mockPickImageOverride;

/// Injectable mock multi-image picker hook for offline unit and widget tests.
Future<List<({Uint8List bytes, String name})>> Function()? mockPickMultipleImagesOverride;

Future<({Uint8List? bytes, String? name})> pickImageFromDevice() {
  if (mockPickImageOverride != null) {
    return mockPickImageOverride!();
  }
  return platform.pickImageFromDevice();
}

Future<List<({Uint8List bytes, String name})>> pickMultipleImagesFromDevice() {
  if (mockPickMultipleImagesOverride != null) {
    return mockPickMultipleImagesOverride!();
  }
  return platform.pickMultipleImagesFromDevice();
}


