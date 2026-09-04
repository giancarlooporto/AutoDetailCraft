import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Uploads vehicle photo bytes to Supabase Storage and returns the public CDN URL.
  static Future<String?> uploadVehiclePhoto({
    required String userId,
    required Uint8List bytes,
    String? customFileName,
  }) async {
    final c = client;
    if (c == null) return null;

    try {
      final fileName = customFileName ?? 'veh_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = '$userId/$fileName';

      // Upload binary to Supabase Storage
      await c.storage.from(vehiclePhotosBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public CDN URL
      final publicUrl = c.storage.from(vehiclePhotosBucket).getPublicUrl(storagePath);
      if (kDebugMode) {
        print('[SupabaseService] Uploaded photo successfully: $publicUrl');
      }
      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('[SupabaseService] Failed to upload to Supabase Storage: $e');
      }
      return null;
    }
  }
}
