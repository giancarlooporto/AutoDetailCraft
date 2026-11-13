import 'dart:js_interop';
import 'dart:typed_data';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Web implementation for downloading a PNG QR code via Blob + AnchorElement.
Future<bool> downloadQrPng(Uint8List bytes, String fileName) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
