import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';

class StudioShareDialog extends StatelessWidget {
  final UserProfile detailer;

  const StudioShareDialog({super.key, required this.detailer});

  static String buildStudioShareUrl(String studioId) {
    return 'https://www.autodetailcraft.com/?studio=${Uri.encodeComponent(studioId)}';
  }

  static Future<void> show(
    BuildContext context, {
    required UserProfile detailer,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StudioShareDialog(detailer: detailer),
    );
  }

  Future<void> _copyLink(BuildContext context, String shareUrl) async {
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Studio website link copied to clipboard'),
        backgroundColor: AppTheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studioName = detailer.businessName.trim().isNotEmpty
        ? detailer.businessName.trim()
        : (detailer.displayName.trim().isNotEmpty
            ? detailer.displayName.trim()
            : 'Detailing Studio');
    final shareUrl = buildStudioShareUrl(detailer.id);

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.surfaceLight),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.surfaceLight,
                    backgroundImage: detailer.localAvatarBytes != null
                        ? MemoryImage(detailer.localAvatarBytes!) as ImageProvider
                        : (detailer.avatarUrl.trim().isNotEmpty
                            ? NetworkImage(detailer.avatarUrl.trim())
                            : null),
                    child: (detailer.localAvatarBytes == null &&
                            detailer.avatarUrl.trim().isEmpty)
                        ? Text(
                            studioName[0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studioName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your Detailing Website & Booking Link',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: shareUrl,
                      version: QrVersions.auto,
                      size: 190,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Scan to Book & View Portfolio',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: () => _copyLink(context, shareUrl),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          shareUrl,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copyLink(context, shareUrl),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Website Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
