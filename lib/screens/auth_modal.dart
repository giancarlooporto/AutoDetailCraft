import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/job_repository.dart';
import '../services/supabase_auth_service.dart';

class AuthModal extends StatefulWidget {
  final JobRepository repository;
  final bool initialIsSignUp;
  final String? initialInviteToken;
  final VoidCallback? onSuccess;

  const AuthModal({
    super.key,
    required this.repository,
    this.initialIsSignUp = false,
    this.initialInviteToken,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required JobRepository repository,
    bool initialIsSignUp = false,
    String? initialInviteToken,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthModal(
        repository: repository,
        initialIsSignUp: initialIsSignUp,
        initialInviteToken: initialInviteToken,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  late bool _isSignUp;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Staff Login State (Step 3)
  bool _isStaffMode = false;
  bool _usePinMode = true;
  bool _obscureStaffPass = true;
  final TextEditingController _staffPinCtrl = TextEditingController();
  final TextEditingController _staffEmailCtrl = TextEditingController();
  final TextEditingController _staffPassCtrl = TextEditingController();

  // Staff Invite Activation State (Step 3)
  bool _isInviteMode = false;
  bool _obscureInvitePass = true;
  final TextEditingController _inviteTokenCtrl = TextEditingController();
  final TextEditingController _invitePassCtrl = TextEditingController();
  final TextEditingController _inviteConfirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    if (widget.initialInviteToken != null && widget.initialInviteToken!.isNotEmpty) {
      _isInviteMode = true;
      _inviteTokenCtrl.text = widget.initialInviteToken!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _staffPinCtrl.dispose();
    _staffEmailCtrl.dispose();
    _staffPassCtrl.dispose();
    _inviteTokenCtrl.dispose();
    _invitePassCtrl.dispose();
    _inviteConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAcceptInvite() async {
    final token = _inviteTokenCtrl.text.trim();
    final pass = _invitePassCtrl.text.trim();
    final confirm = _inviteConfirmCtrl.text.trim();

    if (token.isEmpty) {
      setState(() => _errorMessage = 'Please enter your invitation token or link.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await widget.repository.acceptStaffInvite(
      token: token,
      password: pass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success && res.member != null) {
      Navigator.of(context).pop();
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Staff password set! Welcome to the studio, ${res.member!.name}!'),
              ),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    } else {
      setState(() => _errorMessage = res.error ?? 'Failed to activate staff invitation.');
    }
  }

  Future<void> _submitStaffLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await widget.repository.loginStaffMember(
      pin: _usePinMode
          ? _staffPinCtrl.text.trim()
          : (_staffPinCtrl.text.trim().isNotEmpty ? _staffPinCtrl.text.trim() : null),
      email: !_usePinMode ? _staffEmailCtrl.text.trim() : null,
      password: !_usePinMode ? _staffPassCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success && res.member != null) {
      Navigator.of(context).pop();
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Welcome back, ${res.member!.name}! (${res.member!.roleTitle})'),
              ),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    } else {
      setState(() => _errorMessage = res.error ?? 'Invalid staff credentials.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (_isSignUp) {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      final res = await SupabaseAuthService.signUp(
        email: email,
        password: password,
        displayName: name,
        phone: phone,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success && res.profile != null) {
        widget.repository.loginUser(res.profile!);
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Welcome to AutoDetailCraft, ${res.profile!.displayName}!'),
              ],
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      } else {
        setState(() => _errorMessage = res.error ?? 'Sign up failed.');
      }
    } else {
      final res = await SupabaseAuthService.signIn(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (res.success && res.profile != null) {
        setState(() => _isLoading = false);
        widget.repository.loginUser(res.profile!);
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Signed in as ${res.profile!.displayName}'),
              ],
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      } else {
        // Fallback: check if this matches staff member credentials across company roster
        final staffRes = await widget.repository.loginStaffMember(
          email: email,
          password: password,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (staffRes.success && staffRes.member != null) {
          Navigator.of(context).pop();
          widget.onSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Welcome back, ${staffRes.member!.name}! (${staffRes.member!.roleTitle})'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.surface,
            ),
          );
        } else {
          setState(() => _errorMessage = res.error ?? 'Invalid email or password.');
        }
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter your email above first to reset password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseAuthService.sendPasswordReset(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Password reset link sent! Check your inbox.')),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    } else {
      setState(() => _errorMessage = res.error ?? 'Failed to send reset link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (_isInviteMode) ...[
                // Staff Invite Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.key_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Invitation Setup',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Set your personal password to activate your staff account',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Invitation Token
                TextFormField(
                  controller: _inviteTokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invitation Token / Link Key',
                    hintText: 'inv_...',
                    prefixIcon: Icon(Icons.vpn_key_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // New Password
                TextFormField(
                  controller: _invitePassCtrl,
                  obscureText: _obscureInvitePass,
                  decoration: InputDecoration(
                    labelText: 'Personal Password (min 6 chars)',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureInvitePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscureInvitePass = !_obscureInvitePass),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm Password
                TextFormField(
                  controller: _inviteConfirmCtrl,
                  obscureText: _obscureInvitePass,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                  onFieldSubmitted: (_) => _submitAcceptInvite(),
                ),
                const SizedBox(height: 20),

                // Submit Accept Invite Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _submitAcceptInvite,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Save Password & Enter Studio',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _isInviteMode = false;
                      _errorMessage = null;
                    }),
                    child: const Text('Back to Client Sign In', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                ),
              ] else if (_isStaffMode) ...[
                // Staff Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_rounded, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Member Sign In',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Unlock workbench with shop PIN or staff credentials',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Method Selector: Quick PIN vs Email/Password
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _usePinMode ? AppTheme.primary.withAlpha(20) : AppTheme.surfaceLight,
                          side: BorderSide(color: _usePinMode ? AppTheme.primary : AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(Icons.dialpad_rounded, size: 16, color: _usePinMode ? AppTheme.primary : AppTheme.textSecondary),
                        label: Text(
                          '4-Digit PIN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _usePinMode ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                        onPressed: () => setState(() => _usePinMode = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: !_usePinMode ? AppTheme.primary.withAlpha(20) : AppTheme.surfaceLight,
                          side: BorderSide(color: !_usePinMode ? AppTheme.primary : AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(Icons.alternate_email_rounded, size: 16, color: !_usePinMode ? AppTheme.primary : AppTheme.textSecondary),
                        label: Text(
                          'Email & Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_usePinMode ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                        onPressed: () => setState(() => _usePinMode = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_usePinMode) ...[
                  // 4-Digit PIN Input Field
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: TextFormField(
                        controller: _staffPinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '••••',
                          hintStyle: const TextStyle(fontSize: 26, letterSpacing: 10, color: AppTheme.textMuted),
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_rounded, size: 20, color: AppTheme.primary),
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                        ),
                        onFieldSubmitted: (_) => _submitStaffLogin(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Enter your 4-digit PIN assigned by your shop owner',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  TextFormField(
                    controller: _staffEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Staff Work Email',
                      hintText: 'staff@studio.com',
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _staffPassCtrl,
                    obscureText: _obscureStaffPass,
                    decoration: InputDecoration(
                      labelText: 'Password or PIN',
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureStaffPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(() => _obscureStaffPass = !_obscureStaffPass),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submitStaffLogin(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submit Staff Login Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _submitStaffLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Unlock Staff Workbench',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isStaffMode = false),
                        child: const Text('Back to Client Sign In', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ),
                      const Text('•', style: TextStyle(color: AppTheme.textMuted)),
                      TextButton(
                        onPressed: () => setState(() {
                          _isStaffMode = false;
                          _isInviteMode = true;
                          _errorMessage = null;
                        }),
                        child: const Text('Have an Invite Link / Token?', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Title & Branding
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignUp ? 'Create Your Account' : 'Welcome Back',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          _isSignUp ? 'Register to manage garage, bookings & studio' : 'Sign in to AutoDetailCraft',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Full Name (Sign Up only)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                    ),
                    validator: (v) {
                      if (_isSignUp && (v == null || v.trim().isEmpty)) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Email Address
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Phone Number (Sign Up optional)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      hintText: '(512) 555-0199',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                if (!_isSignUp) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendPasswordReset,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
                      child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else
                  const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          _isSignUp ? 'Create Account' : 'Sign In',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
                const SizedBox(height: 14),

                // Toggle Sign Up / Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.badge_outlined, size: 15),
                      label: const Text('Shop Staff Member? Sign in with Quick PIN', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _isStaffMode = true;
                          _isInviteMode = false;
                          _errorMessage = null;
                        });
                      },
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      icon: const Icon(Icons.vpn_key_outlined, size: 14),
                      label: const Text('Have a Staff Invite Link / Token?', style: TextStyle(fontSize: 11.5)),
                      onPressed: () {
                        setState(() {
                          _isInviteMode = true;
                          _isStaffMode = false;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}
