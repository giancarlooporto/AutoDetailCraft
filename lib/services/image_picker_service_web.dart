// Web implementation — uses dart:html FileUploadInputElement with client-side downscaling
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

Future<Uint8List?> _downscaleAndCompressFile(html.File file) async {
  final completer = Completer<Uint8List?>();
  final objectUrl = html.Url.createObjectUrlFromBlob(file);
  final img = html.ImageElement();
  img.src = objectUrl;

  img.onLoad.listen((_) {
    try {
      const maxDim = 1280.0;
      var width = img.naturalWidth.toDouble();
      var height = img.naturalHeight.toDouble();

      if (width <= 0 || height <= 0) {
        completer.complete(null);
        return;
      }

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

      // Compress to JPEG with 0.82 quality to maintain clarity while keeping RAM & byte size low
      final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.82);
      final base64Str = compressedDataUrl.split(',').last;
      final binaryString = html.window.atob(base64Str);
      final bytes = Uint8List(binaryString.length);
      for (var i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.codeUnitAt(i);
      }
      completer.complete(bytes);
    } catch (_) {
      completer.complete(null);
    } finally {
      html.Url.revokeObjectUrl(objectUrl);
    }
  });

  img.onError.listen((_) {
    html.Url.revokeObjectUrl(objectUrl);
    completer.complete(null);
  });

  return completer.future;
}

Future<html.FileUploadInputElement?> _showPicker({bool multiple = false}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = multiple
    ..style.display = 'none';

  html.document.body?.children.add(input);

  final completer = Completer<html.FileUploadInputElement?>();

  StreamSubscription? changeSub;
  StreamSubscription? cancelSub;
  StreamSubscription? focusSub;
  Timer? focusTimer;

  void cleanup() {
    changeSub?.cancel();
    cancelSub?.cancel();
    focusSub?.cancel();
    focusTimer?.cancel();
    input.remove();
  }

  changeSub = input.onChange.listen((_) {
    if (!completer.isCompleted) {
      completer.complete(input);
    }
  });

  // Modern browsers dispatch 'cancel' event when file dialog is closed without selection
  cancelSub = input.on['cancel'].listen((_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  // Fallback: window focus event when user returns from mobile picker without selecting
  focusSub = html.window.onFocus.listen((_) {
    focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!completer.isCompleted && (input.files == null || input.files!.isEmpty)) {
        completer.complete(null);
      }
    });
  });

  input.click();

  final result = await completer.future;
  cleanup();
  return result;
}

Future<({Uint8List? bytes, String? name})> pickImageFromDevice() async {
  try {
    final input = await _showPicker(multiple: false);
    if (input == null) return (bytes: null, name: null);

    final file = input.files?.first;
    if (file == null) return (bytes: null, name: null);

    final compressedBytes = await _downscaleAndCompressFile(file);
    return (bytes: compressedBytes, name: file.name);
  } catch (_) {
    return (bytes: null, name: null);
  }
}

Future<List<({Uint8List bytes, String name})>> pickMultipleImagesFromDevice() async {
  try {
    final input = await _showPicker(multiple: true);
    if (input == null) return [];

    final files = input.files;
    if (files == null || files.isEmpty) return [];

    final List<({Uint8List bytes, String name})> results = [];

    for (final file in files) {
      try {
        final compressedBytes = await _downscaleAndCompressFile(file);
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          results.add((bytes: compressedBytes, name: file.name));
        }
      } catch (_) {
        // Continue processing remaining files
      }
    }

    return results;
  } catch (_) {
    return [];
  }
}

