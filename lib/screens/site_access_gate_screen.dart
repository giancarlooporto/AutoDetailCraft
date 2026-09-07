import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/local_storage_service.dart';

class SiteAccessGateScreen extends StatefulWidget {
  final Widget child;

  /// Set [enabled] to false when you are officially ready to launch to the public!
  final bool enabled;

  /// The master access PIN required to enter the website while in private development
  final String accessPin;

  const SiteAccessGateScreen({
    super.key,
    required this.child,
    this.enabled = true,
    this.accessPin = '9229',
  });

  @override
  State<SiteAccessGateScreen> createState() => _SiteAccessGateScreenState();
}

class _SiteAccessGateScreenState extends State<SiteAccessGateScreen> {
  bool _isLoading = true;
  bool _isUnlocked = false;
  final _pinController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (!widget.enabled) {
      setState(() {
        _isUnlocked = true;
        _isLoading = false;
      });
      return;
    }

    final unlocked = await LocalStorageService.isSiteUnlocked();
    setState(() {
      _isUnlocked = unlocked;
      _isLoading = false;
    });
  }

  Future<void> _verifyPin() async {
    final input = _pinController.text.trim();
    if (input == widget.accessPin) {
      await LocalStorageService.saveSiteUnlocked(true);
      setState(() {
        _isUnlocked = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN code. Please try again.';
      });
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_isUnlocked || !widget.enabled) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AutoDetailCraft',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Private Preview • Development Mode',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter the 4-digit PIN to access this site:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
                  onSubmitted: (_) => _verifyPin(),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 6,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    errorText: _errorMessage,
                    errorStyle: const TextStyle(color: Colors.redAccent),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Unlock Access',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
