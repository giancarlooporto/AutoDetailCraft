import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256 hashing for the Owner Master PIN.
///
/// The raw PIN is never persisted on the device. Only the encoded string
/// `pbkdf2$<iterations>$<saltB64>$<hashB64>` is cached locally, which lets the
/// app verify offline. The server (Supabase RPC + bcrypt) remains authoritative.
class OwnerPinSecurity {
  static const int _iterations = 20000;
  static const int _keyLength = 32;

  static bool isValidFormat(String pin) => RegExp(r'^[0-9]{4}$').hasMatch(pin.trim());

  static String hashPin(String pin, {Uint8List? salt, int iterations = _iterations}) {
    final s = salt ?? _randomSalt();
    final dk = _pbkdf2(utf8.encode(pin.trim()), s, iterations, _keyLength);
    return 'pbkdf2\$$iterations\$${base64Encode(s)}\$${base64Encode(dk)}';
  }

  static bool verify(String pin, String? encoded) {
    if (encoded == null || encoded.isEmpty) return false;
    final parts = encoded.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null) return false;
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = _pbkdf2(utf8.encode(pin.trim()), salt, iterations, expected.length);
    // Constant-time comparison.
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static Uint8List _randomSalt() {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < keyLength) {
      final blockBytes = Uint8List(4)..buffer.asByteData().setUint32(0, block);
      var u = hmac.convert([...salt, ...blockBytes]).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, keyLength));
  }
}

/// Result of an owner PIN attempt.
class OwnerPinResult {
  final bool ok;
  final String? error; // 'wrong_pin', 'locked', 'no_pin', 'invalid_format', 'mismatch'
  final int? remaining;
  final DateTime? lockedUntil;

  const OwnerPinResult({required this.ok, this.error, this.remaining, this.lockedUntil});

  String get message {
    if (ok) return '';
    switch (error) {
      case 'locked':
        final mins = lockedUntil == null
            ? 15
            : (lockedUntil!.difference(DateTime.now()).inSeconds / 60).ceil().clamp(1, 15);
        return 'Too many failed attempts. PIN locked for $mins min.';
      case 'no_pin':
        return 'No Owner PIN has been created yet.';
      case 'invalid_format':
        return 'PIN must be exactly 4 digits.';
      case 'mismatch':
        return 'PINs do not match.';
      case 'already_set':
        return 'An Owner PIN already exists for this account. Use Change PIN instead.';
      case 'wrong_pin':
      default:
        return remaining != null
            ? 'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} left.'
            : 'Incorrect PIN.';
    }
  }
}
