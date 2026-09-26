import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';

class SubscriptionPlansDialog extends StatelessWidget {
  final JobRepository repository;

  const SubscriptionPlansDialog({super.key, required this.repository});

  static Future<void> show(BuildContext context, {required JobRepository repository}) {
    return showDialog(
      context: context,
      builder: (_) => SubscriptionPlansDialog(repository: repository),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTier = repository.currentUser.subscriptionTier;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: AppTheme.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Detailer Software Plans',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SaaS disclaimer banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AutoDetailCraft is a software platform. We do not charge per job or take commission. You license our business tools and keep 100% of your detailing revenue.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Pricing Cards Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 650;
                    final cards = [
                      _buildPlanCard(
                        context: context,
                        title: 'Free Starter',
                        price: '\$0',
                        period: 'forever',
                        tier: SubscriptionTier.free,
                        isCurrent: currentTier == SubscriptionTier.free,
                        features: [
                          '3 Transformation zones per job',
                          'Basic public profile listing',
                          'Direct phone & Instagram links',
                          'Standard chemical dilution tool',
                        ],
                      ),
                      _buildPlanCard(
                        context: context,
                        title: 'Pro Studio',
                        price: '\$29',
                        period: 'per month',
                        tier: SubscriptionTier.pro,
                        isCurrent: currentTier == SubscriptionTier.pro,
                        isPopular: true,
                        features: [
                          'Unlimited 360° photo zones',
                          'Digital Paint Depth Gauge (PTG)',
                          'Online Client Booking Calendar',
                          'Direct Messaging & In-app Chat',
                          'Verified Insured Pro Badge eligibility',
                        ],
                      ),
                      _buildPlanCard(
                        context: context,
                        title: 'Enterprise Shop',
                        price: '\$79',
                        period: 'per month',
                        tier: SubscriptionTier.enterprise,
                        isCurrent: currentTier == SubscriptionTier.enterprise,
                        features: [
                          'Everything in Pro Studio',
                          'Multi-Technician & Team Dispatch',
                          'Unlimited Service Packages',
                          'Priority Featured placement on Explore',
                          'Dedicated VIP Software Support',
                        ],
                      ),
                    ];

                    if (isSmall) {
                      return Column(
                        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList(),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    required String period,
    required SubscriptionTier tier,
    required bool isCurrent,
    required List<String> features,
    bool isPopular = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2129),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppTheme.primary : AppTheme.border,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MOST POPULAR',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 4),
              Text(period, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const Divider(color: AppTheme.border, height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3))),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.white12 : (isPopular ? AppTheme.primary : AppTheme.surface),
                foregroundColor: isPopular && !isCurrent ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isCurrent
                  ? null
                  : () {
                      repository.updateSubscriptionTier(tier);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully switched to ${tier.label}!'),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    },
              child: Text(
                isCurrent ? 'Current Plan' : 'Select ${title.split(' ').first}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
