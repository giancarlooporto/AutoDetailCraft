import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'r2_storage_service.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://bczyryganiynfhjwlcgl.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_sK8zo59KFsJXNqktwxWdmA_Yu_3mnhy';
  static const String vehiclePhotosBucket = 'vehicle-photos';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      if (kDebugMode) {
        print('[SupabaseService] Initialized successfully with $supabaseUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Initialization warning/error: $e');
      }
    }
  }

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Uploads photo bytes exclusively to Cloudflare R2 and returns the public CDN URL.
  /// Supabase Storage is completely bypassed and disabled for media storage.
  static Future<String?> uploadVehiclePhoto({
    required String userId,
    required Uint8List bytes,
    String? customFileName,
  }) async {
    try {
      final r2Url = await R2StorageService.uploadImage(
        userId: userId,
        bytes: bytes,
        customFileName: customFileName,
        contentType: 'image/jpeg',
      );
      if (r2Url != null && r2Url.isNotEmpty) {
        if (kDebugMode) {
          print('[Storage] Successfully uploaded to Cloudflare R2: $r2Url');
        }
        return r2Url;
      }
      if (kDebugMode) {
        print('[Storage] Cloudflare R2 upload returned null URL');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[Storage] Cloudflare R2 upload error: $e');
      }
      return null;
    }
  }
}
