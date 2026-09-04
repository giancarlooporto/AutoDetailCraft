// Web implementation — uses dart:html FileUploadInputElement with client-side downscaling
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

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

  // Downscale image using HTML5 Canvas to keep base64 within localStorage limits (~100-300KB)
  final completer = Completer<Uint8List?>();
  final img = html.ImageElement();
  img.src = dataUrl;

  img.onLoad.listen((_) {
    final maxDim = 1200.0;
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

  final compressedBytes = await completer.future;
  return (bytes: compressedBytes, name: file.name);
}
