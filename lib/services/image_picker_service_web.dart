// Web implementation — uses dart:html FileUploadInputElement with client-side downscaling
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

Future<Uint8List?> _downscaleAndCompressImage(String dataUrl) async {
  final completer = Completer<Uint8List?>();
  final img = html.ImageElement();
  img.src = dataUrl;

  img.onLoad.listen((_) {
    const maxDim = 1200.0;
    var width = img.naturalWidth.toDouble();
    var height = img.naturalHeight.toDouble();

    if (width > maxDim || height > maxDim) {
      if (width > height) {
        height = (height * maxDim / width);
        width = maxDim;
      } else {
        width = (width * maxDim / height);
        height = maxDim;
      }
    }

    final canvas = html.CanvasElement(width: width.toInt(), height: height.toInt());
    final ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, width, height);

    // Compress to JPEG with 0.85 quality
    final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64Str = compressedDataUrl.split(',').last;
    final binaryString = html.window.atob(base64Str);
    final bytes = Uint8List(binaryString.length);
    for (var i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.codeUnitAt(i);
    }
    completer.complete(bytes);
  });

  img.onError.listen((_) {
    completer.complete(null);
  });

  return completer.future;
}

Future<({Uint8List? bytes, String? name})> pickImageFromDevice() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..click();

  await input.onChange.first;

  final file = input.files?.first;
  if (file == null) return (bytes: null, name: null);

  final reader = html.FileReader();
  reader.readAsDataUrl(file);
  await reader.onLoad.first;

  final dataUrl = reader.result as String?;
  if (dataUrl == null) return (bytes: null, name: file.name);

  final compressedBytes = await _downscaleAndCompressImage(dataUrl);
  return (bytes: compressedBytes, name: file.name);
}

Future<List<({Uint8List bytes, String name})>> pickMultipleImagesFromDevice() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = true
    ..click();

  await input.onChange.first;

  final files = input.files;
  if (files == null || files.isEmpty) return [];

  final List<({Uint8List bytes, String name})> results = [];

  for (final file in files) {
    try {
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;

      final dataUrl = reader.result as String?;
      if (dataUrl != null) {
        final compressedBytes = await _downscaleAndCompressImage(dataUrl);
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          results.add((bytes: compressedBytes, name: file.name));
        }
      }
    } catch (_) {
      // Continue processing remaining files
    }
  }

  return results;
}

