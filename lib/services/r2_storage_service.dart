import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class R2StorageService {
  // Cloudflare R2 Configuration
  static const String accountId = '502973bb2040a020d54a242d1f0e5148';
  static const String bucketName = 'autodetailcraft-media';
  static const String publicDomain = 'https://media.autodetailcraft.com';
  static const String endpointHost = '$accountId.r2.cloudflarestorage.com';

  // R2 API Token Credentials
  static const String _accessKeyId = 'd9857fe65123ab2c79e68f4eec895def';
  static const String _secretAccessKey = 'd665079c002660f86c23a32a19b8eb1ac0d53b81fcf71f179a47d1e1a0ebe5a2';
  static const String _region = 'auto';
  static const String _service = 's3';

  /// Generates an AWS S3 SigV4 presigned PUT URL.
  /// This requires NO custom or restricted headers (like Host) and works flawlessly across web browsers and mobile.
  static String generatePresignedPutUrl({
    required String objectKey,
    int expiresInSeconds = 3600,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = amzDate.substring(0, 8);
    final credentialScope = '$dateStamp/$_region/$_service/aws4_request';
    final canonicalUri = '/$bucketName/$objectKey';

    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$_accessKeyId/$credentialScope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresInSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedKeys = queryParams.keys.toList()..sort();
    final canonicalQueryString = sortedKeys
        .map((k) => '${Uri.encodeComponent(k)}=${Uri.encodeComponent(queryParams[k]!)}')
        .join('&');

    final canonicalHeaders = 'host:$endpointHost\n';
    const signedHeaders = 'host';
    const payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalRequest = [
      'PUT',
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _getSignatureKey(_secretAccessKey, dateStamp, _region, _service);
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    return 'https://$endpointHost$canonicalUri?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  /// Uploads binary image bytes to Cloudflare R2 via presigned URL and returns the public CDN URL.
  static Future<String?> uploadImage({
    required String userId,
    required Uint8List bytes,
    String? customFileName,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final fileName = customFileName ?? 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final objectKey = '$userId/$fileName';

      // 1. Generate presigned URL for clean cross-origin browser upload
      final presignedUrl = generatePresignedPutUrl(objectKey: objectKey);

      // 2. Perform direct HTTP PUT
      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cdnUrl = '$publicDomain/$objectKey';
        if (kDebugMode) {
          print('[R2StorageService] Successfully uploaded to R2: $cdnUrl');
        }
        return cdnUrl;
      } else {
        if (kDebugMode) {
          print('[R2StorageService] R2 Upload failed: HTTP ${response.statusCode} - ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[R2StorageService] Exception during R2 upload: $e');
      }
      return null;
    }
  }

  static String _formatAmzDate(DateTime dt) {
    String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
    return '${dt.year}${pad(dt.month)}${pad(dt.day)}T${pad(dt.hour)}${pad(dt.minute)}${pad(dt.second)}Z';
  }

  static List<int> _getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }
}
