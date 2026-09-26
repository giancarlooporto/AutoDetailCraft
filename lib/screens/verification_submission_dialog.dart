import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/job_repository.dart';

class VerificationSubmissionDialog extends StatefulWidget {
  final JobRepository repository;

  const VerificationSubmissionDialog({super.key, required this.repository});

  static Future<void> show(BuildContext context, {required JobRepository repository}) {
    return showDialog(
      context: context,
      builder: (_) => VerificationSubmissionDialog(repository: repository),
    );
  }

  @override
  State<VerificationSubmissionDialog> createState() => _VerificationSubmissionDialogState();
}

class _VerificationSubmissionDialogState extends State<VerificationSubmissionDialog> {
  String _selectedDocType = 'insurance'; // 'insurance' or 'ida_certification'
  final _policyNumberCtrl = TextEditingController();
  final _docUrlCtrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=800&auto=format&fit=crop&q=80',
  );
  bool _agreedToLiabilityTerms = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _policyNumberCtrl.dispose();
    _docUrlCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_agreedToLiabilityTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Independent Detailer Liability Terms to proceed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_policyNumberCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Policy / Certificate identification number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await widget.repository.submitDetailerVerification(
      docType: _selectedDocType,
      docUrl: _docUrlCtrl.text.trim(),
      policyOrCertNumber: _policyNumberCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Submitted to Back Office audit queue! A reviewer will verify your credentials.'),
          ],
        ),
        backgroundColor: AppTheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 10),
          Text('Submit Verification & Insurance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload proof of Garage Keepers Liability Insurance or IDA Certification to earn public trust badges on your studio storefront.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Document Type Selector
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        title: 'Garage Keepers Insurance',
                        type: 'insurance',
                        icon: Icons.security_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTypeOption(
                        title: 'IDA Certified (CD-SV)',
                        type: 'ida_certification',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Policy / Cert Number
                TextField(
                  controller: _policyNumberCtrl,
                  decoration: InputDecoration(
                    labelText: _selectedDocType == 'insurance'
                        ? 'Policy Number (COI)'
                        : 'IDA Member / Cert ID',
                    hintText: _selectedDocType == 'insurance'
                        ? 'e.g. HISCOX-GK-99412-TX'
                        : 'e.g. IDA-CDSV-2024-91',
                    prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Document URL / Image
                TextField(
                  controller: _docUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Document Image / PDF URL',
                    prefixIcon: Icon(Icons.link_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 16),

                // Legal Disclaimer & Liability Waiver
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToLiabilityTerms,
                        activeColor: AppTheme.primary,
                        onChanged: (val) => setState(() => _agreedToLiabilityTerms = val ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'I confirm that I operate as an independent detailing business. AutoDetailCraft is a software platform provider and does not assume custody, warranty, or liability for vehicles serviced by my studio.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Submit for Review', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTypeOption({required String title, required String type, required IconData icon}) {
    final isSelected = _selectedDocType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedDocType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
