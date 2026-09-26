import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../services/job_repository.dart';

class BackofficeDashboardScreen extends StatefulWidget {
  final JobRepository repository;

  const BackofficeDashboardScreen({super.key, required this.repository});

  @override
  State<BackofficeDashboardScreen> createState() => _BackofficeDashboardScreenState();
}

class _BackofficeDashboardScreenState extends State<BackofficeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.repository.loadVerificationRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final pendingVerifications = widget.repository.verificationRequests
            .where((r) => r.status == VerificationStatus.pending)
            .length;

        return Scaffold(
          backgroundColor: const Color(0xFF0F1115),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161920),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withAlpha(120)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.redAccent),
                      SizedBox(width: 6),
                      Text(
                        'BACK OFFICE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AutoDetailCraft Operations Portal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Admin: ${widget.repository.currentUser.displayName}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                const Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'SaaS Overview'),
                Tab(
                  icon: Badge(
                    isLabelVisible: pendingVerifications > 0,
                    label: Text('$pendingVerifications'),
                    child: const Icon(Icons.verified_user_outlined, size: 18),
                  ),
                  text: 'Verification Queue',
                ),
                const Tab(icon: Icon(Icons.storefront_outlined, size: 18), text: 'Detailer Subscribers'),
                const Tab(icon: Icon(Icons.manage_accounts_outlined, size: 18), text: 'Staff & Roles (RBAC)'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSaasOverviewTab(),
              _buildVerificationQueueTab(),
              _buildSubscribersTab(),
              _buildStaffRbacTab(),
            ],
          ),
        );
      },
    );
  }

  // TAB 1: SAAS & METRICS OVERVIEW
  Widget _buildSaasOverviewTab() {
    final detailers = widget.repository.publicDetailers;
    final totalDetailers = detailers.length;
    final verifiedInsured = detailers.where((d) => d.isInsuranceVerified).length;
    final proSubscribers = detailers.where((d) => d.subscriptionTier == SubscriptionTier.pro).length;
    final enterpriseSubscribers = detailers.where((d) => d.subscriptionTier == SubscriptionTier.enterprise).length;

    // Simulated Monthly Recurring Revenue (MRR)
    final mrr = (proSubscribers * 29.0) + (enterpriseSubscribers * 79.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SaaS Platform Legal Shield Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: Colors.blueAccent, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SaaS Platform Liability Protection Active',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'AutoDetailCraft operates as software tooling & subscription management. You collect subscription licensing fees, not per-job cut, insulating the platform from vehicle damage disputes.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // KPI Cards
              Row(
                children: [
                  _buildMetricCard(
                    title: 'Monthly Recurring Revenue',
                    value: '\$${mrr.toStringAsFixed(0)}',
                    subtext: 'B2B Software Subscriptions',
                    icon: Icons.attach_money_rounded,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    title: 'Active Detailer Shops',
                    value: '$totalDetailers',
                    subtext: '$proSubscribers Pro • $enterpriseSubscribers Enterprise',
                    icon: Icons.storefront_rounded,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    title: 'Insured & Verified',
                    value: '$verifiedInsured / $totalDetailers',
                    subtext: 'Garage Keepers COI on file',
                    icon: Icons.security_rounded,
                    color: Colors.orangeAccent,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Subscription Breakdown Chart Table
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SaaS Subscription Tiers & Capabilities',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    _buildTierRow('Free Starter', 'Free', '3 Photo zones • Basic portfolio listing', Colors.grey),
                    const Divider(color: AppTheme.border, height: 20),
                    _buildTierRow('Pro Studio', '\$29 / mo', 'Unlimited zones • Digital Paint Gauge • Client Booking Portal', AppTheme.primary),
                    const Divider(color: AppTheme.border, height: 20),
                    _buildTierRow('Enterprise / Shop', '\$79 / mo', 'Team Dispatch • Verified Insurance Badge • Priority Search', Colors.amberAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtext, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String title, String price, String perks, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
        ),
        SizedBox(
          width: 100,
          child: Text(price, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ),
        Expanded(
          child: Text(perks, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ),
      ],
    );
  }

  // TAB 2: VERIFICATION QUEUE (INSURANCE & IDA CERTIFICATES)
  Widget _buildVerificationQueueTab() {
    final requests = widget.repository.verificationRequests;

    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.greenAccent),
            SizedBox(height: 12),
            Text('Verification queue is empty', style: TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final isInsurance = req.docType == 'insurance';
        final isPending = req.status == VerificationStatus.pending;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPending ? Colors.orangeAccent.withAlpha(120) : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isInsurance ? Colors.blueAccent.withAlpha(25) : Colors.purpleAccent.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isInsurance ? Colors.blueAccent.withAlpha(80) : Colors.purpleAccent.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isInsurance ? Icons.security_rounded : Icons.workspace_premium_rounded,
                              size: 14,
                              color: isInsurance ? Colors.blueAccent : Colors.purpleAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isInsurance ? 'GARAGE KEEPERS INSURANCE COI' : 'IDA CERTIFICATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isInsurance ? Colors.blueAccent : Colors.purpleAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(req.status).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          req.status.name.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(req.status)),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Submitted: ${_formatDate(req.submittedAt)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          req.docUrl,
                          width: 120,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 80,
                            color: Colors.white10,
                            child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.businessName.isNotEmpty ? req.businessName : req.detailerName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detailer / Host: ${req.detailerName} (ID: ${req.userId})',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            if (req.policyOrCertNumber.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Policy / Certificate #: ${req.policyOrCertNumber}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ],
                            if (req.reviewerNotes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Reviewer Note: ${req.reviewerNotes}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isPending) ...[
                    const Divider(color: AppTheme.border, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: () => _promptReviewDecision(context, req, VerificationStatus.rejected),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject Submission'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _promptReviewDecision(context, req, VerificationStatus.approved),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve & Issue Badge', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.approved:
        return Colors.greenAccent;
      case VerificationStatus.rejected:
        return Colors.redAccent;
      case VerificationStatus.pending:
        return Colors.orangeAccent;
      case VerificationStatus.none:
        return Colors.grey;
    }
  }

  void _promptReviewDecision(BuildContext context, VerificationRequest req, VerificationStatus newStatus) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          newStatus == VerificationStatus.approved ? 'Approve Verification?' : 'Reject Verification?',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              newStatus == VerificationStatus.approved
                  ? 'This will immediately mark ${req.businessName} as Verified Insured in the app and public search.'
                  : 'Please provide a reason for rejecting this document (e.g. expired, unreadable, name mismatch).',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Auditor Notes / Reason (Optional)',
                hintText: 'e.g. Validated with Hiscox policy check portal',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == VerificationStatus.approved ? Colors.greenAccent.shade700 : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.repository.reviewVerification(
                requestId: req.id,
                detailerUserId: req.userId,
                docType: req.docType,
                newStatus: newStatus,
                notes: noteCtrl.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newStatus == VerificationStatus.approved
                        ? 'Verification approved! Badge granted.'
                        : 'Verification rejected.',
                  ),
                ),
              );
            },
            child: Text(newStatus == VerificationStatus.approved ? 'Confirm Approval' : 'Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  // TAB 3: SUBSCRIBERS DIRECTORY (With direct email, username, and role management)
  Widget _buildSubscribersTab() {
    final detailers = widget.repository.publicDetailers;

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: detailers.length,
      itemBuilder: (context, index) {
        final d = detailers[index];
        final email = d.username.contains('@') ? d.username : '${d.username}@detailcraft.com';

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 24, backgroundImage: NetworkImage(d.avatarUrl)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(d.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                            const SizedBox(width: 8),
                            if (d.isInsuranceVerified)
                              const Icon(Icons.security_rounded, size: 14, color: Colors.greenAccent),
                            if (d.role == UserRole.superAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.redAccent.withAlpha(100), width: 0.8),
                                ),
                                child: const Text('SUPER ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ),
                            ] else if (d.role == UserRole.supportAgent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blueAccent.withAlpha(100), width: 0.8),
                                ),
                                child: const Text('STAFF AGENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              'Email: $email',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '• @${d.username} • ${d.location}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withAlpha(60)),
                    ),
                    child: Text(
                      d.subscriptionTier.label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Quick Role Promotion button
                  PopupMenuButton<String>(
                    tooltip: 'Manage User Permissions',
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                    onSelected: (action) {
                      if (action == 'make_agent') {
                        widget.repository.delegateAdminRole(
                          username: d.username,
                          email: email,
                          role: UserRole.supportAgent,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delegated Support Agent role to @${d.username}!')),
                        );
                      } else if (action == 'make_admin') {
                        widget.repository.delegateAdminRole(
                          username: d.username,
                          email: email,
                          role: UserRole.superAdmin,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delegated Super Admin role to @${d.username}!')),
                        );
                      } else if (action.startsWith('tier_')) {
                        final tierName = action.replaceFirst('tier_', '');
                        final tier = SubscriptionTier.values.firstWhere((t) => t.name == tierName);
                        if (d.id == widget.repository.currentUser.id) {
                          widget.repository.updateSubscriptionTier(tier);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated ${d.businessName} to ${tier.label}')),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'make_agent',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Delegate: Support Agent (Limited)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'make_admin',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delegate: Super Admin (Full)'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'tier_free',
                        child: Text('Plan: Free Starter'),
                      ),
                      const PopupMenuItem(
                        value: 'tier_pro',
                        child: Text('Plan: Pro Studio (\$29/mo)'),
                      ),
                      const PopupMenuItem(
                        value: 'tier_enterprise',
                        child: Text('Plan: Enterprise Shop (\$79/mo)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // TAB 4: STAFF & ROLES (RBAC with Dynamic Delegation)
  Widget _buildStaffRbacTab() {
    final staff = widget.repository.staffMembers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Staff Roles & Permissions (RBAC)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text(
                        'Delegate admins with limited permissions or grant full platform rights. Deactivate any session in 1 click.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showAddStaffDialog(context),
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('Delegate New Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Staff List
              ...staff.map((m) {
                final isSuper = m.role == UserRole.superAdmin;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: m.isActive
                          ? (isSuper ? Colors.redAccent.withAlpha(80) : Colors.blueAccent.withAlpha(80))
                          : Colors.grey.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (isSuper ? Colors.redAccent : Colors.blueAccent).withAlpha(25),
                        child: Icon(
                          isSuper ? Icons.admin_panel_settings_rounded : Icons.shield_outlined,
                          color: isSuper ? Colors.redAccent : Colors.blueAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('@${m.username}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isSuper ? Colors.redAccent : Colors.blueAccent).withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: (isSuper ? Colors.redAccent : Colors.blueAccent).withAlpha(80),
                                    ),
                                  ),
                                  child: Text(
                                    isSuper ? 'SUPER ADMIN (FULL OWNER)' : 'SUPPORT AGENT (LIMITED)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isSuper ? Colors.redAccent : Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: m.isActive ? Colors.greenAccent.withAlpha(20) : Colors.redAccent.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    m.isActive ? 'ACTIVE' : 'DEACTIVATED / REVOKED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: m.isActive ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Email: ${m.email} • Added ${_formatDate(m.createdAt)}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: m.isActive ? Colors.redAccent : Colors.greenAccent,
                          side: BorderSide(color: m.isActive ? Colors.redAccent : Colors.greenAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () {
                          widget.repository.toggleStaffActiveStatus(m.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                m.isActive
                                    ? 'Deactivated session for ${m.email}. Tokens revoked!'
                                    : 'Reactivated access for ${m.email}!',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          m.isActive ? 'Deactivate Session' : 'Reactivate Access',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                        tooltip: 'Remove Admin Access',
                        onPressed: () {
                          widget.repository.removeStaffMember(m.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Removed ${m.username} from staff.')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    UserRole selectedRole = UserRole.supportAgent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Delegate Admin Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter username and email to grant admin permissions. Support Agents can review verification documents but cannot view revenue or delete accounts.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. diego_craft or sarah_ops',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'e.g. agent@autodetailcraft.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Permission Tier:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDlgState(() => selectedRole = UserRole.supportAgent),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selectedRole == UserRole.supportAgent ? Colors.blueAccent.withAlpha(25) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedRole == UserRole.supportAgent ? Colors.blueAccent : AppTheme.border,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 20),
                            SizedBox(height: 4),
                            Text('Support Agent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Queue & Tickets', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDlgState(() => selectedRole = UserRole.superAdmin),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selectedRole == UserRole.superAdmin ? Colors.redAccent.withAlpha(25) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedRole == UserRole.superAdmin ? Colors.redAccent : AppTheme.border,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(height: 4),
                            Text('Super Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Full Owner Access', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              onPressed: () {
                if (usernameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
                widget.repository.delegateAdminRole(
                  username: usernameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  role: selectedRole,
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delegated ${selectedRole.label} to @${usernameCtrl.text.trim()}!')),
                );
              },
              child: const Text('Grant Role', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
